-- Runtime smoke for executor/Studio after publishing dist/BobloUI.lua.
local source = "https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.lua"
local BobloUI = loadstring(game:HttpGet(source))()
local UI = BobloUI:CreateWindow({
	Id = "minimal-smoke",
	Title = "Minimal smoke",
	Presentation = "Minimal",
	Settings = false,
})
assert(UI._layout == "Minimal", "minimal window layout missing")

local Main = UI:AddTab({ Id = "minimal-main", Title = "Main" })
local First = Main:AddSection({ Title = "First" })
local calls = 0
local Toggle = First:AddToggle({ Id = "minimal-switch", Title = "Switch", Style = "Checkbox", Callback = function()
	calls += 1
end })
First:AddSlider({ Id = "minimal-delay", Title = "Delay", Min = 0, Max = 2, Default = 0.5 })
task.wait(0.3)
assert(First:GetInstance() and not First._header.Visible, "single section should have no visible heading")
assert(UI._root.AbsoluteSize.X < 450, "minimal window is too wide")
assert(UI._root.AbsoluteSize.Y < 370, "short content should not leave a tall empty window")
Toggle:Flip()
assert(Toggle:GetValue() == true and calls == 1, "toggle state or callback changed")

local Second = Main:AddSection({ Title = "Second" })
Second:AddButton({ Title = "Action", Text = "Run", Callback = function() end })
task.wait(0.2)
assert(First._header.Visible and Second._header.Visible, "multiple sections should show headings")
local height = UI._root.AbsoluteSize.Y
local Extra = UI:AddTab({ Id = "minimal-extra", Title = "Extra" })
local extraToggle = Extra:AddToggle({ Id = "minimal-extra-switch", Title = "Extra switch" })
assert(extraToggle.Style == "Checkbox", "minimal toggle should default to a checkbox")
assert(UI._minimalMenuButton.Visible, "tab menu missing")
Extra:Select()
task.wait(0.2)
assert(UI._active == Extra and UI._root.AbsoluteSize.Y < height, "tab selection should recalculate height")
Extra:SetVisible(false)
task.wait(0.2)
assert(UI._active == Main and not Extra:GetInstance().Visible, "hiding active tab left its page visible")
UI:SetTheme("Light")
assert(UI.Theme:Current() == "Light", "theme switching failed")
UI:Unload()
print("minimal smoke: PASS (visually inspect checkbox row, popup and scrolling in executor)")
