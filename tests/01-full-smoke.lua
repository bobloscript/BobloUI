-- Run in an executor/Studio after replacing the URL with a hosted dist/BobloUI.lua.
local BobloUI = loadstring(game:HttpGet("https://YOUR_CDN/BobloUI.lua"))()
local UI =
	BobloUI:CreateWindow({ Id = "bobloui-full-smoke", Title = "BobloUI Full Smoke", ConfigFolder = "BobloUITest" })

local Main = UI:AddTab({ Id = "main", Title = "Main" })
local S = Main:AddSection({ Id = "controls", Title = "Controls", Column = 1 })
local Enabled = S:AddToggle({ Id = "Enabled", Title = "Enabled", Default = false })
local Range =
	S:AddSlider({ Id = "Range", Title = "Range", Min = 0, Max = 100, Default = 25, VisibleWhen = { Enabled = true } })
local Single = S:AddDropdown({ Id = "Single", Title = "Single", Options = { "A", "B", "C" }, Default = "A" })
local Multi =
	S:AddDropdown({ Id = "Multi", Title = "Multi", Options = { "A", "B", "C" }, Default = { "A" }, Multi = true })
S:AddInput({ Id = "Input", Title = "Input", Default = "hello" })
S:AddKeybind({ Id = "Bind", Title = "Keybind", Default = Enum.KeyCode.E, Mode = "Toggle" })
S:AddColorPicker({ Id = "Color", Title = "Color", Default = Color3.fromRGB(80, 140, 255) })
S:AddParagraph({ Id = "Help", Title = "Help", Content = "All ten constructors are mounted." })
S:AddDivider({ Title = "Status" })
local Status = S:AddStatus({ Id = "Targets", Title = "Targets", Value = 0, Status = "Success" })
S:AddButton({
	Title = "Increment",
	Callback = function()
		UI.State:Update("Targets", function(v)
			return (v or 0) + 1
		end)
	end,
})

assert(UI:Get("Enabled") == Enabled, "registry failed")
assert(UI.State:Get("Range") == 25, "default state failed")
assert(not Range:IsVisible(), "VisibleWhen initial state failed")
Enabled:SetValue(true)
assert(Range:IsVisible(), "VisibleWhen update failed")
UI.State:Batch(function()
	UI.State:Set("Range", 80)
	UI.State:Set("Single", "B")
end)
assert(Range:GetValue() == 80 and Single:GetValue() == "B", "batched state failed")
assert(type(Multi:GetValue()) == "table", "multi dropdown value failed")
Status:SetStatus("Warning")

local bad = pcall(function()
	UI:Build({ Tabs = { { Title = "Invalid", Controls = { { Type = "Slider", Title = "Missing bounds", Min = 0 } } } } })
end)
assert(not bad, "declarative pre-validation failed")

local results = UI.Search:Query("range")
assert(#results > 0, "search failed")
local ok, err = UI.Config:Save("Smoke")
assert(ok, tostring(err))
UI.State:Set("Range", 1)
assert(UI.Config:Load("Smoke"))
assert(UI.State:Get("Range") == 80, "config restore failed")

print("BobloUI full smoke: PASS", BobloUI.Version, UI.Device.Layout)
