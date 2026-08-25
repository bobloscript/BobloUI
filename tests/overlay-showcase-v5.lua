local BobloUI =
	loadstring(game:HttpGet("https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.lua"))()

local UI = BobloUI:CreateWindow({
	Id = "bobloui-overlay-showcase-v5",
	Title = "BobloUI",
	Subtitle = "Overlay polish V5",
	Theme = "Dark",
	Accent = Color3.fromHex("#8172F2"),
	Density = "Comfortable",
	Size = UDim2.fromOffset(720, 480),
})

local Main = UI:AddTab({
	Id = "main",
	Title = "Dashboard",
	Description = "Overlay and component preview",
	Icon = "dashboard",
	Badge = "V5",
})
local Visuals =
	UI:AddTab({ Id = "visuals", Title = "Visuals", Description = "Dropdown and color controls", Icon = "eye" })

local Automation = Main:AddSection({ Title = "Automation", Description = "Core gameplay helpers", Column = 1 })
Automation:AddToggle({
	Id = "AutoFarm",
	Title = "Auto Farm",
	Description = "Automatically farms nearby targets",
	Default = true,
	Tooltip = "This tooltip should stay compact and close to the control.",
	ContextMenu = {
		{
			Text = "Reset value",
			Icon = "settings",
			Callback = function()
				UI.State:Set("AutoFarm", false)
			end,
		},
	},
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

local Overlays = Main:AddSection({ Title = "Overlay Lab", Description = "Open each overlay from here", Column = 2 })
Overlays:AddButton({
	Title = "Command Palette",
	Text = "Open Search",
	Callback = function()
		UI:OpenSearch("")
	end,
})
Overlays:AddButton({
	Title = "Confirm Dialog",
	Text = "Open Dialog",
	Callback = function()
		task.spawn(function()
			local ok = UI.Dialog
				:Confirm({
					Title = "Reset settings?",
					Content = "This compact dialog should only use the space it needs.",
					Confirm = "Reset",
					Danger = true,
				})
				:Await()
			if ok then
				UI.Notify:Push({ Title = "Settings reset", Content = "Dialog returned true.", Variant = "Warning" })
			end
		end)
	end,
})
Overlays:AddButton({
	Title = "Notification",
	Text = "Show Toast",
	Callback = function()
		UI.Notify:Push({
			Title = "Config saved",
			Content = "Farming.json",
			Variant = "Success",
			Actions = { { Text = "Undo", Callback = function() end } },
		})
	end,
})
Overlays:AddInput({ Id = "ProfileName", Title = "Profile name", Placeholder = "Default", Default = "Farming" })

local Appearance = Visuals:AddSection({ Title = "Appearance", Description = "Compact desktop popovers", Column = 1 })
Appearance:AddColorPicker({
	Id = "ESPColor",
	Title = "ESP Color",
	Default = Color3.fromHex("#8172F2"),
	Presets = { Color3.fromHex("#8172F2"), Color3.fromHex("#55D89A"), Color3.fromHex("#F06469") },
})
Appearance:AddDropdown({
	Id = "TextSize",
	Title = "Text size",
	Options = { "Small", "Medium", "Large" },
	Default = "Medium",
})
Appearance:AddDropdown({
	Id = "ESPParts",
	Title = "ESP Parts",
	Options = { "Name", "Box", "Distance", "Health", "Tracer", "Skeleton", "Team", "Tool", "Chams" },
	Default = { "Name", "Box" },
	Multi = true,
})
Appearance:AddToggle({ Id = "Tracers", Title = "Tracers", Default = false })

UI.Commands:Register({
	Id = "save-config",
	Title = "Save current config",
	Keywords = { "save", "config" },
	Callback = function()
		UI.Notify:Push({ Title = "Command executed", Content = "Save current config", Variant = "Success" })
	end,
})
UI.Commands:Register({
	Id = "toggle-theme",
	Title = "Toggle theme",
	Keywords = { "theme", "dark", "light" },
	Callback = function()
		UI:SetTheme(UI.Theme:Current() == "Dark" and "Light" or "Dark")
	end,
})
UI.Commands:Register({
	Id = "open-visuals",
	Title = "Open Visuals tab",
	Keywords = { "visuals", "esp" },
	Callback = function()
		Visuals:Select()
	end,
})
