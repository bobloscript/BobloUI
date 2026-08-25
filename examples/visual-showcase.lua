local BobloUI =
	loadstring(game:HttpGet("https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.lua"))()

local UI = BobloUI:CreateWindow({
	Id = "bobloui-visual-showcase",
	Title = "BobloUI",
	Subtitle = "Visual V2 · " .. BobloUI.Version,
	Icon = "sparkles",
	Theme = "Dark",
	Accent = Color3.fromHex("#7C5CFC"),
	Density = "Comfortable",
})

local Main = UI:AddTab({ Id = "main", Title = "Dashboard", Icon = "dashboard", Badge = "NEW" })
local Player = UI:AddTab({ Id = "player", Title = "Player", Icon = "user" })
local Visuals = UI:AddTab({ Id = "visuals", Title = "Visuals", Icon = "eye" })

local Automation =
	Main:AddSection({ Title = "Automation", Description = "Core gameplay helpers", Icon = "wand-sparkles", Column = 1 })
Automation:AddToggle({
	Id = "AutoFarm",
	Title = "Auto Farm",
	Description = "Automatically farms nearby targets",
	Icon = "bot",
	Default = true,
})
Automation:AddSlider({
	Id = "Distance",
	Title = "Farm Distance",
	Description = "Maximum target distance",
	Icon = "ruler",
	Min = 10,
	Max = 250,
	Default = 85,
	Suffix = " studs",
})
Automation:AddDropdown({
	Id = "Target",
	Title = "Target Priority",
	Icon = "crosshair",
	Options = { "Nearest", "Lowest HP", "Highest HP" },
	Default = "Nearest",
})
Automation:AddButton({
	Title = "Teleport to target",
	Text = "Teleport",
	Icon = "map-pin-check",
	Variant = "Primary",
	Callback = function()
		UI.Notify:Push({ Title = "Teleported", Content = "Moved to the selected target.", Variant = "Success" })
	end,
})

local Profile =
	Main:AddSection({ Title = "Profile", Description = "Preferences and saved values", Icon = "user-cog", Column = 2 })
Profile:AddInput({
	Id = "ProfileName",
	Title = "Profile name",
	Icon = "tag",
	Placeholder = "Default",
	Default = "Farming",
})
Profile:AddKeybind({
	Id = "ToggleFarm",
	Title = "Farm keybind",
	Icon = "keyboard",
	Default = Enum.KeyCode.F,
	Mode = "Toggle",
})
Profile:AddColorPicker({
	Id = "EspColor",
	Title = "ESP Color",
	Icon = "pipette",
	Default = Color3.fromHex("#7C5CFC"),
	Presets = { Color3.fromHex("#7C5CFC"), Color3.fromHex("#42D392"), Color3.fromHex("#F06469") },
})
Profile:AddStatus({ Title = "Server", Icon = "server", Value = "Connected", Status = "Success" })
Profile:AddParagraph({
	Title = "Tip",
	Icon = "lightbulb",
	Content = "Press Ctrl+K to search controls or run commands.",
	Variant = "Info",
})

local Movement = Player:AddSection({ Title = "Movement", Icon = "footprints" })
Movement:AddSlider({ Id = "WalkSpeed", Title = "Walk Speed", Icon = "gauge", Min = 16, Max = 100, Default = 24 })
Movement:AddToggle({
	Id = "Noclip",
	Title = "Noclip",
	Icon = "move-3d",
	Description = "Move through collision",
	Default = false,
	Badge = "BETA",
})

local Appearance = Visuals:AddSection({ Title = "Appearance", Icon = "palette" })
Appearance:AddToggle({ Id = "ESP", Title = "Player ESP", Icon = "scan-eye", Default = true })
Appearance:AddDropdown({
	Id = "Parts",
	Title = "ESP Parts",
	Icon = "list-checks",
	Options = { "Name", "Box", "Distance", "Health" },
	Default = { "Name", "Box" },
	Multi = true,
})
Appearance:AddColorPicker({
	Id = "AccentPreview",
	Title = "Highlight color",
	Icon = "paint-bucket",
	Default = Color3.fromHex("#58B9FF"),
})
