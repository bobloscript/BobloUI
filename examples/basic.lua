local BobloUI = loadstring(game:HttpGet("https://YOUR_CDN/BobloUI.min.lua"))()

local UI = BobloUI:CreateWindow({
	Id = "example-hub",
	Title = "Example Hub",
	Subtitle = BobloUI.Version,
	Theme = "Dark",
	ConfigFolder = "ExampleHub",
	AutoLoad = true,
})

local Farm = UI:AddTab({ Id = "farm", Title = "Farm", Icon = "dashboard" })
local Automation = Farm:AddSection({ Title = "Automation", Column = 1 })

Automation:AddToggle({
	Id = "AutoFarm",
	Title = "Auto Farm",
	Default = false,
	Callback = function(enabled)
		print("AutoFarm", enabled)
	end,
})

Automation:AddSlider({
	Id = "FarmDistance",
	Title = "Farm Distance",
	Min = 10,
	Max = 250,
	Default = 75,
	Suffix = " studs",
	VisibleWhen = { AutoFarm = true },
})

Automation:AddDropdown({
	Id = "Targets",
	Title = "Targets",
	Options = { "Nearest", "Lowest HP", "Highest HP" },
	Default = "Nearest",
})

Automation:AddButton({
	Title = "Save config",
	Callback = function()
		local ok, err = UI.Config:Save("Default")
		UI.Notify:Push({
			Title = ok and "Config saved" or "Save failed",
			Content = ok and "Default.json" or tostring(err),
			Variant = ok and "Success" or "Error",
		})
	end,
})
