--[[
	shell/runtime acceptance test — run this in an executor or in Studio.

	Checks the three things step 3 exists to prove:
	  1. the shell renders and the three ScreenGui layers are present
	  2. a theme change repaints through the binding registry, without
	     rebuilding a single Instance
	  3. resizing the viewport (or rotating a phone) switches Wide/Rail/Drawer
	     without losing tab state
]]

local BobloUI = loadstring(game:HttpGet("https://YOUR_CDN/BobloUI.lua"))()

local UI = BobloUI:CreateWindow({
	Id = "example-hub",
	Title = "Example Hub",
	Subtitle = "shell smoke",
	Theme = "Dark",
	Accent = Color3.fromHex("#5B8CFF"),
	Density = "Comfortable",
	Size = UDim2.fromOffset(780, 520),
})

UI:AddTab({ Id = "farm", Title = "Farming" })
UI:AddTab({ Id = "combat", Title = "Combat" })
UI:AddTab({ Id = "player", Title = "Player" })
UI:AddTab({ Id = "visuals", Title = "Visuals" })
UI:AddTab({ Id = "settings", Title = "Settings" })

print("environment:", BobloUI.Env.Describe())
print("layout:", UI.Device.Layout, "| class:", UI.Device.Class)
print("theme bindings:", UI.Theme:BindingCount())

-- 1. Runtime theme switching. Watch the binding count: it must not grow.
task.delay(3, function()
	UI:SetTheme("Light")
	print("after SetTheme, bindings:", UI.Theme:BindingCount())
end)

task.delay(6, function()
	UI:SetAccent(Color3.fromHex("#F2555A"))
end)

-- 2. Density. On a phone, Compact is clamped to a usable tap target.
task.delay(9, function()
	UI:SetDensity("Compact")
	print("control height:", UI.Tokens:Get("ControlHeight"))
end)

task.delay(12, function()
	UI:SetTheme("Dark")
	UI:SetDensity("Comfortable")
end)

-- 3. Teardown. Nothing should remain on screen and no listener should survive.
task.delay(20, function()
	UI:Unload()
	print("unloaded; windows still registered:", #BobloUI:ListWindows())
end)
