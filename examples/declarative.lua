local BobloUI = loadstring(game:HttpGet("https://YOUR_CDN/BobloUI.min.lua"))()
local UI = BobloUI:CreateWindow({ Id = "declarative-demo", Title = "Declarative Demo" })

local handles = UI:Build({
	Tabs = {
		{
			Id = "main",
			Title = "Main",
			Sections = {
				{
					Id = "automation",
					Title = "Automation",
					Controls = {
						{ Type = "Toggle", Id = "Enabled", Title = "Enabled", Default = false },
						{
							Type = "Slider",
							Id = "Range",
							Title = "Range",
							Min = 10,
							Max = 100,
							Default = 50,
							VisibleWhen = { Enabled = true },
						},
						{
							Type = "Dropdown",
							Id = "Mode",
							Title = "Mode",
							Options = { "Safe", "Fast" },
							Default = "Safe",
						},
					},
				},
			},
		},
	},
})

handles.Enabled:OnChanged(function(value)
	print("Enabled:", value)
end)

UI:Get("Range"):Highlight()
