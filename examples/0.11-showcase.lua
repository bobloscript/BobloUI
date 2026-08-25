local BobloUI =
	loadstring(game:HttpGet("https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.lua"))()
local UI = BobloUI:CreateWindow({
	Id = "bobloui-011-showcase",
	Title = "BobloUI",
	Subtitle = "0.11 showcase",
	Theme = "Dark",
	NotificationPosition = "TopRight",
	ShowText = "Show BobloUI",
})
UI:AddTopbarTag({ Text = "0.11" })
UI:AddTopbarButton({
	Icon = "star",
	Callback = function()
		UI.Notify:Push({ Title = "Topbar action", Variant = "Success" })
	end,
})

local Main = UI:AddTab({ Id = "main", Title = "Main", Icon = "dashboard", Group = "MAIN" })
local Rich = Main:AddSection({ Title = "Rich UI", Description = "New controls and option models", Span = 1 })
Rich:AddProgress({ Id = "Download", Title = "Progress", Icon = "progress", Min = 0, Max = 100, Default = 62 })
Rich:AddInput({ Id = "Notes", Title = "Textarea", Multiline = true, Height = 100, Placeholder = "Write notes..." })
Rich:AddDropdown({
	Id = "Mode",
	Title = "Advanced dropdown",
	Options = {
		{ Value = "safe", Title = "Safe", Description = "Recommended", Icon = "check" },
		{ Value = "fast", Title = "Fast", Description = "More aggressive", Icon = "star" },
		{
			Value = "pro",
			Title = "Pro",
			Description = "Locked demo",
			Icon = "lock",
			Locked = true,
			LockedReason = "Not unlocked",
		},
	},
	Default = "safe",
})
Rich:AddCode({ Title = "Code", Code = "local value = true\nprint(value)", Height = 100 })
Rich:AddImage({ Title = "Image", Image = "rbxassetid://0", Height = 100, Caption = "Replace with your asset id" })

local Layout = Main:AddSection({ Title = "Layouts", Span = 1 })
local row = Layout:AddRow({ Columns = 2 })
row:AddButton({ Title = "One", Text = "Run" })
row:AddToggle({ Id = "Checkbox", Title = "Checkbox", Style = "Checkbox", Default = true })
local box = Layout:AddTabBox({ Title = "Sub tabs" })
local General = box:AddTab({ Id = "general", Title = "General" })
General:AddToggle({ Id = "GeneralToggle", Title = "Enabled", Default = true })
local Advanced = box:AddTab({ Id = "advanced", Title = "Advanced" })
Advanced:AddSlider({
	Id = "AdvancedSlider",
	Title = "Power",
	Min = 0,
	Max = 100,
	Default = 50,
	FloatingValue = true,
	IconFrom = "minus",
	IconTo = "plus",
})

local Players = UI:AddTab({ Id = "players", Title = "Players", Icon = "user", Group = "PLAYER" })
local Targets = Players:AddSection({ Title = "Targeting" })
Targets:AddDropdown({
	Id = "TargetPlayer",
	Title = "Player",
	Source = BobloUI.Sources.Players({ IncludeLocalPlayer = false }),
	Searchable = true,
	AllowNone = true,
	IgnoreConfig = true,
})
Targets:AddKeybind({ Id = "TargetKey", Title = "Action key", Default = Enum.KeyCode.F, Mode = "Toggle" })

UI:AddTab({
	Id = "locked-demo",
	Title = "Locked tab",
	Icon = "lock",
	Locked = true,
	LockedReason = "Example locked page",
	Group = "OTHER",
})
