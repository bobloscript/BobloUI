--!nonstrict
local Signal = require("@runtime/Signal")
local Favorites = {}
Favorites.__index = Favorites
function Favorites.new(registry)
	return setmetatable({ Changed = Signal.new("Favorites.Changed"), _registry = registry, _set = {} }, Favorites)
end
function Favorites:Add(id)
	if type(id) == "string" and not self._set[id] then
		self._set[id] = true
		self.Changed:Fire(id, true)
	end
	return self
end
function Favorites:Remove(id)
	if self._set[id] then
		self._set[id] = nil
		self.Changed:Fire(id, false)
	end
	return self
end
function Favorites:Toggle(id)
	if self._set[id] then
		return self:Remove(id)
	else
		return self:Add(id)
	end
end
function Favorites:Has(id)
	return self._set[id] == true
end
function Favorites:List()
	local o = {}
	for id in self._set do
		table.insert(o, id)
	end
	table.sort(o)
	return o
end
function Favorites:Set(ids)
	self._set = {}
	for _, id in ids or {} do
		if type(id) == "string" then
			self._set[id] = true
		end
	end
	self.Changed:Fire(nil, nil)
end
function Favorites:Destroy()
	self.Changed:Destroy()
	self._set = {}
end
return Favorites
