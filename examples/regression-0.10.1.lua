-- BobloUI 0.10.1 regression showcase.
-- Replace the GitHub file first; this script intentionally loads the public RAW URL.
local SOURCE = "https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.lua"
local BobloUI = loadstring(game:HttpGet(SOURCE))()

local UI = BobloUI:CreateWindow({
	Id = "bobloui-regression-0101",
	Title = "BobloUI",
	Subtitle = "0.10.1 regression check",
	Theme = "Dark",
	Accent = Color3.fromHex("5EE6A8"),
	Density = "Comfortable",
	Settings = true,
})

local Dashboard =
	UI:AddTab({ Id = "dashboard", Title = "Dashboard", Icon = "dashboard", Group = "MAIN", Badge = "0.10.1" })
local Player = UI:AddTab({ Id = "player", Title = "Player", Icon = "user", Group = "MAIN" })
local Visuals = UI:AddTab({ Id = "visuals", Title = "Visuals", Icon = "eye", Group = "MAIN" })

-- Left is intentionally much taller than the first right card. The second right
-- card should sit directly under the first one; there should be no giant hole.
local Tall = Dashboard:AddSection({ Title = "Tall left card", Description = "Masonry regression", Span = 1 })
Tall:AddToggle({ Id = "R_A", Title = "Auto Farm", Default = true })
Tall:AddSlider({ Id = "R_B", Title = "Distance", Min = 0, Max = 100, Default = 55 })
Tall:AddDropdown({
	Id = "R_C",
	Title = "Target",
	Options = { "Nearest", "Highest HP", "Lowest HP" },
	Default = "Nearest",
})
Tall:AddInput({ Id = "R_D", Title = "Profile", Default = "Farming" })
Tall:AddToggle({ Id = "R_E", Title = "Auto Quest", Default = false })
Tall:AddToggle({ Id = "R_F", Title = "Auto Collect", Default = true })
Tall:AddSlider({ Id = "R_G", Title = "Delay", Min = 0, Max = 10, Default = 2 })

local Short = Dashboard:AddSection({ Title = "Short right card", Description = "Should stay compact", Span = 1 })
Short:AddButton({
	Title = "Choice dialog",
	Text = "Open",
	Callback = function()
		task.spawn(function()
			local result = UI.Dialog
				:Choice({
					Title = "Choose a mode",
					Choices = {
						{ Text = "Safe", Value = "safe", Primary = true },
						{ Text = "Fast", Value = "fast" },
						{ Text = "Cancel", Value = nil },
					},
				})
				:Await()
			UI.Notify:Push({ Title = "Choice result", Content = tostring(result), Duration = 2 })
		end)
	end,
})

local KeybindCard =
	Dashboard:AddSection({ Title = "Keybind regression", Description = "Press/capture must be reliable", Span = 1 })
local fires = 0
local keyStatus = KeybindCard:AddStatus({ Id = "R_KeyStatus", Title = "F presses", Value = "0", Status = "Success" })
KeybindCard:AddKeybind({
	Id = "R_Keybind",
	Title = "Test keybind",
	Default = Enum.KeyCode.F,
	Mode = "Toggle",
	Callback = function(active)
		fires += 1
		keyStatus:SetValue(tostring(fires) .. " · " .. (active and "ON" or "OFF"))
	end,
})
KeybindCard:AddParagraph({
	Content = "Click the key field, bind another key, then test it while the game itself also uses that key.",
})

local AccentCard = Dashboard:AddSection({
	Title = "Accent regression",
	Description = "All sidebar icons use Accent / AccentMuted",
	Span = 1,
})
AccentCard:AddColorPicker({
	Id = "R_Accent",
	Title = "Accent",
	Default = Color3.fromHex("5EE6A8"),
	Callback = function(value)
		local color = type(value) == "table" and value.Color or value
		if typeof(color) == "Color3" then
			UI:SetAccent(color)
		end
	end,
})
AccentCard:AddButton({
	Title = "Open full settings",
	Text = "Settings",
	Callback = function()
		UI:OpenSettings()
	end,
})

Player:AddSection({ Title = "Player", Span = "Auto" }):AddParagraph({
	Content = "Switch tabs after changing Accent. Inactive icons should remain a muted version of the chosen accent.",
})
Visuals:AddSection({ Title = "Visuals", Span = "Auto" })
	:AddParagraph({ Content = "Resize the window: two columns should fall back to one without overflow." })
