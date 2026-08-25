local BobloUI =
	loadstring(game:HttpGet("https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.lua"))()

local UI = BobloUI:CreateWindow({
	Id = "bobloui-visual-showcase",
	Title = "BobloUI",
	Subtitle = "UI framework preview",
	Theme = "Dark",
	Accent = Color3.fromHex("#8172F2"),
	Density = "Comfortable",
	Size = UDim2.fromOffset(720, 480),
})

local Main = UI:AddTab({
	Id = "main",
	Title = "Dashboard",
	Description = "Overview and automation",
	Icon = "dashboard",
	Badge = "NEW",
})
local Player =
	UI:AddTab({ Id = "player", Title = "Player", Description = "Movement and character controls", Icon = "user" })
local Visuals =
	UI:AddTab({ Id = "visuals", Title = "Visuals", Description = "ESP and appearance settings", Icon = "eye" })

local Automation = Main:AddSection({ Title = "Automation", Description = "Core gameplay helpers", Column = 1 })
Automation:AddToggle({
	Id = "AutoFarm",
	Title = "Auto Farm",
	Description = "Automatically farms nearby targets",
	Default = true,
})
Automation:AddSlider({
	Id = "Distance",
	Title = "Farm Distance",
	Description = "Maximum target distance",
	Min = 10,
	Max = 250,
	Default = 85,
	Suffix = " studs",
})
Automation:AddDropdown({
	Id = "Target",
	Title = "Target Priority",
	Options = { "Nearest", "Lowest HP", "Highest HP" },
	Default = "Nearest",
})
Automation:AddButton({
	Title = "Teleport to target",
	Text = "Teleport",
	Variant = "Primary",
	Callback = function()
		UI.Notify:Push({ Title = "Teleported", Content = "Moved to the selected target.", Variant = "Success" })
	end,
})

local Profile = Main:AddSection({ Title = "Profile", Description = "Preferences and saved values", Column = 2 })
Profile:AddInput({ Id = "ProfileName", Title = "Profile name", Placeholder = "Default", Default = "Farming" })
Profile:AddKeybind({ Id = "ToggleFarm", Title = "Farm keybind", Default = Enum.KeyCode.F, Mode = "Toggle" })
Profile:AddColorPicker({
	Id = "EspColor",
	Title = "ESP Color",
	Default = Color3.fromHex("#8172F2"),
	Presets = { Color3.fromHex("#8172F2"), Color3.fromHex("#55D89A"), Color3.fromHex("#F06469") },
})
Profile:AddStatus({ Title = "Server", Value = "Connected", Status = "Success" })

local Movement = Player:AddSection({ Title = "Movement", Description = "Character movement", Column = 1 })
Movement:AddSlider({
	Id = "WalkSpeed",
	Title = "Walk Speed",
	Description = "Character movement speed",
	Min = 16,
	Max = 100,
	Default = 24,
})
Movement:AddSlider({ Id = "JumpPower", Title = "Jump Power", Min = 50, Max = 150, Default = 60 })
Movement:AddToggle({
	Id = "Noclip",
	Title = "Noclip",
	Description = "Move through collision",
	Default = false,
	Badge = "BETA",
})

local Character = Player:AddSection({ Title = "Character", Description = "Local character settings", Column = 2 })
Character:AddToggle({ Id = "InfiniteJump", Title = "Infinite Jump", Default = false })
Character:AddDropdown({
	Id = "HipHeight",
	Title = "Movement preset",
	Options = { "Default", "Fast", "Custom" },
	Default = "Default",
})
Character:AddButton({ Title = "Reset character", Text = "Reset", Variant = "Default" })

local ESP = Visuals:AddSection({ Title = "ESP", Description = "Player overlays", Column = 1 })
ESP:AddToggle({ Id = "ESP", Title = "Player ESP", Description = "Show players through the map", Default = true })
ESP:AddDropdown({
	Id = "Parts",
	Title = "ESP Parts",
	Options = { "Name", "Box", "Distance", "Health" },
	Default = { "Name", "Box" },
	Multi = true,
})
ESP:AddSlider({ Id = "ESPDistance", Title = "Max Distance", Min = 100, Max = 5000, Default = 1500, Suffix = " studs" })

local Appearance = Visuals:AddSection({ Title = "Appearance", Description = "Overlay presentation", Column = 2 })
Appearance:AddColorPicker({ Id = "AccentPreview", Title = "Highlight color", Default = Color3.fromHex("#58B9FF") })
Appearance:AddToggle({ Id = "Tracers", Title = "Tracers", Default = false })
Appearance:AddDropdown({
	Id = "FontSize",
	Title = "Text size",
	Options = { "Small", "Medium", "Large" },
	Default = "Medium",
})
