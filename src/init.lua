--!nonstrict
-- BobloUI public entry. All higher-level services are wired here by injection.
local Env = require("@runtime/Env")
local Janitor = require("@runtime/Janitor")
local Util = require("@runtime/Util")
local Tokens = require("@kernel/Tokens")
local Theme = require("@kernel/Theme")
local Device = require("@kernel/Device")
local Layer = require("@kernel/Layer")
local Store = require("@kernel/Store")
local Registry = require("@kernel/Registry")
local Input = require("@kernel/Input")
local Motion = require("@kernel/Motion")
local Locale = require("@kernel/Locale")
local Window = require("@shell/Window")
local Favorites = require("@services/Favorites")
local Config = require("@services/Config")
local Search = require("@services/Search")
local Commands = require("@services/Commands")
local Notify = require("@services/Notify")
local Dialog = require("@services/Dialog")
local Palette = require("@services/Palette")
local Interactions = require("@services/Interactions")
local Build = require("@schema/Build")
local Icon = require("@primitives/Icon")
local Dark = require("@themes/Dark")
local Light = require("@themes/Light")
local Settings = require("@services/Settings")
local Sound = require("@services/Sound")
local Navigation = require("@services/Navigation")
local Loading = require("@services/Loading")
local HUD = require("@services/HUD")
local Cursor = require("@services/Cursor")
local Overlays = require("@services/Overlays")
local ThemeManager = require("@services/ThemeManager")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local BobloUI = {}
BobloUI.Version = "0.11.5-beta.1"
BobloUI.ApiLevel = 11
BobloUI.Env = Env
BobloUI.Icon = Icon
BobloUI.Sources = {}
function BobloUI.Source(getter, signals)
	if type(getter) ~= "function" then
		error("[BobloUI] Source requires a getter function.", 2)
	end
	return { Get = getter, Signals = signals or {} }
end
function BobloUI.Sources.Players(options)
	options = options or {}
	return {
		Get = function()
			local out = {}
			for _, player in Players:GetPlayers() do
				if options.IncludeLocalPlayer ~= false or player ~= Players.LocalPlayer then
					table.insert(out, {
						Value = if options.ReturnPlayer then player else player.Name,
						Title = options.UseUsername and player.Name or player.DisplayName,
						Description = if player.DisplayName ~= player.Name then "@" .. player.Name else nil,
						Icon = options.Icon,
					})
				end
			end
			table.sort(out, function(a, b)
				return string.lower(a.Title) < string.lower(b.Title)
			end)
			return out
		end,
		Signals = { Players.PlayerAdded, Players.PlayerRemoving },
	}
end

local REGISTRY_KEY = "__BobloUI"
local function globalRegistry()
	local existing = Env.Globals[REGISTRY_KEY]
	if type(existing) == "table" and type(existing.Instances) == "table" then
		return existing
	end
	local created = { Instances = {} }
	Env.Globals[REGISTRY_KEY] = created
	return created
end
local function evict(id)
	local r = globalRegistry()
	local previous = r.Instances[id]
	if not previous then
		return
	end
	r.Instances[id] = nil
	local ok, err = pcall(function()
		previous:Unload()
	end)
	if not ok then
		warn(`[BobloUI] previous window "{id}" failed to unload ({err}); sweeping GUIs.`)
		Layer.SweepOrphans(id)
	end
end
local WINDOW_OPTIONS = {
	"Id",
	"Singleton",
	"Title",
	"Subtitle",
	"Icon",
	"Theme",
	"Accent",
	"Density",
	"Scale",
	"Size",
	"Presentation",
	"MinSize",
	"Locale",
	"ToggleKey",
	"ToggleUIKeybind",
	"ShowText",
	"ConfigFolder",
	"ThemeFolder",
	"AutoLoadTheme",
	"AutoLoad",
	"ReducedMotion",
	"HighContrast",
	"Settings",
	"RememberGeometry",
	"KeyboardNavigation",
	"SoundEnabled",
	"SoundVolume",
	"Sounds",
	"OnUnload",
	"SidebarHidden",
	"SidebarWidth",
	"EnableSidebarResize",
	"Compact",
	"DisableSearch",
	"SearchbarSize",
	"GlobalSearch",
	"ShowMobileButtons",
	"MobileButtonsSide",
	"EnableCompacting",
	"DisableCompactingSnap",
	"SidebarCompacted",
	"MinContainerWidth",
	"MinSidebarWidth",
	"SidebarCompactWidth",
	"SidebarCollapseThreshold",
	"CompactWidthActivation",
	"TabSwipeOffset",
	"TabSwipeFrom",
	"Font",
	"Animations",
	"CornerRadius",
	"FooterHeight",
	"FooterText",
	"Opacity",
	"BackgroundImage",
	"BackgroundImageTransparency",
	"RestoreButton",
	"TabTransition",
	"WindowAnimation",
	"TabTransitionTime",
	"NotificationPosition",
	"Watermark",
	"KeybindHUD",
	"CustomCursor",
}
local function checkOptions(options)
	if type(options) ~= "table" then
		error("[BobloUI] CreateWindow expects an options table.", 3)
	end
	if type(options.Title) ~= "string" then
		error("[BobloUI] CreateWindow: Title is required and must be a string.", 3)
	end
	if options.Presentation ~= nil and options.Presentation ~= "Standard" and options.Presentation ~= "Minimal" then
		error("[BobloUI] Presentation must be 'Standard' or 'Minimal'.", 3)
	end
	for key in options do
		if not table.find(WINDOW_OPTIONS, key) then
			local suggestion = Util.suggest(tostring(key), WINDOW_OPTIONS)
			local hint = if suggestion then ' Did you mean "' .. suggestion .. '"?' else ""
			warn(
				`[BobloUI] CreateWindow: unknown option "{key}".{hint}\nValid options: {table.concat(
					WINDOW_OPTIONS,
					", "
				)}`
			)
		end
	end
end

local function normalizeBundledTheme(name, theme)
	if name ~= "Midnight" and name ~= "OLED" then
		return name
	end
	if theme and table.find(theme:List(), name) then
		return name
	end
	return "Dark"
end

function BobloUI:CreateWindow(options)
	checkOptions(options)
	local id = options.Id or Util.slug(options.Title)
	if not options.Id then
		warn(`[BobloUI] CreateWindow: no Id given, using "{id}" from Title. Set Id explicitly.`)
	end
	local singleton = options.Singleton ~= false
	if singleton then
		evict(id)
	end
	local janitor = Janitor.new(`Window[{id}]`)
	local device = Device.new()
	janitor:Add(device)
	local tokens = Tokens.new(
		options.Density
			or (options.Compact and "Compact")
			or (options.Presentation == "Minimal" and "Compact")
			or "Comfortable",
		device.Class,
		options.Presentation == "Minimal"
	)
	janitor:Add(tokens)
	local theme = Theme.new({
		Palettes = { Dark = Dark, Light = Light },
		Accent = options.Accent,
	})
	janitor:Add(theme)
	local requestedTheme = options.Theme
	local initialTheme = normalizeBundledTheme(requestedTheme or "Dark", theme)
	if not table.find({ "Dark", "Light" }, initialTheme) then
		initialTheme = "Dark"
	end
	theme:Set(initialTheme)
	if options.HighContrast then
		theme:SetHighContrast(true)
	end
	local input = Input.new()
	janitor:Add(input)
	local layers = Layer.new(id, input, theme)
	janitor:Add(layers)
	local state = Store.new()
	janitor:Add(state)
	local registry = Registry.new()
	janitor:Add(registry)
	local motion = Motion.new()
	janitor:Add(motion)
	if options.ReducedMotion then
		motion:SetEnabled(false)
	end
	local locale = Locale.new(options.Locale or "en")
	janitor:Add(locale)
	locale:Register("en", {
		["search.placeholder"] = "Search controls or type > for commands",
		["common.cancel"] = "Cancel",
		["common.confirm"] = "Confirm",
		["settings.title"] = "Settings",
		["settings.description"] = "Interface, profiles and accessibility",
		["nav.system"] = "System",
		["settings.appearance"] = "Appearance",
		["settings.appearanceDesc"] = "Theme, scale, density and language",
		["settings.theme"] = "Theme",
		["settings.accent"] = "Accent color",
		["settings.scale"] = "UI scale",
		["settings.density"] = "Density",
		["settings.language"] = "Language",
		["settings.reducedMotion"] = "Reduced motion",
		["settings.highContrast"] = "High contrast",
		["settings.keyboardNavigation"] = "Keyboard / gamepad navigation",
		["settings.uiSounds"] = "UI sounds",
		["settings.soundVolume"] = "UI sound volume",
		["settings.themeEditor"] = "Advanced theme editor",
		["settings.themeEditorDesc"] = "Override any core interface color",
		["settings.theme.reset"] = "Reset custom theme",
		["settings.theme.export"] = "Export theme",
		["settings.theme.import"] = "Import theme",
		["settings.window"] = "Window",
		["settings.lockWindow"] = "Lock window position",
		["settings.rememberGeometry"] = "Remember size and position",
		["settings.resetLayout"] = "Reset window layout",
		["settings.resetAll"] = "Reset all controls",
		["settings.configs"] = "Config profiles",
		["settings.config.name"] = "Profile name",
		["settings.config.profile"] = "Selected profile",
		["settings.config.save"] = "Save profile",
		["settings.config.load"] = "Load profile",
		["settings.config.autoload"] = "Auto-load profile",
		["settings.config.duplicate"] = "Duplicate profile",
		["settings.config.rename"] = "Rename profile",
		["settings.config.delete"] = "Delete profile",
		["settings.config.export"] = "Export profile",
		["settings.config.import"] = "Import profile",
		["settings.config.paste"] = "Paste exported JSON",
		["settings.config.disabled"] = "Set ConfigFolder in CreateWindow to enable persistent profiles.",
		["settings.favorites"] = "Favorites",
		["settings.favorites.empty"] = "No favorites yet. Right-click or long-press a control to pin it.",
		["settings.keybinds"] = "Keybind manager",
		["settings.keybinds.empty"] = "No keybind controls in this hub.",
		["settings.open"] = "Open",
		["settings.removeFavorite"] = "Remove from Favorites",
		["settings.save"] = "Save",
		["settings.load"] = "Load",
		["settings.set"] = "Set",
		["settings.duplicate"] = "Duplicate",
		["settings.rename"] = "Rename",
		["settings.delete"] = "Delete",
		["settings.export"] = "Export",
		["settings.import"] = "Import",
		["settings.reset"] = "Reset",
		["settings.saved"] = "Profile saved",
		["settings.autoloadSet"] = "Auto-load updated",
		["settings.copied"] = "Copied to clipboard",
		["settings.resetDone"] = "Theme reset",
	})
	locale:Register("ru", {
		["search.placeholder"] = "Поиск функций или > для команд",
		["common.cancel"] = "Отмена",
		["common.confirm"] = "Подтвердить",
		["settings.title"] = "Настройки",
		["settings.description"] = "Интерфейс, профили и доступность",
		["nav.system"] = "Система",
		["settings.appearance"] = "Внешний вид",
		["settings.appearanceDesc"] = "Тема, масштаб, плотность и язык",
		["settings.theme"] = "Тема",
		["settings.accent"] = "Цвет акцента",
		["settings.scale"] = "Масштаб UI",
		["settings.density"] = "Плотность",
		["settings.language"] = "Язык",
		["settings.reducedMotion"] = "Меньше анимаций",
		["settings.highContrast"] = "Высокий контраст",
		["settings.keyboardNavigation"] = "Навигация клавиатурой / геймпадом",
		["settings.uiSounds"] = "Звуки интерфейса",
		["settings.soundVolume"] = "Громкость интерфейса",
		["settings.themeEditor"] = "Редактор темы",
		["settings.themeEditorDesc"] = "Изменение основных цветов интерфейса",
		["settings.window"] = "Окно",
		["settings.lockWindow"] = "Заблокировать окно",
		["settings.rememberGeometry"] = "Запоминать размер и позицию",
		["settings.resetLayout"] = "Сбросить расположение",
		["settings.resetAll"] = "Сбросить все функции",
		["settings.configs"] = "Профили",
		["settings.config.name"] = "Имя профиля",
		["settings.config.profile"] = "Выбранный профиль",
		["settings.config.disabled"] = "Укажите ConfigFolder, чтобы включить сохранение профилей.",
		["settings.favorites"] = "Избранное",
		["settings.favorites.empty"] = "Избранного пока нет.",
		["settings.keybinds"] = "Горячие клавиши",
		["settings.keybinds.empty"] = "В хабе нет горячих клавиш.",
		["settings.open"] = "Открыть",
		["settings.save"] = "Сохранить",
		["settings.load"] = "Загрузить",
		["settings.set"] = "Назначить",
		["settings.duplicate"] = "Копировать",
		["settings.rename"] = "Переименовать",
		["settings.delete"] = "Удалить",
		["settings.export"] = "Экспорт",
		["settings.import"] = "Импорт",
		["settings.reset"] = "Сбросить",
		["settings.copied"] = "Скопировано",
		["settings.saved"] = "Профиль сохранён",
	})
	locale:Register("es", {
		["search.placeholder"] = "Buscar controles o usar > para comandos",
		["common.cancel"] = "Cancelar",
		["common.confirm"] = "Confirmar",
		["settings.title"] = "Ajustes",
		["settings.description"] = "Interfaz, perfiles y accesibilidad",
		["nav.system"] = "Sistema",
		["settings.appearance"] = "Apariencia",
		["settings.theme"] = "Tema",
		["settings.accent"] = "Color de acento",
		["settings.scale"] = "Escala de UI",
		["settings.density"] = "Densidad",
		["settings.language"] = "Idioma",
		["settings.reducedMotion"] = "Movimiento reducido",
		["settings.highContrast"] = "Alto contraste",
		["settings.keyboardNavigation"] = "Navegación con teclado / mando",
		["settings.uiSounds"] = "Sonidos de interfaz",
		["settings.soundVolume"] = "Volumen de interfaz",
		["settings.window"] = "Ventana",
		["settings.configs"] = "Perfiles",
		["settings.favorites"] = "Favoritos",
		["settings.keybinds"] = "Atajos",
		["settings.open"] = "Abrir",
		["settings.save"] = "Guardar",
		["settings.load"] = "Cargar",
		["settings.reset"] = "Restablecer",
	})

	local window = Window.new({
		Id = id,
		Janitor = janitor,
		Theme = theme,
		Tokens = tokens,
		Device = device,
		Layers = layers,
		Fonts = Tokens.Fonts,
		State = state,
		Registry = registry,
		Input = input,
		Motion = motion,
		Locale = locale,
	}, options)
	window.Version = BobloUI.Version
	window.ApiLevel = BobloUI.ApiLevel
	window.Singleton = singleton
	window.CustomControls = BobloUI.CustomControls
	window.State = state
	window.Registry = registry
	window.Input = input
	window.Motion = motion
	window.Locale = locale
	if options.Font then
		window:SetFont(options.Font)
	end
	if options.Animations then
		window:SetAnimations(options.Animations)
	end

	local favorites = Favorites.new(registry)
	janitor:Add(favorites)
	window.Favorites = favorites
	local search = Search.new(window)
	janitor:Add(search)
	window.Search = search
	local commands = Commands.new(window)
	janitor:Add(commands)
	window.Commands = commands
	local notify = Notify.new(window, options.NotificationPosition)
	janitor:Add(notify)
	window.Notify = notify
	local dialog = Dialog.new(window)
	janitor:Add(dialog)
	window.Dialog = dialog
	local config = nil
	if options.ConfigFolder then
		config = Config.new(window, options.ConfigFolder)
		janitor:Add(config)
		window.Config = config
	end
	local interactions = Interactions.new(window)
	janitor:Add(interactions)
	window.Interactions = interactions
	local palette = Palette.new(window, search, commands)
	janitor:Add(palette)
	window.Palette = palette
	local sound = Sound.new(window, options)
	janitor:Add(sound)
	window.Sound = sound
	local navigation = Navigation.new(window, options.KeyboardNavigation ~= false)
	janitor:Add(navigation)
	window.Navigation = navigation
	local loading = Loading.new(window)
	janitor:Add(loading)
	window.Loading = loading
	local hud = HUD.new(window)
	janitor:Add(hud)
	window.HUD = hud
	local cursor = Cursor.new(window)
	janitor:Add(cursor)
	window.Cursor = cursor
	local overlays = Overlays.new(window)
	janitor:Add(overlays)
	window.Overlays = overlays
	local themeManager = ThemeManager.new(window, options.ThemeFolder or options.ConfigFolder or id)
	janitor:Add(themeManager)
	window.ThemeManager = themeManager
	if
		requestedTheme
		and requestedTheme ~= "Dark"
		and requestedTheme ~= "Light"
		and requestedTheme ~= "Midnight"
		and requestedTheme ~= "OLED"
	then
		local loaded, loadError = themeManager:Load(requestedTheme)
		if not loaded then
			warn(`[BobloUI] custom theme "{requestedTheme}" could not be loaded: {loadError}`)
		end
	elseif requestedTheme == nil and options.AutoLoadTheme ~= false and themeManager:GetDefault() then
		themeManager:LoadDefault()
	end
	local settings = nil
	if options.Settings ~= false then
		settings = Settings.new(window, options)
		janitor:Add(settings)
		window.Settings = settings
	end
	function window:OpenSettings()
		if settings then
			settings:Open()
		end
		return self
	end

	local unloaded = false
	function window:SetTheme(name)
		theme:Set(normalizeBundledTheme(name, theme))
		return self
	end
	function window:SetAccent(colour)
		theme:SetAccent(colour)
		return self
	end
	function window:SetThemeToken(token, value)
		theme:SetToken(token, value)
		return self
	end
	function window:SetHighContrast(enabled)
		theme:SetHighContrast(enabled)
		return self
	end
	function window:RegisterTheme(name, palette)
		theme:Register(name, palette)
		return self
	end
	function window:SaveCustomTheme(name, palette)
		return themeManager:SaveCustomTheme(name, palette)
	end
	function window:DeleteCustomTheme(name)
		return themeManager:DeleteCustomTheme(name)
	end
	function window:ReloadCustomThemes()
		return themeManager:ReloadCustomThemes()
	end
	function window:SetThemeFolder(folder)
		return themeManager:SetFolder(folder)
	end
	function window:ListCustomThemes()
		return themeManager:ListCustomThemes()
	end
	function window:LoadCustomTheme(name)
		return themeManager:Load(name)
	end
	function window:SetDefaultTheme(name)
		return themeManager:SetDefault(name)
	end
	function window:GetDefaultTheme()
		return themeManager:GetDefault()
	end
	function window:LoadDefaultTheme()
		return themeManager:LoadDefault()
	end
	function window:SetDensity(density)
		tokens:SetDensity(density)
		return self
	end
	function window:SetScale(scale)
		local root = self:GetInstance()
		local uiScale = root:FindFirstChildOfClass("UIScale")
		if not uiScale then
			uiScale = Instance.new("UIScale")
			uiScale.Parent = root
		end
		self._scale = math.clamp(scale, 0.5, 2)
		uiScale.Scale = self._scale
		if self._applyGeometry then
			self:_applyGeometry()
		end
		if self._scheduleSectionLayouts then
			self:_scheduleSectionLayouts()
		end
		return self
	end
	function window:GetScale()
		return self._scale or 1
	end
	function window:ExportTheme(copy)
		local raw = HttpService:JSONEncode(theme:Export())
		if copy then
			Env.SetClipboard(raw)
		end
		return raw
	end
	function window:ImportTheme(raw)
		local data = raw
		if type(raw) == "string" then
			local ok, res = pcall(HttpService.JSONDecode, HttpService, raw)
			if not ok then
				return false, res
			end
			data = res
		end
		if type(data) == "table" and data.Theme then
			data = table.clone(data)
			data.Theme = normalizeBundledTheme(data.Theme, theme)
		end
		return theme:Import(data)
	end
	function window:SetLocale(name)
		locale:Set(name)
		for _, tab in self._tabs do
			if tab._refreshLocale then
				tab:_refreshLocale()
			end
		end
		for _, entry in registry:Entries() do
			if entry.Handle and entry.Handle._refreshText then
				entry.Handle:_refreshText()
			end
		end
		if self._refreshFooterText then
			self:_refreshFooterText()
		end
		search:Reindex()
		return self
	end
	function window:SetReducedMotion(reduced)
		motion:SetEnabled(not reduced)
		return self
	end
	function window:SetKeyboardNavigation(enabled)
		navigation:SetEnabled(enabled)
		return self
	end
	function window:SetUISounds(enabled)
		sound:SetEnabled(enabled)
		return self
	end
	function window:SetSoundVolume(volume)
		sound:SetVolume(volume)
		return self
	end
	function window:RegisterSound(name, spec)
		sound:Register(name, spec)
		return self
	end
	function window:PlaySound(name, override)
		return sound:Play(name, override)
	end
	function window:ShowLoading(options)
		return loading:Show(options)
	end
	function window:HideLoading()
		loading:Hide()
		return self
	end
	function window:SetWatermark(spec)
		hud:SetWatermark(spec)
		return self
	end
	function window:SetKeybindHUD(enabled)
		hud:SetKeybindHUD(enabled)
		return self
	end
	function window:SetCustomCursor(enabled, options)
		cursor:SetEnabled(enabled, options)
		return self
	end
	function window:SetNotificationPosition(position)
		notify:SetPosition(position)
		return self
	end
	function window:AddDraggableLabel(...)
		return overlays:AddLabel(...)
	end
	function window:AddDraggableButton(...)
		return overlays:AddButton(...)
	end
	function window:AddDraggableMenu(...)
		return overlays:AddMenu(...)
	end
	function window:AddDialog(id, dialogOptions)
		if type(id) == "table" then
			dialogOptions = id
		else
			dialogOptions = table.clone(dialogOptions or {})
			dialogOptions.Id = id
		end
		return dialog:Custom(dialogOptions)
	end
	function window:OpenSearch(query)
		palette:Open(query or "", "search")
		return self
	end
	function window:OpenCommands()
		palette:Open("> ", "commands")
		return self
	end
	function window:Build(schema)
		return Build.Run(self, schema)
	end
	function window:OnUnload(fn)
		return self.Unloading:Connect(fn)
	end
	function window:IsUnloaded()
		return unloaded
	end

	commands:Register({
		Id = "ui.toggle",
		Title = "Toggle UI",
		Keywords = { "show", "hide" },
		Callback = function()
			window:Toggle()
		end,
	})
	commands:Register({
		Id = "ui.theme",
		Title = "Toggle light/dark theme",
		Keywords = { "theme", "dark", "light" },
		Callback = function()
			local target = theme:Counterpart()
			if target and target ~= theme:Current() then
				window:SetTheme(target)
			end
		end,
	})
	commands:Register({
		Id = "ui.settings",
		Title = "Open settings",
		Keywords = { "settings", "preferences", "config" },
		Callback = function()
			window:OpenSettings()
		end,
	})
	commands:Register({
		Id = "ui.reset",
		Title = "Reset UI layout",
		Keywords = { "reset", "layout", "window" },
		Callback = function()
			window:ResetGeometry()
		end,
	})
	commands:Register({
		Id = "ui.unload",
		Title = "Unload UI",
		Keywords = { "close", "destroy" },
		Callback = function()
			window:Unload()
		end,
	})

	local toggleKey = options.ToggleUIKeybind
	if toggleKey == nil then
		toggleKey = options.ToggleKey
	end
	if toggleKey == nil then
		toggleKey = Enum.KeyCode.RightShift
	end
	if type(toggleKey) == "string" then
		local wanted = string.lower(toggleKey)
		local resolved = nil
		for _, candidate in Enum.KeyCode:GetEnumItems() do
			if string.lower(candidate.Name) == wanted then
				resolved = candidate
				break
			end
		end
		if not resolved then
			error(`[BobloUI] ToggleUIKeybind/ToggleKey "{toggleKey}" is not a valid Enum.KeyCode.`, 2)
		end
		toggleKey = resolved
	end
	if toggleKey ~= false then
		if typeof(toggleKey) ~= "EnumItem" or toggleKey.EnumType ~= Enum.KeyCode then
			error("[BobloUI] ToggleUIKeybind/ToggleKey must be a string, Enum.KeyCode, or false.", 2)
		end
		janitor:Add(input:BindKey("__window_toggle", toggleKey, "Toggle", function()
			if not unloaded then
				window:Toggle()
			end
		end))
	end
	if options.Scale then
		window:SetScale(options.Scale)
	end
	if options.Watermark then
		window:SetWatermark(options.Watermark)
	end
	if options.KeybindHUD then
		window:SetKeybindHUD(true)
	end
	if options.CustomCursor then
		window:SetCustomCursor(true, type(options.CustomCursor) == "table" and options.CustomCursor or nil)
	end
	if options.OnUnload then
		window:OnUnload(options.OnUnload)
	end
	if singleton then
		globalRegistry().Instances[id] = window
	end

	local baseDestroy = Window.Destroy
	function window:Unload()
		if unloaded then
			return
		end
		unloaded = true
		self.Unloading:Fire()
		if config and config:GetAutoLoad() then
			pcall(function()
				config:Save(config:GetAutoLoad())
			end)
		end
		layers:DismissAll()
		baseDestroy(self)
		janitor:Destroy()
		local r = globalRegistry()
		if r.Instances[id] == self then
			r.Instances[id] = nil
		end
	end

	if config and options.AutoLoad then
		local ok, err = config:LoadAuto()
		if not ok and err ~= "no autoload" then
			warn(`[BobloUI] autoload failed: {err}`)
		end
	end
	return window
end
BobloUI.CustomControls = {}
function BobloUI:RegisterControl(name, factory)
	if type(name) ~= "string" or type(factory) ~= "function" then
		error("[BobloUI] RegisterControl(name,factory) expects string/function.", 2)
	end
	self.CustomControls[name] = factory
	return self
end

function BobloUI:GetWindow(id)
	return globalRegistry().Instances[id]
end
function BobloUI:ListWindows()
	local ids = Util.keys(globalRegistry().Instances)
	table.sort(ids)
	return ids
end
function BobloUI:SweepOrphans(id)
	return Layer.SweepOrphans(id)
end
return BobloUI
