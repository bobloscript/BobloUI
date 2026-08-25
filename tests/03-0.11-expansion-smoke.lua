-- BobloUI 0.11 expansion smoke. Run after publishing current dist/BobloUI.lua.
local SOURCE = "https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.lua"
local BobloUI = loadstring(game:HttpGet(SOURCE))()
local function check(v, m)
	assert(v, "[BobloUI 0.11 smoke] " .. m)
end
check(BobloUI.Version == "0.11.5-beta.1", "unexpected version " .. tostring(BobloUI.Version))
check(BobloUI.ApiLevel >= 11, "ApiLevel < 11")
check(type(BobloUI.Source) == "function" and type(BobloUI.Sources.Players) == "function", "data sources missing")

local UI = BobloUI:CreateWindow({
	Id = "bobloui-011-smoke",
	Title = "BobloUI 0.11",
	Subtitle = "Expansion smoke",
	Theme = "Dark",
	NotificationPosition = "TopRight",
	ShowText = "Show BobloUI",
	TabTransition = { Style = "Slide", Direction = "Right", Duration = 0.08 },
	WindowAnimation = { Style = "SlideDown", Duration = 0.08, Offset = 6 },
})
check(type(UI.AddTopbarButton) == "function" and type(UI.AddTopbarTag) == "function", "topbar API missing")
check(
	type(UI.ShowLoading) == "function" and type(UI.SetWatermark) == "function" and type(UI.SetKeybindHUD) == "function",
	"service API missing"
)

local tag = UI:AddTopbarTag({ Text = "BETA" })
local topClicks = 0
local top = UI:AddTopbarButton({
	Icon = "star",
	Callback = function()
		topClicks += 1
	end,
})
check(tag and top, "topbar creation failed")

UI:SetWindowOpacity(0.92)
check(math.abs(UI:GetWindowOpacity() - 0.92) < 0.001, "window opacity failed")
UI:SetTabTransition({ Style = "Slide", Direction = "Down", Duration = 0.05, Offset = 6 })
UI:SetWindowAnimation({ Style = "SlideDown", Duration = 0.05, Offset = 6 })
UI:SetNotificationPosition("BottomLeft")
UI:SetRestoreButton({ Mode = "Mobile", Text = "Show BobloUI" })
UI:SetWatermark(function()
	return "BobloUI 0.11"
end)
UI:SetWatermark(false)
UI:SetKeybindHUD(true)
UI:SetKeybindHUD(false)
UI:SetCustomCursor(true, { Size = 8 })
UI:SetCustomCursor(false)

local Main = UI:AddTab({ Id = "main", Title = "Main", Icon = "dashboard", Group = "MAIN" })
local Locked = UI:AddTab({ Id = "locked", Title = "Locked", Icon = "lock", Locked = true, LockedReason = "Smoke lock" })
check(Locked:IsLocked(), "locked tab state missing")
Locked:SetLocked(false)
check(not Locked:IsLocked(), "unlock failed")

local Rich = Main:AddSection({ Title = "Rich controls", Span = 1 })
local progress =
	Rich:AddProgress({ Id = "Progress", Title = "Progress", Icon = "progress", Min = 0, Max = 100, Default = 35 })
check(progress:GetValue() == 35, "progress default")
progress:SetValue(70)
check(progress:GetValue() == 70, "progress set")
progress:SetIndeterminate(true)
progress:SetIndeterminate(false)

local input =
	Rich:AddInput({ Id = "Notes", Title = "Notes", Icon = "code", Multiline = true, Height = 100, Default = "hello" })
check(input:GetValue() == "hello", "textarea default")
Rich:AddCode({ Title = "Loader", Icon = "code", Code = "print('BobloUI')", Height = 90, Copy = true })
Rich:AddImage({ Title = "Preview", Icon = "image", Image = "rbxassetid://0", Height = 80, Caption = "Media block" })

local dd = Rich:AddDropdown({
	Id = "AdvancedDD",
	Title = "Advanced dropdown",
	Searchable = true,
	Options = {
		{ Value = "safe", Title = "Safe", Description = "Normal mode", Icon = "check" },
		{ Value = "fast", Title = "Fast", Description = "Faster behavior", Icon = "star" },
		{
			Value = "locked",
			Title = "Locked",
			Description = "Not available",
			Icon = "lock",
			Locked = true,
			LockedReason = "Unlock later",
		},
	},
	Default = "safe",
})
check(dd:GetValue() == "safe", "advanced dropdown default")

local PlayerDD = Rich:AddDropdown({
	Id = "PlayerSource",
	Title = "Player source",
	Source = BobloUI.Sources.Players({ IncludeLocalPlayer = true }),
	AllowNone = true,
	IgnoreConfig = true,
})
PlayerDD:RefreshSource(true)

local Layout = Main:AddSection({ Title = "Layout primitives", Span = 1 })
local row = Layout:AddRow({ Columns = 2 })
row:AddButton({ Title = "Left", Text = "Left", Callback = function() end })
row:AddToggle({ Id = "RowToggle", Title = "Right", Style = "Checkbox", Default = true })
check(UI.State:Get("RowToggle") == true, "row child state failed")

local tabs = Layout:AddTabBox({ Title = "Modes" })
local A = tabs:AddTab({ Id = "a", Title = "A" })
A:AddToggle({ Id = "TabBoxA", Title = "A toggle", Default = true })
local B = tabs:AddTab({ Id = "b", Title = "B" })
B:AddSlider({
	Id = "TabBoxSlider",
	Title = "B slider",
	Min = 0,
	Max = 10,
	Default = 5,
	FloatingValue = true,
	ValueInput = true,
	IconFrom = "minus",
	IconTo = "plus",
})
tabs:Select("b")
check(UI.State:Get("TabBoxSlider") == 5, "TabBox child state failed")

local key = Layout:AddKeybind({
	Id = "HUDKey",
	Title = "HUD key",
	Default = Enum.KeyCode.F,
	Mode = "Toggle",
	Callback = function() end,
})
check(key ~= nil, "keybind creation failed")

local loading = UI:ShowLoading({ Title = "Boot", Status = "Step one", Progress = 0.1 })
check(loading and loading.SetStep, "loading handle missing")
loading:SetStep(2, 3, "Almost ready"):SetProgress(0.8)
loading:Dismiss()

local n = UI.Notify:Push({ Title = "0.11", Content = "Expansion smoke", Progress = 0.2, Duration = 0 })
n:SetProgress(1)
n:Dismiss()

UI:SetBackgroundImage("rbxassetid://0", 0.2, 0.9)
UI:SetBackgroundImage(nil)

tag:Destroy()
top:Destroy()
print("BobloUI 0.11 expansion smoke: PASS")
