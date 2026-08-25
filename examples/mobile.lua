local BobloUI = loadstring(game:HttpGet("https://YOUR_CDN/BobloUI.min.lua"))()
local UI = BobloUI:CreateWindow({
	Id = "mobile-demo",
	Title = "Mobile Demo",
	Density = "Comfortable",
	Scale = 1,
})

local Main = UI:AddTab({ Id = "main", Title = "Main" })
Main:AddToggle({ Id = "TouchFeature", Title = "Touch-friendly toggle", Default = true })
Main:AddDropdown({
	Id = "Choice",
	Title = "Choice",
	Options = { "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" },
})
Main:AddInput({ Id = "Name", Title = "Name", Placeholder = "Type here" })

print("Class:", UI.Device.Class, "Layout:", UI.Device.Layout)
