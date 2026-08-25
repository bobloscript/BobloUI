--!nonstrict
-- Built-in settings center. Uses only public window/tab/section/control APIs.
local Env = require("@runtime/Env")
local Settings = {}
Settings.__index = Settings

local THEME_COLOR_TOKENS = {
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
	"Success",
	"Warning",
	"Error",
	"Info",
	"Scrim",
}

local function clearSection(section)
	for _, control in table.clone(section._controls or {}) do
		control:Destroy()
	end
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

function Settings.new(window, options)
	local self = setmetatable(
		{ _window = window, _options = options or {}, _mounted = false, _refreshing = false, _tokenControls = {} },
		Settings
	)
	window._settingsService = self
	return self
end

function Settings:_profileOptions()
	local list = self._window.Config and self._window.Config:List() or {}
	if #list == 0 then
		return { "Default" }
	end
	return list
end

function Settings:_refreshProfiles()
	if self._profileDrop then
		self._profileDrop:SetOptions(self:_profileOptions())
	end
end

function Settings:_refreshFavorites()
	if not self._favoritesSection or self._refreshing then
		return
	end
	self._refreshing = true
	clearSection(self._favoritesSection)
	local ids = self._window.Favorites:List()
	if #ids == 0 then
		self._favoritesSection:AddParagraph({ Content = "@settings.favorites.empty" })
	else
		for _, id in ids do
			local handle = self._window:Get(id)
			if handle and not handle._destroyed then
				self._favoritesSection:AddButton({
					Title = handle.Title or id,
					Text = "@settings.open",
					Variant = "Ghost",
					Callback = function()
						handle:Reveal()
					end,
					ContextMenu = {
						{
							Text = "@settings.removeFavorite",
							Callback = function()
								self._window.Favorites:Remove(id)
							end,
						},
					},
				})
			end
		end
	end
	self._refreshing = false
end

function Settings:_refreshKeybinds()
	if not self._keybindSection or self._refreshing then
		return
	end
	self._refreshing = true
	clearSection(self._keybindSection)
	local n = 0
	for _, entry in self._window.Registry:Entries() do
		if
			entry.Type == "Keybind"
			and entry.Handle
			and not entry.Handle._destroyed
			and not string.match(entry.Id or "", "^__settings")
		then
			n += 1
			local h = entry.Handle
			local current = h:GetValue()
			local key = (type(current) == "table" and current.Key) or "None"
			self._keybindSection:AddButton({
				Title = h.Title or entry.Id,
				Text = tostring(key),
				Variant = "Ghost",
				Callback = function()
					h:Reveal()
					task.defer(function()
						h:Capture()
					end)
				end,
			})
		end
	end
	if n == 0 then
		self._keybindSection:AddParagraph({ Content = "@settings.keybinds.empty" })
	end
	self._refreshing = false
end

function Settings:_buildConfig(section)
	local w = self._window
	if not w.Config then
		section:AddParagraph({ Variant = "Info", Content = "@settings.config.disabled" })
		return
	end
	self._profileName = section:AddInput({
		Id = "__settings.configName",
		Title = "@settings.config.name",
		Icon = "file-pen",
		Default = "Default",
		IgnoreConfig = true,
		Adaptive = true,
	})
	self._profileDrop = section:AddDropdown({
		Id = "__settings.configProfile",
		Title = "@settings.config.profile",
		Icon = "folder-open",
		Options = self:_profileOptions(),
		Default = self:_profileOptions()[1],
		AllowNone = true,
		IgnoreConfig = true,
		Adaptive = true,
	})
	local function chosen()
		return self._profileDrop:GetValue() or self._profileName:GetValue() or "Default"
	end
	section:AddButton({
		Title = "@settings.config.save",
		Icon = "save",
		Text = "@settings.save",
		Variant = "Primary",
		Callback = function()
			local ok, err = w.Config:Save(self._profileName:GetValue() or chosen())
			if ok then
				self:_refreshProfiles()
				w.Notify:Push({ Title = w.Locale:T("settings.saved"), Variant = "Success" })
			else
				w.Notify:Push({ Title = tostring(err), Variant = "Error" })
			end
		end,
	})
	section:AddButton({
		Title = "@settings.config.load",
		Icon = "folder-open",
		Text = "@settings.load",
		Callback = function()
			local ok, err = w.Config:Load(chosen())
			if not ok then
				w.Notify:Push({ Title = tostring(err), Variant = "Error" })
			end
		end,
	})
	section:AddButton({
		Title = "@settings.config.autoload",
		Icon = "circle-check",
		Text = "@settings.set",
		Callback = function()
			w.Config:SetAutoLoad(chosen())
			w.Notify:Push({ Title = w.Locale:T("settings.autoloadSet"), Variant = "Success" })
		end,
	})
	section:AddButton({
		Title = "@settings.config.duplicate",
		Icon = "copy",
		Text = "@settings.duplicate",
		Callback = function()
			task.spawn(function()
				local name =
					w.Dialog:Prompt({ Title = w.Locale:T("settings.config.duplicate"), Placeholder = "Copy" }):Await()
				if name and name ~= "" then
					w.Config:Duplicate(chosen(), name)
					self:_refreshProfiles()
				end
			end)
		end,
	})
	section:AddButton({
		Title = "@settings.config.rename",
		Icon = "file-pen",
		Text = "@settings.rename",
		Callback = function()
			task.spawn(function()
				local name =
					w.Dialog:Prompt({ Title = w.Locale:T("settings.config.rename"), Default = chosen() }):Await()
				if name and name ~= "" then
					w.Config:Rename(chosen(), name)
					self:_refreshProfiles()
				end
			end)
		end,
	})
	section:AddButton({
		Title = "@settings.config.delete",
		Icon = "trash-2",
		Text = "@settings.delete",
		Variant = "Danger",
		Callback = function()
			task.spawn(function()
				if
					w.Dialog
						:Confirm({ Title = w.Locale:T("settings.config.delete"), Content = chosen(), Danger = true })
						:Await()
				then
					w.Config:Delete(chosen())
					self:_refreshProfiles()
				end
			end)
		end,
	})
	section:AddButton({
		Title = "@settings.config.export",
		Icon = "upload",
		Text = "@settings.export",
		Callback = function()
			local raw = w.Config:Export(chosen())
			if raw then
				w.Notify:Push({ Title = w.Locale:T("settings.copied"), Variant = "Success" })
			end
		end,
	})
	section:AddButton({
		Title = "@settings.config.import",
		Icon = "download",
		Text = "@settings.import",
		Callback = function()
			task.spawn(function()
				local raw = w.Dialog
					:Prompt({
						Title = w.Locale:T("settings.config.import"),
						Content = w.Locale:T("settings.config.paste"),
						Placeholder = "{...}",
					})
					:Await()
				if raw and raw ~= "" then
					local name =
						w.Dialog:Prompt({ Title = w.Locale:T("settings.config.name"), Default = "Imported" }):Await()
					if name then
						local ok, err = w.Config:Import(raw, name)
						if ok then
							self:_refreshProfiles()
						else
							w.Notify:Push({ Title = tostring(err), Variant = "Error" })
						end
					end
				end
			end)
		end,
	})
end

function Settings:_syncAppearance()
	if not self._mounted then
		return
	end
	local w = self._window
	if self._themeControl then
		self._themeControl:SetOptions(w.Theme:List())
		self._themeControl:SetValue(w.Theme:Current(), true)
	end
	if self._accentControl then
		self._accentControl:SetValue(w.Theme:Get("Accent"), true)
	end
	if self._scaleControl then
		self._scaleControl:SetValue(math.floor((w:GetScale() or 1) * 100 + 0.5), true)
	end
	if self._radiusControl then
		self._radiusControl:SetValue(
			serviceValue(w, function(window)
				if window.GetCornerRadius ~= nil then
					return window:GetCornerRadius()
				end
				return nil
			end, 0),
			true
		)
	end
	if self._densityControl then
		self._densityControl:SetValue(w.Tokens:GetDensity(), true)
	end
	if self._localeControl then
		self._localeControl:SetOptions(w.Locale:List())
		self._localeControl:SetValue(w.Locale:Get(), true)
	end
	if self._motionControl then
		self._motionControl:SetValue(not w.Motion.Enabled, true)
	end
	if self._contrastControl then
		self._contrastControl:SetValue(w.Theme:IsHighContrast(), true)
	end
	if self._navigationControl and w.Navigation then
		self._navigationControl:SetValue(w.Navigation:IsEnabled(), true)
	end
	if self._sidebarControl and w.IsSidebarHidden then
		self._sidebarControl:SetValue(w:IsSidebarHidden(), true)
	end
	if self._opacityControl and w.GetWindowOpacity then
		self._opacityControl:SetValue(math.floor(w:GetWindowOpacity() * 100 + 0.5), true)
	end
	if self._cursorControl and w.Cursor then
		self._cursorControl:SetValue(w.Cursor:IsEnabled(), true)
	end
	if self._soundsControl and w.Sound then
		self._soundsControl:SetValue(w.Sound:IsEnabled(), true)
	end
	if self._soundVolumeControl and w.Sound then
		self._soundVolumeControl:SetValue(math.floor(w.Sound:GetVolume() * 100 + 0.5), true)
	end
	for token, control in self._tokenControls do
		if control and not control._destroyed then
			control:SetValue(w.Theme:Get(token), true)
		end
	end
	if self._scrimTransparencyControl and not self._scrimTransparencyControl._destroyed then
		self._scrimTransparencyControl:SetValue(math.floor(w.Theme:Get("ScrimTransparency") * 100 + 0.5), true)
	end
end

function Settings:_ensureMounted()
	if self._mounted then
		return self
	end
	self._mounted = true
	local w = self._window
	local tab = w:AddTab({
		Id = "__bobloui_settings",
		Title = "@settings.title",
		Description = "@settings.description",
		Icon = "settings-2",
		Group = "@nav.system",
		Order = 999,
		_system = true,
	})
	self.Tab = tab
	local appearance = tab:AddSection({
		Id = "__settings.appearance",
		Title = "@settings.appearance",
		Description = "@settings.appearanceDesc",
		Icon = "palette",
		Span = "Auto",
	})
	self._themeControl = appearance:AddDropdown({
		Id = "__settings.theme",
		Title = "@settings.theme",
		Icon = "swatch-book",
		Options = w.Theme:List(),
		Default = w.Theme:Current(),
		IgnoreConfig = true,
		-- Showing the polarity is what makes the light/dark toggle legible:
		-- without it, users cannot tell why a switch landed where it did.
		FormatDisplayValue = function(value)
			local polarity = w.Theme:Polarity(value)
			if not polarity or value == polarity then
				return value
			end
			return `{value} · {polarity}`
		end,
		Callback = function(v)
			w:SetTheme(v)
		end,
	})
	self._accentControl = appearance:AddColorPicker({
		Id = "__settings.accent",
		Title = "@settings.accent",
		Icon = "pipette",
		Default = w.Theme:Get("Accent"),
		IgnoreConfig = true,
		Callback = function(v)
			local c = type(v) == "table" and v.Color or v
			if typeof(c) == "Color3" then
				w:SetAccent(c)
			end
		end,
	})
	self._scaleControl = appearance:AddSlider({
		Id = "__settings.scale",
		Title = "@settings.scale",
		Icon = "zoom-in",
		Min = 70,
		Max = 140,
		Step = 5,
		Default = math.floor((w._scale or 1) * 100 + 0.5),
		Suffix = "%",
		IgnoreConfig = true,
		Callback = function(v)
			w:SetScale(v / 100)
		end,
	})
	self._radiusControl = appearance:AddSlider({
		Id = "__settings.radius",
		Title = "Window corner radius",
		Icon = "square-round-corner",
		Min = 0,
		Max = 28,
		Step = 1,
		Default = serviceValue(w, function(window)
			if window.GetCornerRadius ~= nil then
				return window:GetCornerRadius()
			end
			return nil
		end, 0),
		Suffix = " px",
		IgnoreConfig = true,
		Callback = function(v)
			if w.SetCornerRadius then
				w:SetCornerRadius(v)
			end
		end,
	})
	self._densityControl = appearance:AddDropdown({
		Id = "__settings.density",
		Title = "@settings.density",
		Icon = "rows-3",
		Options = { "Compact", "Comfortable", "Touch" },
		Default = w.Tokens:GetDensity(),
		IgnoreConfig = true,
		Callback = function(v)
			w:SetDensity(v)
		end,
	})
	self._localeControl = appearance:AddDropdown({
		Id = "__settings.locale",
		Title = "@settings.language",
		Icon = "languages",
		Options = w.Locale:List(),
		Default = w.Locale:Get(),
		IgnoreConfig = true,
		Callback = function(v)
			w:SetLocale(v)
		end,
	})
	self._motionControl = appearance:AddToggle({
		Id = "__settings.motion",
		Title = "@settings.reducedMotion",
		Icon = "accessibility",
		Default = not w.Motion.Enabled,
		IgnoreConfig = true,
		Callback = function(v)
			w:SetReducedMotion(v)
		end,
	})
	self._contrastControl = appearance:AddToggle({
		Id = "__settings.contrast",
		Title = "@settings.highContrast",
		Icon = "sun-medium",
		Default = w.Theme:IsHighContrast(),
		IgnoreConfig = true,
		Callback = function(v)
			w:SetHighContrast(v)
		end,
	})
	self._navigationControl = appearance:AddToggle({
		Id = "__settings.navigation",
		Title = "@settings.keyboardNavigation",
		Icon = "keyboard",
		Default = serviceValue(w.Navigation, function(service)
			return service:IsEnabled()
		end, true),
		IgnoreConfig = true,
		Callback = function(v)
			w:SetKeyboardNavigation(v)
		end,
	})
	self._soundsControl = appearance:AddToggle({
		Id = "__settings.sounds",
		Title = "@settings.uiSounds",
		Icon = "volume-2",
		Default = serviceValue(w.Sound, function(service)
			return service:IsEnabled()
		end, true),
		IgnoreConfig = true,
		Callback = function(v)
			w:SetUISounds(v)
		end,
	})
	self._soundVolumeControl = appearance:AddSlider({
		Id = "__settings.soundVolume",
		Title = "@settings.soundVolume",
		Icon = "audio-lines",
		Min = 0,
		Max = 100,
		Step = 5,
		Default = serviceValue(w.Sound, function(service)
			local volume = service:GetVolume()
			if volume ~= nil then
				return math.floor(volume * 100 + 0.5)
			end
			return nil
		end, 100),
		Suffix = "%",
		IgnoreConfig = true,
		VisibleWhen = function(State)
			return State:Get("__settings.sounds") ~= false
		end,
		Callback = function(v)
			w:SetSoundVolume(v / 100)
		end,
	})

	local editor = tab:AddSection({
		Id = "__settings.themeEditor",
		Title = "@settings.themeEditor",
		Description = "@settings.themeEditorDesc",
		Icon = "paintbrush",
		Collapsible = true,
		Collapsed = true,
		Span = "Auto",
	})
	for _, token in THEME_COLOR_TOKENS do
		local name = token
		self._tokenControls[name] = editor:AddColorPicker({
			Id = "__settings.token." .. name,
			Title = name,
			Default = w.Theme:Get(name),
			IgnoreConfig = true,
			Callback = function(v)
				local c = type(v) == "table" and v.Color or v
				if typeof(c) == "Color3" then
					w.Theme:SetToken(name, c)
				end
			end,
		})
	end
	self._scrimTransparencyControl = editor:AddSlider({
		Id = "__settings.token.ScrimTransparency",
		Title = "Scrim transparency",
		Description = "Opacity of the backdrop behind dialogs and sheets",
		Min = 0,
		Max = 100,
		Step = 1,
		Default = math.floor(w.Theme:Get("ScrimTransparency") * 100 + 0.5),
		Suffix = "%",
		IgnoreConfig = true,
		Callback = function(value)
			w.Theme:SetToken("ScrimTransparency", value / 100)
		end,
	})
	editor:AddButton({
		Title = "@settings.theme.reset",
		Icon = "rotate-ccw",
		Text = "@settings.reset",
		Callback = function()
			w.Theme:ResetOverrides()
			w:SetAccent(nil)
			w.Notify:Push({ Title = w.Locale:T("settings.resetDone"), Variant = "Success" })
		end,
	})
	editor:AddButton({
		Title = "@settings.theme.export",
		Icon = "upload",
		Text = "@settings.export",
		Callback = function()
			w:ExportTheme(true)
			w.Notify:Push({ Title = w.Locale:T("settings.copied"), Variant = "Success" })
		end,
	})
	editor:AddButton({
		Title = "@settings.theme.import",
		Icon = "download",
		Text = "@settings.import",
		Callback = function()
			task.spawn(function()
				local raw =
					w.Dialog:Prompt({ Title = w.Locale:T("settings.theme.import"), Placeholder = "{...}" }):Await()
				if raw then
					local ok, err = w:ImportTheme(raw)
					if not ok then
						w.Notify:Push({ Title = tostring(err), Variant = "Error" })
					end
				end
			end)
		end,
	})
	editor:AddButton({
		Title = "Save custom theme",
		Icon = "save",
		Text = "Save as…",
		Callback = function()
			task.spawn(function()
				local name = w.Dialog
					:Prompt({
						Title = "Save custom theme",
						Content = "Use letters, numbers, dots, dashes or underscores.",
						Placeholder = "MyTheme",
					})
					:Await()
				if name and name ~= "" then
					local ok, err = w:SaveCustomTheme(name)
					w.Notify:Push({
						Title = if ok then `Saved theme {name}` else "Theme was not saved",
						Content = if ok then "It is now available in the theme list." else tostring(err),
						Variant = if ok then "Success" else "Error",
					})
				end
			end)
		end,
	})
	editor:AddButton({
		Title = "Use current theme by default",
		Icon = "pin",
		Text = "Set default",
		Callback = function()
			local ok, err = w:SetDefaultTheme(w.Theme:Current())
			w.Notify:Push({
				Title = if ok then "Default theme updated" else "Default was not changed",
				Content = if ok then w.Theme:Current() else tostring(err),
				Variant = if ok then "Success" else "Error",
			})
		end,
	})
	editor:AddButton({
		Title = "Delete current custom theme",
		Icon = "trash-2",
		Text = "Delete",
		Variant = "Danger",
		Confirm = "Delete the selected custom theme? Built-in Dark and Light cannot be deleted.",
		Callback = function()
			local name = w.Theme:Current()
			local ok, err = w:DeleteCustomTheme(name)
			w.Notify:Push({
				Title = if ok then `Deleted theme {name}` else "Theme was not deleted",
				Content = if ok then "Dark is active now." else tostring(err),
				Variant = if ok then "Success" else "Error",
			})
		end,
	})

	local windowSec = tab:AddSection({
		Id = "__settings.window",
		Title = "@settings.window",
		Icon = "app-window",
		Span = "Auto",
	})
	windowSec:AddToggle({
		Id = "__settings.lock",
		Title = "@settings.lockWindow",
		Icon = "lock",
		Default = w:IsLocked(),
		IgnoreConfig = true,
		Callback = function(v)
			w:SetLocked(v)
		end,
	})
	windowSec:AddToggle({
		Id = "__settings.remember",
		Title = "@settings.rememberGeometry",
		Icon = "save",
		Default = w:GetRememberGeometry(),
		IgnoreConfig = true,
		Callback = function(v)
			w:SetRememberGeometry(v)
		end,
	})
	windowSec:AddToggle({
		Id = "__settings.sidebar",
		Title = "Hide sidebar",
		Icon = "panel-left",
		Default = serviceValue(w, function(window)
			if window.IsSidebarHidden ~= nil then
				return window:IsSidebarHidden()
			end
			return nil
		end, false),
		IgnoreConfig = true,
		Callback = function(v)
			if w.SetSidebarHidden then
				w:SetSidebarHidden(v)
			end
		end,
	})
	self._opacityControl = windowSec:AddSlider({
		Id = "__settings.opacity",
		Title = "Window opacity",
		Icon = "blend",
		Min = 35,
		Max = 100,
		Step = 5,
		Default = serviceValue(w, function(window)
			if window.GetWindowOpacity ~= nil then
				local opacity = window:GetWindowOpacity()
				if opacity ~= nil then
					return math.floor(opacity * 100 + 0.5)
				end
			end
			return nil
		end, 100),
		Suffix = "%",
		IgnoreConfig = true,
		Callback = function(v)
			if w.SetWindowOpacity then
				w:SetWindowOpacity(v / 100)
			end
		end,
	})
	self._cursorControl = windowSec:AddToggle({
		Id = "__settings.cursor",
		Title = "Custom cursor",
		Icon = "mouse-pointer-2",
		Default = serviceValue(w.Cursor, function(cursor)
			return cursor:IsEnabled()
		end, false),
		IgnoreConfig = true,
		Callback = function(v)
			if w.SetCustomCursor then
				w:SetCustomCursor(v)
			end
		end,
	})
	windowSec:AddDropdown({
		Id = "__settings.notifyPosition",
		Title = "Notification position",
		Icon = "bell",
		Options = { "BottomRight", "BottomLeft", "TopRight", "TopLeft" },
		Default = serviceValue(w.Notify, function(notify)
			return notify:GetPosition()
		end, "BottomRight"),
		IgnoreConfig = true,
		Callback = function(v)
			if w.SetNotificationPosition then
				w:SetNotificationPosition(v)
			end
		end,
	})
	windowSec:AddButton({
		Title = "@settings.resetLayout",
		Icon = "rotate-ccw",
		Text = "@settings.reset",
		Callback = function()
			w:ResetGeometry()
		end,
	})
	windowSec:AddButton({
		Title = "@settings.resetAll",
		Icon = "trash-2",
		Text = "@settings.reset",
		Variant = "Danger",
		Confirm = "Reset every saved control to its default value?",
		Callback = function()
			w:ResetAll()
		end,
	})

	local config = tab:AddSection({
		Id = "__settings.configs",
		Title = "@settings.configs",
		Icon = "folder-cog",
		Collapsible = true,
		Collapsed = false,
		Span = "Auto",
	})
	self:_buildConfig(config)
	self._favoritesSection = tab:AddSection({
		Id = "__settings.favorites",
		Title = "@settings.favorites",
		Icon = "star",
		Collapsible = true,
		Collapsed = false,
		Span = "Auto",
	})
	self._keybindSection = tab:AddSection({
		Id = "__settings.keybinds",
		Title = "@settings.keybinds",
		Icon = "keyboard",
		Collapsible = true,
		Collapsed = false,
		Span = "Auto",
	})
	self:_refreshFavorites()
	self:_refreshKeybinds()
	self._favConn = w.Favorites.Changed:Connect(function()
		task.defer(function()
			self:_refreshFavorites()
		end)
	end)
	self._regAdd = w.Registry.Added:Connect(function(entry)
		if entry.Type == "Keybind" then
			task.defer(function()
				self:_refreshKeybinds()
			end)
		end
	end)
	self._regRemove = w.Registry.Removed:Connect(function(entry)
		if entry.Type == "Keybind" then
			task.defer(function()
				self:_refreshKeybinds()
			end)
		end
	end)
	if w.Config then
		self._savedConn = w.Config.Saved:Connect(function()
			self:_refreshProfiles()
		end)
	end
	self._themeConn = w.Theme.Changed:Connect(function()
		task.defer(function()
			self:_syncAppearance()
		end)
	end)
	self._tokensConn = w.Tokens.Changed:Connect(function()
		task.defer(function()
			self:_syncAppearance()
		end)
	end)
	self._localeConn = w.Locale.Changed:Connect(function()
		task.defer(function()
			self:_syncAppearance()
		end)
	end)
	self:_syncAppearance()
	return self
end
function Settings:RefreshThemeOptions()
	if self._themeControl and not self._themeControl._destroyed then
		self._themeControl:SetOptions(self._window.Theme:List(), true)
		self._themeControl:SetValue(self._window.Theme:Current(), true)
	end
	return self
end
function Settings:Open()
	self:_ensureMounted()
	if self.Tab then
		self.Tab:Select()
	end
	return self
end
function Settings:Destroy()
	for _, c in
		{
			self._favConn,
			self._regAdd,
			self._regRemove,
			self._savedConn,
			self._themeConn,
			self._tokensConn,
			self._localeConn,
		}
	do
		if c then
			c:Disconnect()
		end
	end
end
return Settings
