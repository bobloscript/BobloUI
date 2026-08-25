--!nonstrict
local Signal = require("@runtime/Signal")
local Registry = {}
Registry.__index = Registry
function Registry.new()
	return setmetatable({
		Added = Signal.new("Registry.Added"),
		Updated = Signal.new("Registry.Updated"),
		Removed = Signal.new("Registry.Removed"),
		_byId = {},
		_entries = {},
		_anon = 0,
	}, Registry)
end
function Registry:AssertAvailable(id, level)
	if id and self._byId[id] then
		local old = self._byId[id]
		error(`[BobloUI] duplicate Id "{id}". First registered at {old.Path or old.Type or "unknown"}.`, level or 2)
	end
	return true
end
function Registry:Add(handle, meta)
	meta = meta or {}
	local id = meta.Id or handle.Id
	self:AssertAvailable(id, 2)
	local key = id
	if not key then
		self._anon += 1
		key = `__anon_{self._anon}`
	end
	local entry = {
		Key = key,
		Id = id,
		Handle = handle,
		Type = meta.Type or handle.Type,
		Title = meta.Title or handle.Title or "",
		Description = meta.Description or "",
		Keywords = meta.Keywords or {},
		Tab = meta.Tab,
		Section = meta.Section,
		Path = meta.Path,
		Persist = meta.Persist == true,
		Hidden = false,
	}
	self._entries[key] = entry
	if id then
		self._byId[id] = entry
	end
	handle._registryKey = key
	self.Added:Fire(entry)
	return entry
end
function Registry:Get(id)
	local e = self._byId[id]
	return e and e.Handle or nil
end
function Registry:GetEntry(id)
	return self._byId[id]
end
function Registry:Has(id)
	return self._byId[id] ~= nil
end
function Registry:Update(handle, fields)
	local e = self._entries[handle._registryKey or handle.Id]
	if not e then
		return
	end
	for k, v in fields do
		e[k] = v
	end
	self.Updated:Fire(e, fields)
end
function Registry:Remove(handleOrId)
	local e
	if type(handleOrId) == "string" then
		e = self._byId[handleOrId] or self._entries[handleOrId]
	else
		e = self._entries[handleOrId._registryKey or handleOrId.Id]
	end
	if not e then
		return
	end
	self._entries[e.Key] = nil
	if e.Id then
		self._byId[e.Id] = nil
	end
	self.Removed:Fire(e)
end
function Registry:Entries()
	local out = {}
	for _, e in self._entries do
		table.insert(out, e)
	end
	return out
end
function Registry:GetPersistable()
	local out = {}
	for _, e in self._entries do
		if e.Id and e.Persist and e.Handle and not e.Handle._destroyed then
			table.insert(out, e)
		end
	end
	return out
end
function Registry:Destroy()
	self.Added:Destroy()
	self.Updated:Destroy()
	self.Removed:Destroy()
	self._byId = {}
	self._entries = {}
end
return Registry
