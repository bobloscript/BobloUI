--!nonstrict
--[[
	Janitor — cleanup container.

	Every object in BobloUI that creates Instances, connections or tasks owns a
	Janitor. Parents adopt their children's Janitors, so `UI:Unload()` is a
	single cascading Destroy.

	Cleanup runs in REVERSE insertion order (LIFO): tearing down in reverse
	avoids handlers firing against half-destroyed state.
]]

local Janitor = {}
Janitor.__index = Janitor

local function cleanupOne(object: any, method: any)
	if method ~= nil then
		if type(method) == "function" then
			method(object)
		else
			local fn = object[method]
			if fn then
				fn(object)
			end
		end
		return
	end

	local kind = typeof(object)
	if kind == "function" then
		object()
	elseif kind == "RBXScriptConnection" then
		object:Disconnect()
	elseif kind == "thread" then
		pcall(task.cancel, object)
	elseif kind == "Instance" then
		if object:IsA("Tween") then
			object:Cancel()
		end
		object:Destroy()
	elseif kind == "table" then
		local fn = object.Destroy or object.Disconnect or object.Cleanup
		if fn then
			fn(object)
		end
	end
end

function Janitor.new(name: string?)
	return setmetatable({
		_name = name or "Janitor",
		_items = {},
		_indexed = {},
		_destroyed = false,
	}, Janitor)
end

function Janitor.is(value): boolean
	return type(value) == "table" and getmetatable(value) == Janitor
end

--[[
	Add(object, method?, index?)

	method  nil       -> inferred from the object's type
	        string    -> object[method](object)
	        function  -> method(object)
	index   any       -> replaces (and cleans up) whatever was stored there
]]
function Janitor:Add(object: any, method: any?, index: any?)
	if self._destroyed then
		-- The owner is already gone. Clean immediately rather than leaking.
		cleanupOne(object, method)
		return object
	end

	if index ~= nil then
		self:Remove(index)
	end

	local entry = { object = object, method = method, index = index }
	table.insert(self._items, entry)
	if index ~= nil then
		self._indexed[index] = entry
	end
	return object
end

function Janitor:AddJanitor(child, index: any?)
	return self:Add(child, "Destroy", index)
end

function Janitor:Get(index: any): any?
	local entry = self._indexed[index]
	return entry and entry.object or nil
end

function Janitor:Remove(index: any)
	local entry = self._indexed[index]
	if not entry then
		return
	end
	self._indexed[index] = nil
	local position = table.find(self._items, entry)
	if position then
		table.remove(self._items, position)
	end
	local ok, err = pcall(cleanupOne, entry.object, entry.method)
	if not ok then
		warn(`[BobloUI] {self._name}: cleanup of "{tostring(index)}" failed: {err}`)
	end
end

--- Removes an entry WITHOUT cleaning it up, for handing ownership elsewhere.
function Janitor:Release(index: any): any?
	local entry = self._indexed[index]
	if not entry then
		return nil
	end
	self._indexed[index] = nil
	local position = table.find(self._items, entry)
	if position then
		table.remove(self._items, position)
	end
	return entry.object
end

function Janitor:LinkToInstance(instance: Instance)
	return self:Add(instance.Destroying:Connect(function()
		self:Destroy()
	end))
end

function Janitor:IsEmpty(): boolean
	return #self._items == 0
end

function Janitor:Cleanup()
	local items = self._items
	self._items = {}
	self._indexed = {}
	for index = #items, 1, -1 do
		local entry = items[index]
		local ok, err = pcall(cleanupOne, entry.object, entry.method)
		if not ok then
			warn(`[BobloUI] {self._name}: cleanup failed: {err}`)
		end
	end
end

function Janitor:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self:Cleanup()
end

return Janitor
