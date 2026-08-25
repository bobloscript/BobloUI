--!nonstrict
local HttpService = game:GetService("HttpService")
local Storage = require("@services/Storage")
local ThemeManager = {}
ThemeManager.__index = ThemeManager

local REQUIRED_COLOR_TOKENS = {
	"Canvas",
	"Background",
	"Sidebar",
	"Surface",
	"SurfaceRaised",
	"SurfaceInset",
	"SurfaceSecondary",
	"SurfaceHover",
	"SurfaceActive",
	"Control",
	"ControlHover",
	"ControlPressed",
	"ControlInset",
	"BorderSubtle",
	"Border",
	"BorderStrong",
	"Text",
	"TextSecondary",
	"TextTertiary",
	"TextDisabled",
	"Accent",
	"Success",
	"Warning",
	"Error",
	"Info",
	"Scrim",
}
local BASE_TOKEN_SET = { ScrimTransparency = true }
for _, token in REQUIRED_COLOR_TOKENS do
	BASE_TOKEN_SET[token] = true
end

local function validName(name)
	return type(name) == "string" and name ~= "" and string.match(name, "^[A-Za-z0-9_.%-]+$") ~= nil
end
local function encodePalette(palette)
	local out = {}
	for token, value in palette or {} do
		if BASE_TOKEN_SET[token] and typeof(value) == "Color3" then
			out[token] = "#" .. value:ToHex()
		elseif token == "ScrimTransparency" and type(value) == "number" then
			out[token] = value
		end
	end
	return out
end
local function decodePalette(palette)
	local out = {}
	for token, value in palette or {} do
		if BASE_TOKEN_SET[token] and type(value) == "string" then
			local ok, color = pcall(Color3.fromHex, string.gsub(value, "#", ""))
			if ok then
				out[token] = color
			end
		elseif token == "ScrimTransparency" and type(value) == "number" then
			out[token] = value
		end
	end
	if out.ScrimTransparency == nil then
		out.ScrimTransparency = 0.52
	end
	return out
end
local function validatePalette(palette)
	if type(palette) ~= "table" then
		return false, "palette must be a table"
	end
	for _, token in REQUIRED_COLOR_TOKENS do
		if typeof(palette[token]) ~= "Color3" then
			return false, `palette token "{token}" must be Color3`
		end
	end
	if palette.ScrimTransparency == nil then
		palette.ScrimTransparency = 0.52
	elseif type(palette.ScrimTransparency) ~= "number" then
		return false, 'palette token "ScrimTransparency" must be number'
	end
	palette.ScrimTransparency = math.clamp(palette.ScrimTransparency, 0, 1)
	return true
end

function ThemeManager.new(window, folder)
	local self = setmetatable({
		_window = window,
		_storage = Storage.new((folder or window.Id or "Default") .. "/themes"),
		_custom = {},
		_default = nil,
	}, ThemeManager)
	self:ReloadCustomThemes()
	self:_loadDefaultMarker()
	return self
end

function ThemeManager:_loadDefaultMarker()
	local default = self._storage:Read("default.txt")
	if default == "Dark" or default == "Light" or self._custom[default] then
		self._default = default
	elseif default and default ~= "" then
		self._storage:Write("default.txt", "")
	end
	return self._default
end

function ThemeManager:_file(name)
	return name .. ".json"
end

function ThemeManager:_refreshSettings()
	local settings = self._window.Settings
	if settings and settings.RefreshThemeOptions then
		settings:RefreshThemeOptions()
	end
end

function ThemeManager:SetFolder(folder)
	if type(folder) ~= "string" or folder == "" then
		return false, "theme folder must be a non-empty string"
	end
	self._storage = Storage.new(folder .. "/themes")
	self._default = nil
	self:ReloadCustomThemes()
	self:_loadDefaultMarker()
	return true
end

function ThemeManager:SaveCustomTheme(name, palette)
	if not validName(name) then
		return false, "theme name may contain only A-Z, a-z, 0-9, _, ., -"
	end
	if name == "Dark" or name == "Light" then
		return false, "built-in themes cannot be overwritten"
	end
	palette = palette or self._window.Theme:Palette()
	local valid, validationError = validatePalette(palette)
	if not valid then
		return false, validationError
	end
	local payload = { Name = name, Palette = encodePalette(palette), SavedAt = os.time() }
	local ok, raw = pcall(HttpService.JSONEncode, HttpService, payload)
	if not ok then
		return false, raw
	end
	if not self._storage:Write(self:_file(name), raw) then
		return false, "write failed"
	end
	local decoded = decodePalette(payload.Palette)
	self._custom[name] = decoded
	self._window.Theme:Register(name, decoded)
	self:_refreshSettings()
	return true
end

function ThemeManager:DeleteCustomTheme(name)
	if not self._custom[name] then
		return false, "theme not found"
	end
	if self._window.Theme:Current() == name then
		self._window.Theme:Set("Dark")
	end
	if not self._storage:Delete(self:_file(name)) then
		return false, "delete failed"
	end
	self._custom[name] = nil
	self._window.Theme:Unregister(name)
	if self._default == name then
		self:SetDefault(nil)
	end
	self:_refreshSettings()
	return true
end

function ThemeManager:ReloadCustomThemes()
	local previous = self._custom
	local active = self._window.Theme:Current()
	for name in previous do
		if self._window.Theme:Current() ~= name then
			pcall(function()
				self._window.Theme:Unregister(name)
			end)
		end
	end
	self._custom = {}
	for _, path in self._storage:List() do
		local name = string.match(path, "([^/\\]+)%.json$")
		if name then
			local raw = self._storage:Read(self:_file(name))
			local ok, data = pcall(HttpService.JSONDecode, HttpService, raw or "")
			if ok and type(data) == "table" and type(data.Palette) == "table" then
				local palette = decodePalette(data.Palette)
				if validatePalette(palette) then
					self._custom[name] = palette
					self._window.Theme:Register(name, palette)
				end
			end
		end
	end
	if previous[active] and not self._custom[active] then
		self._window.Theme:Set("Dark")
		self._window.Theme:Unregister(active)
		if self._default == active then
			self:SetDefault(nil)
		end
	end
	self:_refreshSettings()
	return self:ListCustomThemes()
end

function ThemeManager:ListCustomThemes()
	local out = {}
	for name in self._custom do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

function ThemeManager:Load(name)
	if name ~= "Dark" and name ~= "Light" and not self._custom[name] then
		return false, "theme not found"
	end
	self._window.Theme:Set(name)
	return true
end

function ThemeManager:ApplyTheme(name)
	return self:Load(name)
end

function ThemeManager:GetCustomTheme(name)
	local palette = self._custom[name]
	return palette and table.clone(palette) or nil
end

function ThemeManager:SetDefault(name)
	if name ~= nil and name ~= "Dark" and name ~= "Light" and not self._custom[name] then
		return false, "theme not found"
	end
	if not self._storage:Write("default.txt", name or "") then
		return false, "write failed"
	end
	self._default = name
	return true
end

function ThemeManager:SaveDefault(name)
	return self:SetDefault(name)
end

function ThemeManager:GetDefault()
	return self._default
end

function ThemeManager:LoadDefault()
	if not self._default then
		return false, "no default theme"
	end
	if not self._window.Theme:GetRegistered(self._default) then
		self:SetDefault(nil)
		return false, "default theme is no longer available"
	end
	self._window.Theme:Set(self._default)
	return true
end

function ThemeManager:Destroy()
	self._custom = {}
end

return ThemeManager
