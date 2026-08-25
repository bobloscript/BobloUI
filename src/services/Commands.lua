--!nonstrict
local Commands = {}
Commands.__index = Commands
function Commands.new(window)
	return setmetatable({ _window = window, _commands = {} }, Commands)
end
function Commands:Register(c)
	if type(c) ~= "table" or type(c.Id) ~= "string" or type(c.Title) ~= "string" or type(c.Callback) ~= "function" then
		error("[BobloUI] Commands:Register requires Id, Title, Callback.", 2)
	end
	self._commands[c.Id] = c
	return c
end
function Commands:Unregister(id)
	self._commands[id] = nil
end
function Commands:Run(id)
	local c = self._commands[id]
	if not c then
		return false
	end
	if c.EnabledWhen and not c.EnabledWhen(self._window.State) then
		return false
	end
	local ok, err = xpcall(c.Callback, debug.traceback)
	if not ok then
		warn(`[BobloUI] command "{id}" failed:\n{err}`)
	end
	return ok
end
function Commands:List()
	local o = {}
	for _, c in self._commands do
		table.insert(o, c)
	end
	table.sort(o, function(a, b)
		return a.Title < b.Title
	end)
	return o
end
function Commands:Query(text)
	local q = string.lower(text or "")
	local o = {}
	for _, c in self._commands do
		local hay = string.lower(c.Title .. " " .. table.concat(c.Keywords or {}, " "))
		if q == "" or string.find(hay, q, 1, true) then
			table.insert(
				o,
				{ Kind = "Command", Id = c.Id, Title = c.Title, Icon = c.Icon, Callback = c.Callback, Command = c }
			)
		end
	end
	table.sort(o, function(a, b)
		return a.Title < b.Title
	end)
	return o
end
function Commands:Destroy()
	self._commands = {}
end
return Commands
