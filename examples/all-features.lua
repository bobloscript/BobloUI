-- BobloUI feature showcase. Replace SOURCE if needed.
local SOURCE = "https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.lua"
local BobloUI = loadstring(game:HttpGet(SOURCE))()

-- Example custom icon + control extension.
BobloUI.Icon.Register("spark", function(window, root)
	local dot = Instance.new("Frame")
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

BobloUI:RegisterControl("ActionCard", function(section, options)
	return section:AddButton({
		Title = options.Title or "Action",
		Description = options.Description,
		Text = options.Text or "Run",
		Variant = options.Variant,
		Callback = options.Callback,
	})
end)

local UI = BobloUI:CreateWindow({
	Id = "bobloui-all-features",
	Title = "BobloUI",
	Subtitle = "All features · 0.11",
	Theme = "Dark",
	Accent = Color3.fromHex("8172F2"),
	Density = "Comfortable",
	Scale = 1,
	ConfigFolder = "BobloUIShowcase",
	Settings = true,
	KeyboardNavigation = true,
	FooterText = "BobloUI showcase · ready",
})

local Dashboard =
	UI:AddTab({ Id = "dashboard", Title = "Dashboard", Icon = "dashboard", Group = "MAIN", Badge = "0.11" })
local Player = UI:AddTab({ Id = "player", Title = "Player", Icon = "user", Group = "PLAYER" })
local Visuals = UI:AddTab({ Id = "visuals", Title = "Visuals", Icon = "eye", Group = "PLAYER" })

local Automation = Dashboard:AddSection({
	Id = "automation",
	Title = "Automation",
	Description = "Responsive gameplay controls",
	Span = 1,
	Layout = "Stack",
	Collapsible = true,
})
local Tools = Dashboard:AddSection({
	Id = "tools",
	Title = "Interface Lab",
	Description = "Built-in UX services",
	Span = "Auto",
	Layout = "Auto",
})

Automation:AddToggle({ Id = "AutoFarm", Title = "Auto Farm", Description = "Master farming switch", Default = true })
Automation:AddSlider({
	Id = "FarmDistance",
	Title = "Farm Distance",
	Description = "Maximum target distance",
	Min = 10,
	Max = 250,
	Step = 5,
	Default = 85,
	Suffix = " studs",
	VisibleWhen = { AutoFarm = true },
})
Automation:AddDropdown({
	Id = "TargetPriority",
	Title = "Target Priority",
	Options = { "Nearest", "Highest HP", "Lowest HP" },
	Default = "Nearest",
})
Automation:AddDropdown({
	Id = "FarmMode",
	Title = "Farm Mode",
	Options = { "Safe", "Fast", "Manual" },
	Default = "Safe",
	Style = "Segmented",
})
Automation:AddCustom("ActionCard", {
	Title = "Teleport to target",
	Text = "Teleport",
	Variant = "Primary",
	Callback = function()
		UI.Notify:Push({ Title = "Teleport", Content = "Demo action triggered.", Variant = "Success" })
	end,
})

Tools:AddButton({
	Title = "Settings",
	Description = "Theme editor, configs, favorites and keybinds",
	Text = "Open Settings",
	Callback = function()
		UI:OpenSettings()
	end,
})
Tools:AddButton({
	Title = "Command Palette",
	Text = "Open Search",
	Callback = function()
		UI:OpenSearch()
	end,
})
Tools:AddButton({
	Title = "Choice Dialog",
	Text = "Open Dialog",
	Callback = function()
		task.spawn(function()
			local value = UI.Dialog
				:Choice({
					Title = "Choose a mode",
					Content = "Choice dialogs return the supplied value.",
					Choices = {
						{ Text = "Safe", Value = "safe", Primary = true },
						{ Text = "Fast", Value = "fast" },
						{ Text = "Cancel", Value = nil },
					},
				})
				:Await()
			UI.Notify:Push({ Title = "Choice", Content = "Result: " .. tostring(value), Variant = "Default" })
		end)
	end,
})
Tools:AddButton({
	Title = "Progress Notification",
	Text = "Run Demo",
	Callback = function()
		task.spawn(function()
			local n = UI.Notify:Push({
				Title = "Processing",
				Content = "Starting…",
				Variant = "Loading",
				Progress = 0,
				Duration = 0,
			})
			for i = 1, 10 do
				task.wait(0.08)
				n:SetProgress(i / 10):Update({ Content = (i * 10) .. "%" })
			end
			n:Update({
				Title = "Complete",
				Content = "Progress notification finished.",
				Variant = "Success",
				Progress = 1,
				Duration = 2,
			})
			task.delay(2, function()
				n:Dismiss()
			end)
		end)
	end,
})
Tools:AddInput({ Id = "ProfileName", Title = "Profile name", Default = "Farming" })
Tools:AddKeybind({ Id = "FarmKeybind", Title = "Farm keybind", Default = Enum.KeyCode.F, Mode = "Toggle" })

local Movement = Player:AddSection({
	Id = "movement",
	Title = "Movement",
	Description = "Adaptive controls stack on narrow cards",
	Span = 2,
	Layout = "Auto",
})
Movement:AddToggle({ Id = "SpeedEnabled", Title = "Speed boost", Default = false })
Movement:AddSlider({
	Id = "WalkSpeed",
	Title = "Walk speed",
	Min = 16,
	Max = 100,
	Default = 32,
	VisibleWhen = {
		SpeedEnabled = true,
	},
})
Movement:AddSlider({ Id = "JumpPower", Title = "Jump power", Min = 50, Max = 150, Default = 50 })
Movement:AddToggle({ Id = "Noclip", Title = "Noclip", Description = "Move through collision", Default = false })
Movement:AddButton({
	Title = "Reset movement",
	Text = "Reset",
	Variant = "Ghost",
	Callback = function()
		Movement:Reset()
	end,
})

local Appearance = Visuals:AddSection({
	Id = "appearance",
	Title = "Appearance",
	Description = "Color and selection controls",
	Span = "Auto",
	Layout = "Auto",
})
Appearance:AddColorPicker({
	Id = "ESPColor",
	Title = "ESP Color",
	Default = Color3.fromHex("8172F2"),
	Alpha = true,
	DefaultAlpha = 0.9,
	Presets = { Color3.fromHex("8172F2"), Color3.fromHex("5EE6A8"), Color3.fromHex("FF5E7D") },
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
	Options = { "Name", "Box", "Distance", "Tracers" },
	Default = { "Name", "Box" },
	Multi = true,
	Searchable = true,
})
Appearance:AddToggle({ Id = "Tracers", Title = "Tracers", Default = false })
Appearance:AddStatus({ Id = "RendererStatus", Title = "Renderer", Value = "Ready", Status = "Success" })

-- A custom command appears under `>` in the palette.
UI.Commands:Register({
	Id = "demo.light",
	Title = "Switch to Light theme",
	Keywords = { "light", "theme" },
	Callback = function()
		UI:SetTheme("Light")
	end,
})
UI.Commands:Register({
	Id = "demo.favorite",
	Title = "Favorite Auto Farm",
	Keywords = { "favorite", "pin" },
	Callback = function()
		UI.Favorites:Add("AutoFarm")
	end,
})

-- Open Settings from the header/palette or programmatically with UI:OpenSettings().
-- Settings contains theme preset + arbitrary accent/token editor, scale, density,
-- language, accessibility, window preferences, config profiles, Favorites and keybinds.
