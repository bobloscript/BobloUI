-- BobloUI all-features runtime smoke.
-- Run in an executor/Studio environment after publishing the current dist/BobloUI.lua.
-- Change SOURCE if you host the library elsewhere.
local SOURCE = "https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.lua"
local BobloUI = loadstring(game:HttpGet(SOURCE))()

local function check(condition, message)
	assert(condition, "[BobloUI all-features smoke] " .. message)
end

local function closeEnough(a, b, epsilon)
	return math.abs(a - b) <= (epsilon or 0.001)
end

local runId = tostring(os.time())

-- Public extension surfaces ---------------------------------------------------
BobloUI.Icon.Register("smoke-custom", function(window, root)
	local dot = Instance.new("Frame")
	dot.Name = "SmokeDot"
	dot.Size = UDim2.fromOffset(8, 8)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.BorderSizePixel = 0
	dot.BackgroundColor3 = window.Theme:Get("Accent")
	dot.Parent = root
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
end)

BobloUI:RegisterControl("SmokeAction", function(section, options)
	return section:AddButton({
		Title = options.Title or "Custom action",
		Text = options.Text or "Run",
		Callback = options.Callback,
	})
end)

local UI = BobloUI:CreateWindow({
	Id = "bobloui-all-features-smoke",
	Title = "BobloUI All Features",
	Subtitle = "0.11 runtime validation",
	Theme = "Dark",
	Density = "Comfortable",
	Scale = 1,
	ConfigFolder = "BobloUI_AllFeaturesSmoke",
	AutoLoad = false,
	Settings = true,
	KeyboardNavigation = true,
	SoundEnabled = false,
})

check(BobloUI.Version == "0.11.5-beta.1", "unexpected runtime version: " .. tostring(BobloUI.Version))
check(BobloUI.ApiLevel >= 11, "ApiLevel should be >= 11")
check(BobloUI:GetWindow("bobloui-all-features-smoke") == UI, "window registry lookup failed")

-- Tabs, groups, spans, adaptive controls ------------------------------------
local Dashboard =
	UI:AddTab({ Id = "dashboard", Title = "Dashboard", Icon = "dashboard", Group = "MAIN", Badge = "TEST" })
local Player = UI:AddTab({ Id = "player", Title = "Player", Icon = "user", Group = "PLAYER" })
local Visuals = UI:AddTab({ Id = "visuals", Title = "Visuals", Icon = "eye", Group = "PLAYER" })

local Automation = Dashboard:AddSection({
	Id = "automation",
	Title = "Automation",
	Description = "Responsive controls",
	Span = 1,
	Layout = "Stack",
	Collapsible = true,
})
local Secondary = Dashboard:AddSection({
	Id = "secondary",
	Title = "Secondary",
	Span = "Auto",
	Layout = "Auto",
})
local FullWidth = Player:AddSection({
	Id = "fullwidth",
	Title = "Full width",
	Span = 2,
	Layout = "Grid",
})

check(Automation.Span == 1 and Automation.Layout == "Stack", "section constructor span/layout failed")
Automation:SetSpan(2):SetLayout("Auto")
check(Automation.Span == 2 and Automation.Layout == "Auto", "Section:SetSpan/SetLayout failed")
Automation:SetSpan(1):SetLayout("Stack")

local Enabled =
	Automation:AddToggle({ Id = "Enabled", Title = "Auto Farm", Description = "Dependency master", Default = false })
local Range = Automation:AddSlider({
	Id = "Range",
	Title = "Farm Distance",
	Min = 10,
	Max = 250,
	Step = 5,
	Default = 75,
	Suffix = " studs",
	VisibleWhen = { Enabled = true },
})
local Priority = Automation:AddDropdown({
	Id = "Priority",
	Title = "Target Priority",
	Options = { "Nearest", "Highest HP", "Lowest HP" },
	Default = "Nearest",
})
local Segmented = Secondary:AddDropdown({
	Id = "Mode",
	Title = "Mode",
	Options = { "Safe", "Fast", "Manual" },
	Default = "Safe",
	Style = "Segmented",
})
local Name =
	Secondary:AddInput({ Id = "ProfileName", Title = "Profile name", Default = "Farming", Placeholder = "Name" })
local Bind =
	Secondary:AddKeybind({ Id = "FarmBind", Title = "Farm keybind", Default = Enum.KeyCode.F, Mode = "Toggle" })
local Tint = FullWidth:AddColorPicker({
	Id = "EspTint",
	Title = "ESP Color",
	Default = Color3.fromHex("8172F2"),
	Alpha = true,
	DefaultAlpha = 0.8,
})
local Tracers = FullWidth:AddToggle({ Id = "Tracers", Title = "Tracers", Default = true })
local Status = FullWidth:AddStatus({ Id = "ServerStatus", Title = "Server", Value = "Connected", Status = "Success" })
FullWidth:AddParagraph({ Title = "Info", Content = "Paragraph presentation control", Variant = "Info" })
FullWidth:AddDivider({ Title = "Actions" })
local CustomRan = false
FullWidth:AddCustom("SmokeAction", {
	Title = "Custom control",
	Callback = function()
		CustomRan = true
	end,
}):Click()
check(CustomRan, "custom-control factory/callback failed")

-- State, dependencies, reset/copy surface -----------------------------------
check(UI.State:Get("Range") == 75, "state default not registered")
check(Range:IsVisible() == false, "VisibleWhen initial dependency failed")
Enabled:SetValue(true)
check(Range:IsVisible() == true, "VisibleWhen reactive dependency failed")

local watchValue = nil
local stopWatch = UI.State:Watch("Range", function(value)
	watchValue = value
end)
UI.State:Set("Range", 95)
check(Range:GetValue() == 95 and watchValue == 95, "synchronous Store watcher/control binding failed")
stopWatch()

UI.State:Batch(function()
	UI.State:Set("Range", 135)
	UI.State:Set("Priority", "Highest HP")
end)
check(Range:GetValue() == 135 and Priority:GetValue() == "Highest HP", "State:Batch failed")
Range:Reset(true)
check(Range:GetValue() == 75, "control Reset() failed")
local copiedRange = Range:CopyValue()
check(type(copiedRange) == "string" and string.find(copiedRange, "75", 1, true) ~= nil, "CopyValue failed")

-- Favorites and search -------------------------------------------------------
UI.Favorites:Add("Range")
check(UI.Favorites:Has("Range"), "Favorites:Add/Has failed")
check(table.find(UI.Favorites:List(), "Range") ~= nil, "Favorites:List failed")
local search = UI.Search:Query("farm distance")
check(#search > 0 and search[1].Handle ~= nil, "Search query returned no control")
UI.Favorites:Remove("Range")
check(not UI.Favorites:Has("Range"), "Favorites:Remove failed")

-- Window geometry, density, scale, accessibility ----------------------------
UI:SetScale(1.15)
check(closeEnough(UI:GetScale(), 1.15), "SetScale/GetScale failed")
UI:SetDensity("Compact")
check(UI.Tokens:GetDensity() == "Compact", "density switch failed")
UI:SetDensity("Comfortable")
UI:SetLocked(true)
check(UI:IsLocked(), "window lock failed")
UI:SetLocked(false)
UI:SetRememberGeometry(true)
check(UI:GetRememberGeometry(), "remember geometry flag failed")
local beforeGeometry = UI:GetGeometry()
check(
	typeof(beforeGeometry.Size) == "UDim2" and typeof(beforeGeometry.Position) == "UDim2",
	"GetGeometry shape invalid"
)
UI:Minimize()
check(not UI:IsVisible(), "Minimize failed")
UI:Restore()
check(UI:IsVisible(), "Restore failed")
UI:SetReducedMotion(true)
check(UI.Motion.Enabled == false, "reduced motion failed")
UI:SetReducedMotion(false)
check(UI.Motion.Enabled == true, "motion restore failed")
UI:SetKeyboardNavigation(false)
check(UI.Navigation:IsEnabled() == false, "keyboard navigation disable failed")
UI:SetKeyboardNavigation(true)
check(UI.Navigation:IsEnabled() == true, "keyboard navigation enable failed")

-- Theme presets, arbitrary colors, token editor, import/export --------------
local bundledThemes = UI.Theme:List()
check(
	#bundledThemes == 2 and table.find(bundledThemes, "Dark") and table.find(bundledThemes, "Light"),
	"bundled theme list failed"
)
UI:SetTheme("Dark")
check(UI.Theme:Current() == "Dark", "Dark theme preset failed")
UI:SetTheme("Light")
check(UI.Theme:Current() == "Light", "Light theme preset failed")
UI:SetAccent(Color3.fromHex("FF5EA8"))
check(UI.Theme:Get("Accent"):ToHex():lower() == "ff5ea8", "arbitrary accent failed")
UI:SetThemeToken("Surface", Color3.fromHex("15111A"))
check(UI.Theme:Get("Surface"):ToHex():lower() == "15111a", "theme token override failed")
UI:SetHighContrast(true)
check(UI.Theme:IsHighContrast(), "high contrast enable failed")
local exportedTheme = UI:ExportTheme(false)
check(type(exportedTheme) == "string" and string.find(exportedTheme, "Light", 1, true) ~= nil, "theme export failed")
UI:SetTheme("Dark")
local importOk, importErr = UI:ImportTheme(exportedTheme)
check(importOk == true, "theme import failed: " .. tostring(importErr))
check(UI.Theme:Current() == "Light", "theme import did not restore preset")
UI:SetHighContrast(false)

-- Locale packs + user locale -------------------------------------------------
UI:SetLocale("ru")
check(UI.Locale:Get() == "ru", "Russian locale switch failed")
UI:SetLocale("es")
check(UI.Locale:Get() == "es", "Spanish locale switch failed")
UI.Locale:Register("smoke", { ["smoke.hello"] = "Hello smoke" })
UI:SetLocale("smoke")
check(UI.Locale:T("smoke.hello") == "Hello smoke", "custom locale failed")
UI:SetLocale("en")

-- Config profiles + persisted UI preferences --------------------------------
local baseConfig = "Smoke_" .. runId
local dupConfig = baseConfig .. "_Copy"
local renamedConfig = baseConfig .. "_Renamed"
local importedConfig = baseConfig .. "_Imported"
Enabled:SetValue(true)
Range:SetValue(145)
UI.Favorites:Add("Range")
Automation:SetCollapsed(true)
UI:SetScale(1.1)
UI:SetDensity("Compact")
UI:SetTheme("Dark")
UI:SetUISounds(false)
UI:SetSoundVolume(0.3)
local saveOk, saveErr = UI.Config:Save(baseConfig)
check(saveOk, "Config:Save failed: " .. tostring(saveErr))
check(UI.Config:Duplicate(baseConfig, dupConfig), "Config:Duplicate failed")
local renameOk, renameErr = UI.Config:Rename(dupConfig, renamedConfig)
check(renameOk, "Config:Rename failed: " .. tostring(renameErr))
local rawConfig = UI.Config:Export(baseConfig)
check(type(rawConfig) == "string" and #rawConfig > 20, "Config:Export failed")
local impOk, impErr = UI.Config:Import(rawConfig, importedConfig)
check(impOk, "Config:Import failed: " .. tostring(impErr))
UI.Config:SetAutoLoad(baseConfig)
check(UI.Config:GetAutoLoad() == baseConfig, "Config autoload setter failed")

-- Mutate and restore both values and UI meta.
Range:SetValue(10)
UI.Favorites:Remove("Range")
Automation:SetCollapsed(false)
UI:SetScale(0.85)
UI:SetDensity("Comfortable")
local loadOk, loadErr = UI.Config:Load(baseConfig)
check(loadOk, "Config:Load failed: " .. tostring(loadErr))
check(Range:GetValue() == 145, "config did not restore control state")
check(UI.Favorites:Has("Range"), "config did not restore favorites")
check(Automation.Collapsed == true, "config did not restore collapsed section")
check(closeEnough(UI:GetScale(), 1.1), "config did not restore scale")
check(UI.Tokens:GetDensity() == "Compact", "config did not restore density")

-- Settings center, config/favorites/keybind manager --------------------------
UI:OpenSettings()
task.wait()
local settingsTab = UI:GetTab("__bobloui_settings")
check(settingsTab ~= nil and settingsTab:IsSelected(), "built-in Settings center failed to mount/select")
check(UI:Get("__settings.theme") ~= nil, "Settings appearance controls missing")
check(UI:Get("__settings.configName") ~= nil, "Settings config profile UI missing")

-- Commands / palette APIs ----------------------------------------------------
local commandRan = false
UI.Commands:Register({
	Id = "smoke.command",
	Title = "Smoke Command",
	Keywords = { "smoke", "test" },
	Callback = function()
		commandRan = true
	end,
})
UI.Commands:Run("smoke.command")
check(commandRan, "command registry/run failed")
UI:OpenSearch("range")
task.wait()
check(UI.Palette._handle ~= nil, "OpenSearch failed")
UI.Palette:Close()
UI:OpenCommands()
task.wait()
check(UI.Palette._handle ~= nil, "OpenCommands failed")
UI.Palette:Close()

-- Notification progress -----------------------------------------------------
local notice = UI.Notify:Push({
	Title = "Runtime smoke",
	Content = "Testing progress",
	Variant = "Loading",
	Progress = 0,
	Duration = 0,
})
notice:SetProgress(0.5):Update({ Content = "Halfway", Variant = "Success", Progress = 1 })
check(notice.Progress == 1 and notice.Variant == "Success", "notification progress/update failed")
notice:Dismiss()

-- Dialog handles without user input -----------------------------------------
local choiceResult = "unset"
local choice = UI.Dialog:Choice({
	Title = "Smoke choice",
	Content = "Programmatic resolve",
	Choices = {
		{ Text = "A", Value = "a", Primary = true },
		{ Text = "B", Value = "b" },
	},
})
choice.Resolved:Connect(function(value)
	choiceResult = value
end)
choice:Resolve("b")
check(choiceResult == "b" and not choice:IsOpen(), "Dialog:Choice resolve lifecycle failed")
choice:Destroy()

local confirm = UI.Dialog:Confirm({ Title = "Smoke confirm", Content = "Programmatic resolve" })
local confirmResult = nil
confirm.Resolved:Connect(function(value)
	confirmResult = value
end)
confirm:Resolve(true)
check(confirmResult == true, "Dialog:Confirm programmatic resolve failed")
confirm:Destroy()

-- Optional sound service: no audio is played in the smoke -------------------
UI:RegisterSound("SmokeClick", { Id = "1", Volume = 0.1 })
UI:SetSoundVolume(0.25)
check(closeEnough(UI.Sound:GetVolume(), 0.25), "sound volume failed")
UI:SetUISounds(false)
check(UI.Sound:IsEnabled() == false, "sound disable failed")
UI:SetUISounds(true)
check(UI.Sound:IsEnabled() == true, "sound enable failed")

-- Keyboard/gamepad navigation service ---------------------------------------
Dashboard:Select()
UI.Navigation:Move(1)
check(UI.Navigation:GetFocused() ~= nil, "Navigation:Move failed to focus a control")
UI.Navigation:Clear()
check(UI.Navigation:GetFocused() == nil, "Navigation:Clear failed")

-- Declarative layout + segmented + grouped tab ------------------------------
local handles = UI:Build({
	Tabs = {
		{
			Id = "decl",
			Title = "Declarative",
			Group = "TESTS",
			Description = "Schema smoke",
			Sections = {
				{
					Id = "declSection",
					Title = "Descriptor",
					Span = 2,
					Layout = "Auto",
					Controls = {
						{ Type = "Toggle", Id = "DeclToggle", Title = "Declarative toggle", Default = true },
						{
							Type = "Dropdown",
							Id = "DeclMode",
							Title = "Declarative mode",
							Options = { "A", "B", "C" },
							Default = "B",
							Style = "Segmented",
						},
					},
				},
			},
		},
	},
})
check(
	handles.DeclToggle ~= nil and UI:Get("DeclMode"):GetValue() == "B",
	"declarative grouped/span/layout build failed"
)

-- Reject the entire bad descriptor before creating a partial tab.
local badOk = pcall(function()
	UI:Build({
		Tabs = {
			{
				Id = "badSchema",
				Title = "Bad",
				Sections = {
					{ Title = "Bad", Span = 3, Controls = { { Type = "Slider", Title = "Oops", Min = 0 } } },
				},
			},
		},
	})
end)
check(not badOk and UI:GetTab("badSchema") == nil, "declarative prevalidation failed")

-- Section reset + tab group runtime -----------------------------------------
Dashboard:SetGroup("PRIMARY")
check(Dashboard.Group == "PRIMARY", "Tab:SetGroup failed")
Automation:SetCollapsed(false)
Range:SetValue(200)
Automation:Reset()
check(Range:GetValue() == 75 and Enabled:GetValue() == false, "Section:Reset failed")
Status:SetStatus("Warning")

-- Cleanup config artifacts created by this test ------------------------------
UI.Config:SetAutoLoad(nil)
for _, name in { baseConfig, renamedConfig, importedConfig } do
	pcall(function()
		UI.Config:Delete(name)
	end)
end

-- Window cleanup / instance registry ----------------------------------------
UI:Unload()
check(UI:IsUnloaded(), "Unload flag failed")
check(BobloUI:GetWindow("bobloui-all-features-smoke") == nil, "window registry cleanup failed")

print("BobloUI all-features smoke: PASS", BobloUI.Version)
