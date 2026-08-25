--!nonstrict
local Signal = require("@runtime/Signal")
local Locale = {}
Locale.__index = Locale
function Locale.new(initial)
	return setmetatable(
		{ Changed = Signal.new("Locale.Changed"), _name = initial or "en", _locales = { en = {} } },
		Locale
	)
end
function Locale:Register(name, dict)
	self._locales[name] = table.clone(dict or {})
end
function Locale:Add(name, dict)
	local target = self._locales[name] or {}
	self._locales[name] = target
	for k, v in dict do
		target[k] = v
	end
end
function Locale:Set(name)
	if not self._locales[name] then
		warn(`[BobloUI] locale "{name}" is not registered.`)
	end
	if self._name ~= name then
		self._name = name
		self.Changed:Fire(name)
	end
end
function Locale:Get()
	return self._name
end
function Locale:List()
	local out = {}
	for name in self._locales do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end
function Locale:T(key, vars)
	local dict = self._locales[self._name] or {}
	local fallback = self._locales.en or {}
	local text = dict[key] or fallback[key] or key
	if vars then
		for k, v in vars do
			text = string.gsub(text, "{" .. k .. "}", tostring(v))
		end
	end
	return text
end
function Locale:Resolve(value)
	if type(value) == "string" and string.sub(value, 1, 1) == "@" then
		return self:T(string.sub(value, 2))
	end
	return value
end
function Locale:Destroy()
	self.Changed:Destroy()
	self._locales = {}
end
return Locale
