--!nonstrict
--[[
	Central synchronous state store.

	Nested writes are appended to one FIFO drain instead of recursively
	dispatching. WatchMany subscribers observe the settled state once per drain,
	and dependency tracking happens in Store:Get so it cannot be bypassed by
	reading the original Store reference.
]]

local Signal = require("@runtime/Signal")
local Util = require("@runtime/Util")

local Store = {}
Store.__index = Store

local MAX_CASCADE = 64

local function equal(a, b, seen)
	local kindA = typeof(a)
	if kindA ~= typeof(b) then
		return false
	end

	if type(a) == "table" and type(b) == "table" then
		seen = seen or {}
		local matches = seen[a]
		if matches and matches[b] then
			return true
		end
		if not matches then
			matches = {}
			seen[a] = matches
		end
		matches[b] = true

		for key, value in a do
			if not equal(value, b[key], seen) then
				return false
			end
		end
		for key in b do
			if a[key] == nil then
				return false
			end
		end
		return true
	end

	if rawequal(a, b) then
		return true
	end
	if kindA == "Color3" then
		return a.R == b.R and a.G == b.G and a.B == b.B
	end
	if kindA == "Vector2" or kindA == "Vector3" or kindA == "UDim2" or kindA == "CFrame" then
		return a == b
	end
	return a == b
end

local function originOwner(origin)
	if type(origin) == "table" and origin.Source ~= nil then
		return origin.Source
	end
	return origin
end

local function isCascadeError(value)
	return type(value) == "table" and value.__boblouiStateCascade == true
end

local function preserveCascadeTrace(value)
	if isCascadeError(value) then
		return value
	end
	return debug.traceback(value)
end

local function appendChain(chain, id)
	local nextChain = table.create(#(chain or {}) + 1)
	for index, key in chain or {} do
		nextChain[index] = key
	end
	table.insert(nextChain, id)
	return nextChain
end

function Store.new()
	return setmetatable({
		Changed = Signal.new("State.Changed"),
		_values = {},
		_present = {},
		_snapshots = {},
		_defaults = {},
		_defaultPresent = {},
		_watchers = {},
		_manyById = {},
		_manyPending = {},
		_manyOrder = {},
		_manyCalled = {},
		_batchDepth = 0,
		_pending = {},
		_pendingOrder = {},
		_queue = {},
		_queueHead = 1,
		_draining = false,
		_activeChain = nil,
		_trackers = {},
		_cascadeFailure = nil,
		_destroyed = false,
	}, Store)
end

function Store:Get(id)
	for _, tracker in self._trackers do
		if not tracker.Seen[id] then
			tracker.Seen[id] = true
			table.insert(tracker.Ordered, id)
		end
	end
	return self._values[id]
end

function Store:Has(id)
	return self._present[id] == true
end

function Store:Snapshot()
	return Util.deepCopy(self._values)
end

function Store:SetDefault(id, value)
	if not self._defaultPresent[id] then
		self._defaults[id] = Util.deepCopy(value)
		self._defaultPresent[id] = true
	end
	if not self._present[id] then
		self._values[id] = Util.deepCopy(value)
		self._snapshots[id] = Util.deepCopy(self._values[id])
		self._present[id] = true
	end
	return self._values[id]
end

function Store:_raiseCascade(chain)
	local failure = {
		__boblouiStateCascade = true,
		Message = `[BobloUI] State cascade exceeded {MAX_CASCADE} updates: {table.concat(chain, " -> ")}. Check recursive watchers.`,
	}
	self._cascadeFailure = failure
	error(failure, 0)
end

function Store:_enqueue(change)
	table.insert(self._queue, change)
end

function Store:_markMany(id, origin, chain)
	local bucket = self._manyById[id]
	if not bucket then
		return
	end
	local owner = originOwner(origin)
	for _, group in table.clone(bucket) do
		local ownerMatches = group.Owner ~= nil and (group.Owner == origin or group.Owner == owner)
		if group.Alive and not self._manyCalled[group] and not ownerMatches then
			group.ChangedId = id
			group.Origin = origin
			group.Chain = chain
			if not self._manyPending[group] then
				self._manyPending[group] = true
				table.insert(self._manyOrder, group)
			end
		end
	end
end

function Store:_dispatch(change)
	local id = change.id
	self._activeChain = change.chain
	local bucket = self._watchers[id]
	if bucket then
		local copy = table.clone(bucket)
		local owner = originOwner(change.origin)
		for _, watcher in copy do
			local ownerMatches = watcher.Owner ~= nil and (watcher.Owner == change.origin or watcher.Owner == owner)
			if table.find(bucket, watcher) and not ownerMatches then
				local ok, err =
					xpcall(watcher.Fn, preserveCascadeTrace, change.newValue, change.oldValue, id, change.origin)
				if not ok then
					if isCascadeError(err) then
						error(err, 0)
					end
					warn(`[BobloUI] State watcher "{id}" failed:\n{err}`)
				end
				if self._cascadeFailure then
					error(self._cascadeFailure, 0)
				end
			end
		end
	end

	self:_markMany(id, change.origin, change.chain)
	self.Changed:Fire(id, change.newValue, change.oldValue, change.origin)
	if self._cascadeFailure then
		error(self._cascadeFailure, 0)
	end
	self._activeChain = nil
end

function Store:_flushMany()
	local groups = self._manyOrder
	self._manyOrder = {}
	for _, group in groups do
		self._manyPending[group] = nil
		if group.Alive and not self._manyCalled[group] then
			self._manyCalled[group] = true
			local snapshot = {}
			for _, id in group.Ids do
				snapshot[id] = self:Get(id)
			end
			self._activeChain = group.Chain
			local ok, err = xpcall(group.Fn, preserveCascadeTrace, snapshot, group.ChangedId, group.Origin)
			self._activeChain = nil
			if not ok then
				if isCascadeError(err) then
					error(err, 0)
				end
				warn(`[BobloUI] State WatchMany failed:\n{err}`)
			end
			if self._cascadeFailure then
				error(self._cascadeFailure, 0)
			end
		end
	end
end

function Store:_drain()
	if self._draining then
		return
	end
	self._draining = true
	self._manyCalled = {}
	self._cascadeFailure = nil

	local ok, err = xpcall(function()
		while true do
			while self._queueHead <= #self._queue do
				local change = self._queue[self._queueHead]
				self._queueHead += 1
				self:_dispatch(change)
			end
			if #self._manyOrder == 0 then
				break
			end
			self:_flushMany()
		end
	end, preserveCascadeTrace)

	self._draining = false
	self._activeChain = nil
	self._queue = {}
	self._queueHead = 1
	self._manyPending = {}
	self._manyOrder = {}
	self._manyCalled = {}
	self._cascadeFailure = nil

	if not ok then
		if isCascadeError(err) then
			error(err.Message, 2)
		end
		error(err, 2)
	end
end

function Store:Set(id, value, origin)
	if self._destroyed then
		error("[BobloUI] State store is destroyed.", 2)
	end
	if type(id) ~= "string" or id == "" then
		error("[BobloUI] State:Set requires a non-empty string id.", 2)
	end

	local chain = appendChain(self._activeChain, id)
	if #chain > MAX_CASCADE then
		self:_raiseCascade(chain)
	end

	local oldValue = if self._present[id] then self._snapshots[id] else nil
	if self._present[id] and equal(oldValue, value) then
		return false
	end

	local storedValue = Util.deepCopy(value)
	self._values[id] = storedValue
	self._snapshots[id] = Util.deepCopy(storedValue)
	self._present[id] = true

	local change = {
		id = id,
		oldValue = oldValue,
		newValue = storedValue,
		origin = origin,
		chain = chain,
	}

	if self._batchDepth > 0 then
		local pending = self._pending[id]
		if pending then
			pending.newValue = storedValue
			pending.origin = origin
			pending.chain = chain
		else
			self._pending[id] = change
			table.insert(self._pendingOrder, id)
		end
	else
		self:_enqueue(change)
		self:_drain()
	end
	return true
end

function Store:Update(id, fn, origin)
	if type(fn) ~= "function" then
		error("[BobloUI] State:Update expects a function.", 2)
	end
	return self:Set(id, fn(self:Get(id)), origin)
end

function Store:Reset(id, origin)
	if not self._defaultPresent[id] then
		return false
	end
	return self:Set(id, Util.deepCopy(self._defaults[id]), origin)
end

function Store:Watch(id, fn, owner)
	if type(fn) ~= "function" then
		error("[BobloUI] State:Watch expects a function.", 2)
	end
	local bucket = self._watchers[id]
	if not bucket then
		bucket = {}
		self._watchers[id] = bucket
	end
	local watcher = { Fn = fn, Owner = owner }
	table.insert(bucket, watcher)
	local alive = true
	return function()
		if not alive then
			return
		end
		alive = false
		local current = self._watchers[id]
		if current then
			local position = table.find(current, watcher)
			if position then
				table.remove(current, position)
			end
			if #current == 0 then
				self._watchers[id] = nil
			end
		end
	end
end

function Store:WatchMany(ids, fn, owner)
	if type(ids) ~= "table" or type(fn) ~= "function" then
		error("[BobloUI] State:WatchMany expects an id array and a function.", 2)
	end
	local unique = {}
	local ordered = {}
	for _, id in ids do
		if type(id) ~= "string" or id == "" then
			error("[BobloUI] State:WatchMany ids must be non-empty strings.", 2)
		end
		if not unique[id] then
			unique[id] = true
			table.insert(ordered, id)
		end
	end

	local group = { Ids = ordered, Fn = fn, Owner = owner, Alive = true }
	for _, id in ordered do
		local bucket = self._manyById[id]
		if not bucket then
			bucket = {}
			self._manyById[id] = bucket
		end
		table.insert(bucket, group)
	end

	return function()
		if not group.Alive then
			return
		end
		group.Alive = false
		self._manyPending[group] = nil
		for _, id in ordered do
			local bucket = self._manyById[id]
			if bucket then
				local position = table.find(bucket, group)
				if position then
					table.remove(bucket, position)
				end
				if #bucket == 0 then
					self._manyById[id] = nil
				end
			end
		end
	end
end

function Store:_flushBatch()
	local pending = self._pending
	local order = self._pendingOrder
	self._pending = {}
	self._pendingOrder = {}
	for _, id in order do
		local change = pending[id]
		if change and not equal(change.oldValue, change.newValue) then
			self:_enqueue(change)
		end
	end
	self:_drain()
end

function Store:Batch(fn)
	if type(fn) ~= "function" then
		error("[BobloUI] State:Batch expects a function.", 2)
	end
	self._batchDepth += 1
	local ok, result = xpcall(fn, preserveCascadeTrace)
	self._batchDepth -= 1

	if not ok and isCascadeError(result) then
		if self._batchDepth == 0 then
			self._pending = {}
			self._pendingOrder = {}
		end
		error(result.Message, 2)
	end

	if self._batchDepth == 0 then
		self:_flushBatch()
	end
	if not ok then
		error(result, 2)
	end
	return result
end

-- Tracks every Get made on this Store, including direct calls through aliases.
function Store:Track(predicate)
	if type(predicate) ~= "function" then
		error("[BobloUI] State:Track expects a function.", 2)
	end
	local tracker = { Seen = {}, Ordered = {} }
	table.insert(self._trackers, tracker)
	local ok, result = xpcall(predicate, preserveCascadeTrace, self)
	table.remove(self._trackers)
	if not ok then
		if isCascadeError(result) then
			error(result.Message, 2)
		end
		error(`[BobloUI] dependency predicate failed:\n{result}`, 2)
	end
	return tracker.Ordered, result
end

function Store:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self.Changed:Destroy()
	self._values = {}
	self._present = {}
	self._snapshots = {}
	self._defaults = {}
	self._defaultPresent = {}
	self._watchers = {}
	self._manyById = {}
	self._manyPending = {}
	self._manyOrder = {}
	self._pending = {}
	self._pendingOrder = {}
	self._queue = {}
	self._trackers = {}
end

return Store
