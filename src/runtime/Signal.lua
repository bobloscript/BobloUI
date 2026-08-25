--!nonstrict
--[[
	Signal — synchronous, error-isolated event.

	Not a BindableEvent: those serialise their arguments, which loses table
	identity and breaks any payload richer than primitives. The State layer
	depends on passing real tables through, so we need our own.

	Semantics:
	  * handlers run SYNCHRONOUSLY, in connection order, before Fire returns
	  * a handler that errors is reported and skipped; it does not abort the rest
	  * connections made during a Fire are not called by that Fire
	  * connections disconnected during a Fire are not called by that Fire
]]

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local signal = self._signal
	signal._dirty = true
	if signal._depth == 0 then
		signal:_compact()
	end
end

Connection.Destroy = Connection.Disconnect

function Signal.new(name: string?)
	return setmetatable({
		_name = name or "Signal",
		_conns = {},
		_depth = 0,
		_dirty = false,
	}, Signal)
end

function Signal.is(value): boolean
	return type(value) == "table" and getmetatable(value) == Signal
end

function Signal:_compact()
	local kept = {}
	for _, conn in self._conns do
		if conn.Connected then
			table.insert(kept, conn)
		end
	end
	self._conns = kept
	self._dirty = false
end

function Signal:Connect(fn)
	if type(fn) ~= "function" then
		error(`[BobloUI] {self._name}:Connect expects a function, got {typeof(fn)}`, 2)
	end
	local conn = setmetatable({
		Connected = true,
		_fn = fn,
		_signal = self,
	}, Connection)
	table.insert(self._conns, conn)
	return conn
end

function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal:Fire(...)
	local conns = self._conns
	local count = #conns
	if count == 0 then
		return
	end

	self._depth += 1
	for index = 1, count do
		local conn = conns[index]
		if conn and conn.Connected then
			local ok, err = xpcall(conn._fn, debug.traceback, ...)
			if not ok then
				warn(`[BobloUI] error in {self._name} handler:\n{err}`)
			end
		end
	end
	self._depth -= 1

	if self._depth == 0 and self._dirty then
		self:_compact()
	end
end

function Signal:Wait()
	local co = coroutine.running()
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		task.spawn(co, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	for _, conn in self._conns do
		conn.Connected = false
	end
	self._conns = {}
	self._dirty = false
end

function Signal:GetConnectionCount(): number
	local n = 0
	for _, conn in self._conns do
		if conn.Connected then
			n += 1
		end
	end
	return n
end

Signal.Destroy = Signal.DisconnectAll

return Signal
