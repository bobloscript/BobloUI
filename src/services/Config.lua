--!nonstrict

local HttpService = game:GetService("HttpService")

local Signal = require("@runtime/Signal")
local Util = require("@runtime/Util")
local Storage = require("@services/Storage")
local Env = require("@runtime/Env")

local Config = {}
Config.__index = Config

local CURRENT = 1

local function serialize(value, seen)
	local kind = typeof(value)
	if kind == "Color3" then
		return { __type = "Color3", Hex = value:ToHex() }
	end
	if kind == "Vector2" then
		return { __type = "Vector2", X = value.X, Y = value.Y }
	end
	if kind == "Vector3" then
		return { __type = "Vector3", X = value.X, Y = value.Y, Z = value.Z }
	end
	if kind == "UDim" then
		return { __type = "UDim", Scale = value.Scale, Offset = value.Offset }
	end
	if kind == "UDim2" then
		return {
			__type = "UDim2",
			XS = value.X.Scale,
			XO = value.X.Offset,
			YS = value.Y.Scale,
			YO = value.Y.Offset,
		}
	end
	if kind == "EnumItem" then
		return { __type = "EnumItem", Enum = tostring(value.EnumType), Name = value.Name }
	end
	if type(value) == "table" then
		seen = seen or {}
		if seen[value] then
			error("[BobloUI] Config cannot serialize a cyclic table.", 0)
		end
		seen[value] = true
		local out = {}
		for key, child in value do
			out[key] = serialize(child, seen)
		end
		seen[value] = nil
		return out
	end
	if type(value) == "number" or type(value) == "string" or type(value) == "boolean" or value == nil then
		return value
	end
	return tostring(value)
end

local function deserialize(value)
	if type(value) ~= "table" then
		return value
	end
	if value.__type == "Color3" then
		local ok, colour = pcall(Color3.fromHex, value.Hex)
		return if ok then colour else Color3.new(1, 1, 1)
	end
	if value.__type == "Vector2" then
		return Vector2.new(value.X or 0, value.Y or 0)
	end
	if value.__type == "Vector3" then
		return Vector3.new(value.X or 0, value.Y or 0, value.Z or 0)
	end
	if value.__type == "UDim" then
		return UDim.new(value.Scale or 0, value.Offset or 0)
	end
	if value.__type == "UDim2" then
		return UDim2.new(value.XS or 0, value.XO or 0, value.YS or 0, value.YO or 0)
	end
	if value.__type == "EnumItem" then
		local enumName = string.match(value.Enum or "", "Enum%.(.+)")
		local enumType = enumName and Enum[enumName]
		return if enumType then enumType[value.Name] else value.Name
	end
	local out = {}
	for key, child in value do
		out[key] = deserialize(child)
	end
	return out
end

local function decode(raw, label)
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(data) ~= "table" then
		return nil, `{label or "config"} is not a valid JSON object`
	end
	return data
end

local function serviceValue(service, getter, defaultValue)
	if service ~= nil then
		local value = getter(service)
		if value ~= nil then
			return value
		end
	end
	return defaultValue
end

function Config.new(window, folder)
	local self = setmetatable({
		Saved = Signal.new("Config.Saved"),
		Loaded = Signal.new("Config.Loaded"),
		_window = window,
		_storage = Storage.new(folder),
		_folder = folder,
		_migrations = {},
		_pending = {},
		_orphans = {},
		_ignored = {},
		_pendingCollapsed = {},
		_autoload = nil,
	}, Config)

	self._registryConn = window.Registry.Added:Connect(function(entry)
		if entry.Id and self._pending[entry.Id] ~= nil then
			local value = self._pending[entry.Id]
			self._pending[entry.Id] = nil
			self._orphans[entry.Id] = nil
			window.State:Set(entry.Id, value, { Source = "CONFIG", Silent = false })
		end
		if entry.Id and self._pendingCollapsed[entry.Id] ~= nil and entry.Handle and entry.Handle.SetCollapsed then
			local value = self._pendingCollapsed[entry.Id]
			self._pendingCollapsed[entry.Id] = nil
			entry.Handle:SetCollapsed(value)
		end
	end)

	local autoload = self._storage:Read("autoload.txt")
	if autoload and autoload ~= "" then
		self._autoload = autoload
	end
	return self
end

function Config:SetFolder(folder)
	self._folder = folder
	self._storage = Storage.new(folder)
	local autoload = self._storage:Read("autoload.txt")
	self._autoload = if autoload and autoload ~= "" then autoload else nil
	return self
end

function Config:_file(name)
	return `configs/{name}.json`
end

function Config:_ensureConfigDir()
	if Env.FS and not Env.FS.IsFolder(self._storage.Root .. "/configs") then
		Env.FS.MakeFolder(self._storage.Root .. "/configs")
	end
end

function Config:List()
	local out = {}
	local entries = if Env.FS then Env.FS.List(self._storage.Root .. "/configs") else self._storage:List()
	for _, path in entries do
		local name = string.match(path, "([^/\\]+)%.json$")
		if name and name ~= "autoload" then
			table.insert(out, name)
		end
	end
	table.sort(out)
	return out
end

function Config:SetIgnored(id, value)
	self._ignored[id] = value == true
	return self
end

function Config:_existingEnvelope(name)
	local raw = self._storage:Read(self:_file(name))
	if not raw then
		return {}
	end
	local data, err = decode(raw, "existing config")
	if not data then
		return nil, err
	end
	return data
end

function Config:Save(name)
	if type(name) ~= "string" or name == "" then
		return false, "invalid name"
	end
	self:_ensureConfigDir()

	local envelope, existingError = self:_existingEnvelope(name)
	if not envelope then
		return false, existingError
	end

	local existingValues = if type(envelope.values) == "table" then envelope.values else {}
	local values = {}
	for id, rawValue in existingValues do
		if not self._window.Registry:Has(id) then
			values[id] = rawValue
		end
	end

	local okValues, valuesError = xpcall(function()
		for _, entry in self._window.Registry:GetPersistable() do
			if not self._ignored[entry.Id] then
				values[entry.Id] = serialize(entry.Handle:GetValue())
			end
		end
		for id, value in self._orphans do
			if values[id] == nil then
				values[id] = serialize(value)
			end
		end
	end, debug.traceback)
	if not okValues then
		return false, valuesError
	end

	local collapsed = {}
	for _, tab in self._window._tabs or {} do
		for _, section in tab._sections or {} do
			if section.Id then
				collapsed[section.Id] = section.Collapsed == true
			end
		end
	end

	local geometry = nil
	if self._window.GetRememberGeometry and self._window:GetRememberGeometry() then
		geometry = self._window:GetGeometry()
	end

	local themeData = nil
	if self._window.Theme.Export ~= nil then
		themeData = self._window.Theme:Export()
	end
	local scale = 1
	if self._window.GetScale ~= nil then
		scale = self._window:GetScale()
	end
	local locale = "en"
	if self._window.Locale ~= nil then
		locale = self._window.Locale:Get()
	end
	local favorites = {}
	if self._window.Favorites ~= nil then
		favorites = self._window.Favorites:List()
	end
	local reducedMotion = false
	if self._window.Motion ~= nil then
		reducedMotion = not self._window.Motion.Enabled
	end

	local keyboardNavigation = serviceValue(self._window.Navigation, function(service)
		return service:IsEnabled()
	end, true)
	local uiSounds = serviceValue(self._window.Sound, function(service)
		return service:IsEnabled()
	end, true)
	local soundVolume = serviceValue(self._window.Sound, function(service)
		return service:GetVolume()
	end, 1)

	local meta = if type(envelope.meta) == "table" then Util.deepCopy(envelope.meta) else {}
	meta.theme = self._window.Theme:Current()
	meta.themeData = themeData
	meta.accent = serialize(self._window.Theme:Get("Accent"))
	meta.density = self._window.Tokens:GetDensity()
	meta.scale = scale
	meta.locale = locale
	meta.favorites = favorites
	meta.collapsed = collapsed
	meta.geometry = serialize(geometry)
	meta.reducedMotion = reducedMotion
	meta.keyboardNavigation = keyboardNavigation
	meta.uiSounds = uiSounds
	meta.soundVolume = soundVolume

	envelope["$schema"] = CURRENT
	envelope.name = name
	envelope.library = "BobloUI"
	envelope.libraryVersion = self._window.Version
	envelope.savedAt = os.time()
	envelope.values = values
	envelope.meta = meta

	local ok, json = pcall(HttpService.JSONEncode, HttpService, envelope)
	if not ok then
		return false, json
	end
	local wrote = self._storage:Write(self:_file(name), json)
	if wrote then
		self.Saved:Fire(name)
	end
	return wrote, if wrote then nil else "write failed"
end

function Config:Load(name)
	local raw = self._storage:Read(self:_file(name))
	if not raw then
		return false, "config not found"
	end
	local data, decodeError = decode(raw)
	if not data then
		return false, decodeError
	end
	if data.values ~= nil and type(data.values) ~= "table" then
		return false, "invalid config: values must be an object"
	end

	local version = tonumber(data["$schema"]) or 0
	if version < CURRENT then
		self._storage:Write(self:_file(name) .. ".bak", raw)
		while version < CURRENT do
			local migration = self._migrations[version]
			if not migration then
				return false, `[BobloUI] missing config migration {version} -> {version + 1}.`
			end
			local okMigration, result = xpcall(migration, debug.traceback, data)
			if not okMigration then
				return false, result
			end
			data = result or data
			version += 1
			data["$schema"] = version
		end
	end

	self._pending = {}
	self._orphans = {}
	self._window.State:Batch(function()
		for id, rawValue in data.values or {} do
			local value = deserialize(rawValue)
			if self._window.Registry:Has(id) then
				self._window.State:Set(id, value, { Source = "CONFIG" })
			else
				self._pending[id] = value
				self._orphans[id] = value
			end
		end
	end)

	local meta = if type(data.meta) == "table" then data.meta else {}
	if meta.themeData and self._window.ImportTheme then
		pcall(function()
			self._window:ImportTheme(meta.themeData)
		end)
	elseif meta.theme then
		pcall(function()
			self._window:SetTheme(meta.theme)
		end)
	end
	if meta.accent and not meta.themeData then
		pcall(function()
			self._window:SetAccent(deserialize(meta.accent))
		end)
	end
	if meta.density then
		pcall(function()
			self._window:SetDensity(meta.density)
		end)
	end
	if meta.scale and self._window.SetScale then
		pcall(function()
			self._window:SetScale(meta.scale)
		end)
	end
	if meta.locale and self._window.SetLocale then
		pcall(function()
			self._window:SetLocale(meta.locale)
		end)
	end
	if self._window.Favorites and type(meta.favorites) == "table" then
		self._window.Favorites:Set(meta.favorites)
	end
	if meta.reducedMotion ~= nil and self._window.SetReducedMotion then
		pcall(function()
			self._window:SetReducedMotion(meta.reducedMotion == true)
		end)
	end
	if meta.keyboardNavigation ~= nil and self._window.SetKeyboardNavigation then
		pcall(function()
			self._window:SetKeyboardNavigation(meta.keyboardNavigation ~= false)
		end)
	end
	if meta.uiSounds ~= nil and self._window.SetUISounds then
		pcall(function()
			self._window:SetUISounds(meta.uiSounds ~= false)
		end)
	end
	if meta.soundVolume ~= nil and self._window.SetSoundVolume then
		pcall(function()
			self._window:SetSoundVolume(meta.soundVolume)
		end)
	end

	if type(meta.collapsed) == "table" then
		for id, value in meta.collapsed do
			local section = self._window:Get(id)
			if section and section.SetCollapsed then
				section:SetCollapsed(value == true)
			else
				self._pendingCollapsed[id] = value == true
			end
		end
	end

	if meta.geometry and self._window.GetRememberGeometry and self._window:GetRememberGeometry() then
		local geometry = deserialize(meta.geometry)
		if type(geometry) == "table" then
			if geometry.Size then
				self._window:SetSize(geometry.Size)
			end
			if geometry.Position then
				self._window:SetPosition(geometry.Position)
			end
			if geometry.Scale then
				self._window:SetScale(geometry.Scale)
			end
			if geometry.Locked ~= nil then
				self._window:SetLocked(geometry.Locked)
			end
			if geometry.SidebarWidth and self._window.SetSidebarWidth then
				self._window:SetSidebarWidth(geometry.SidebarWidth)
			end
			if geometry.SidebarHidden ~= nil and self._window.SetSidebarHidden then
				self._window:SetSidebarHidden(geometry.SidebarHidden)
			end
			if geometry.Compact ~= nil and self._window.SetCompact then
				self._window:SetCompact(geometry.Compact)
			end
			if geometry.SidebarCompacted ~= nil and self._window.SetSidebarCompacted then
				self._window:SetSidebarCompacted(geometry.SidebarCompacted)
			end
		end
	end

	self.Loaded:Fire(name)
	return true
end

function Config:Delete(name)
	local raw = self._storage:Read(self:_file(name))
	local deleted = self._storage:Delete(self:_file(name))
	if deleted and self._autoload == name then
		if not self._storage:Write("autoload.txt", "") then
			-- Keep the profile and the pointer consistent if the second write fails.
			if raw ~= nil then
				self._storage:Write(self:_file(name), raw)
			end
			return false, "autoload update failed"
		end
		self._autoload = nil
	end
	return deleted, if deleted then nil else "delete failed"
end

function Config:Rename(fromName, toName)
	if type(fromName) ~= "string" or fromName == "" or type(toName) ~= "string" or toName == "" then
		return false, "invalid name"
	end
	if fromName == toName then
		return true
	end
	local raw = self._storage:Read(self:_file(fromName))
	if not raw then
		return false, "not found"
	end
	if self._storage:Exists(self:_file(toName)) then
		return false, "destination exists"
	end
	if not self._storage:Write(self:_file(toName), raw) then
		return false, "write failed"
	end
	local updatesAutoload = self._autoload == fromName
	if updatesAutoload and not self._storage:Write("autoload.txt", toName) then
		self._storage:Delete(self:_file(toName))
		return false, "autoload update failed"
	end
	if not self._storage:Delete(self:_file(fromName)) then
		self._storage:Delete(self:_file(toName))
		if updatesAutoload then
			self._storage:Write("autoload.txt", fromName)
		end
		return false, "delete failed"
	end
	if updatesAutoload then
		self._autoload = toName
	end
	return true
end

function Config:Duplicate(fromName, toName)
	local raw = self._storage:Read(self:_file(fromName))
	if not raw then
		return false, "not found"
	end
	return self._storage:Write(self:_file(toName), raw)
end

function Config:Export(name)
	local raw = self._storage:Read(self:_file(name))
	if raw then
		Env.SetClipboard(raw)
	end
	return raw
end

function Config:Import(json, name)
	if type(name) ~= "string" or name == "" then
		return false, "invalid name"
	end
	local data = decode(json, "import")
	if not data then
		return false, "invalid json"
	end
	if data.values ~= nil and type(data.values) ~= "table" then
		return false, "invalid config: values must be an object"
	end
	self:_ensureConfigDir()
	return self._storage:Write(self:_file(name), json)
end

function Config:SetAutoLoad(name)
	if name == "" then
		name = nil
	end
	if self._storage:Write("autoload.txt", name or "") then
		self._autoload = name
	else
		warn("[BobloUI] failed to update config autoload pointer.")
	end
	return self
end

function Config:GetAutoLoad()
	return self._autoload
end

function Config:LoadAuto()
	if self._autoload then
		return self:Load(self._autoload)
	end
	return false, "no autoload"
end

function Config:RegisterMigration(fromVersion, toVersion, callback)
	if toVersion ~= fromVersion + 1 then
		error("[BobloUI] config migrations must be linear (N -> N+1).", 2)
	end
	self._migrations[fromVersion] = callback
	return self
end

function Config:Destroy()
	if self._registryConn then
		self._registryConn:Disconnect()
	end
	self.Saved:Destroy()
	self.Loaded:Destroy()
	self._pending = {}
	self._orphans = {}
	self._pendingCollapsed = {}
end

return Config
