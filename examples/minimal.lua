-- Small hub: one title, five switches, one slider, and a tab menu when needed.
local source = "https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.lua"
local BobloUI = loadstring(game:HttpGet(source))()

local UI = BobloUI:CreateWindow({
	Id = "minimal-example",
	Title = "MERGE A NUKE!",
	Icon = "rocket",
	Presentation = "Minimal",
	Theme = "Dark",
	Accent = Color3.fromHex("#FFA94D"),
	-- Size.Y.Offset is an optional height limit; omit Size for auto height.
})

local Main = UI:AddTab({ Id = "main", Title = "Main" })
Main:AddToggle({ Id = "AutoMerge", Title = "Auto Merge", Style = "Checkbox", Default = true })
Main:AddToggle({ Id = "AutoLocked", Title = "Auto Locked", Style = "Checkbox", Default = true })
Main:AddToggle({ Id = "TierUpgrade", Title = "Tier Upgrade", Style = "Checkbox" })
Main:AddToggle({ Id = "SpawnUpgrade", Title = "Spawn Upgrade", Style = "Checkbox" })
Main:AddToggle({ Id = "LockUpgrade", Title = "Lock Upgrade", Style = "Checkbox" })
Main:AddSlider({ Id = "MergeDelay", Title = "Merge Delay", Min = 0, Max = 2, Default = 0.5, Step = 0.1, Suffix = " s" })

-- Add another tab only if the script needs it. The header chevron opens the tab list.
-- local Extras = UI:AddTab({ Id = "extras", Title = "Extras" })
-- Extras:AddButton({ Title = "Open video", Text = "Open", Callback = function() end })
