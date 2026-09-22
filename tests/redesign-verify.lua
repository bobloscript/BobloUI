-- BobloUI Visual Redesign Verification Script
-- Запусти в Roblox executor. Каждый тест выводит PASS/FAIL.

local PASS = 0
local FAIL = 0

local function check(name, condition)
    if condition then
        PASS += 1
        print(`[PASS] {name}`)
    else
        FAIL += 1
        warn(`[FAIL] {name}`)
    end
end

local Players = game:GetService("Players")
local BOBLOUI_URL = "https://raw.githubusercontent.com/bobloscript/BobloUI/redesign/visual-overhaul/dist/BobloUI.min.lua"

local okLib, BobloUI = pcall(function()
    return loadstring(game:HttpGet(BOBLOUI_URL))()
end)
check("BobloUI loads", okLib and type(BobloUI) == "table")

local UI = BobloUI:CreateWindow({
    Id = "redesign-test",
    Title = "Redesign Verify",
    Icon = "test-tube",
    Theme = "Dark",
    Presentation = "Standard",
    ConfigFolder = "RedesignTest",
    AutoLoad = false,
})

-- Test 1: Public API exists
check("CreateWindow returns table", type(UI) == "table")
check("AddTab exists", type(UI.AddTab) == "function")
check("SetTheme exists", type(UI.SetTheme) == "function")
check("SetAccent exists", type(UI.SetAccent) == "function")
check("SetThemeToken exists", type(UI.SetThemeToken) == "function")
check("SetKeybindHUD exists", type(UI.SetKeybindHUD) == "function")
check("SetKeybindHUDSide exists", type(UI.SetKeybindHUDSide) == "function")
check("ShowLoading exists", type(UI.ShowLoading) == "function")
check("HideLoading exists", type(UI.HideLoading) == "function")

-- Test 2: Tabs
local Tab1 = UI:AddTab({ Title = "Test Tab 1", Icon = "star" })
local Tab2 = UI:AddTab({ Title = "Test Tab 2", Icon = "heart" })
check("AddTab returns tab", type(Tab1) == "table" and type(Tab2) == "table")

-- Test 3: Sections — flat, no default icon
local S1 = Tab1:AddSection({ Title = "Flat Section" })
check("Section without Icon has nil Icon", S1.Icon == nil)

local S2 = Tab1:AddSection({ Title = "Icon Section", Icon = "zap" })
check("Section with Icon has icon", S2.Icon == "zap")

-- Test 4: Controls
local tog = S1:AddToggle({ Id = "T1", Title = "Toggle", Default = false })
check("AddToggle returns control", type(tog) == "table")

local sl = S1:AddSlider({ Id = "S1", Title = "Slider", Min = 0, Max = 100, Default = 50 })
check("AddSlider returns control", type(sl) == "table")

local btn = S1:AddButton({ Title = "Button", Text = "Click" })
check("AddButton returns control", type(btn) == "table")

local st = S1:AddStatus({ Id = "ST1", Title = "Status", Value = "OK" })
check("AddStatus returns control", type(st) == "table")

local pr = S1:AddProgress({ Id = "P1", Title = "Progress", Default = 0.5 })
check("AddProgress returns control", type(pr) == "table")

local kb = S1:AddKeybind({ Id = "KB1", Title = "Keybind", Default = { Key = "E", Mode = "Toggle" } })
check("AddKeybind returns control", type(kb) == "table")

local dd = S1:AddDropdown({ Id = "DD1", Title = "Dropdown", Options = {"A", "B"}, Default = "A" })
check("AddDropdown returns control", type(dd) == "table")

local inp = S1:AddInput({ Id = "IN1", Title = "Input", Placeholder = "..." })
check("AddInput returns control", type(inp) == "table")

-- Test 5: Keybind ShowInHUD option
local kbHud = S1:AddKeybind({ Id = "KB_HUD", Title = "HUD Key", Default = { Key = "Q", Mode = "Toggle" }, ShowInHUD = true })
check("Keybind ShowInHUD option accepted", kbHud.ShowInHUD == true)

local kbNoHud = S1:AddKeybind({ Id = "KB_NOHUD", Title = "No HUD", Default = { Key = "T", Mode = "Toggle" }, ShowInHUD = false })
check("Keybind ShowInHUD=false accepted", kbNoHud.ShowInHUD == false)

-- Test 6: Theme
check("SetTheme works", pcall(function() UI:SetTheme("Dark") end))
check("SetAccent works", pcall(function() UI:SetAccent(Color3.fromHex("#cbb7ff")) end))
check("SetThemeToken works", pcall(function() UI:SetThemeToken("Accent", Color3.fromHex("#7C6CF2")) end))

-- Test 7: State
check("SetValue works", pcall(function() tog:SetValue(true) end))
check("GetValue returns set value", tog:GetValue() == true)
check("Reset works", pcall(function() tog:Reset() end))

-- Test 8: Keybind HUD
check("SetKeybindHUD(true) works", pcall(function() UI:SetKeybindHUD(true) end))
check("SetKeybindHUD(false) works", pcall(function() UI:SetKeybindHUD(false) end))
check("SetKeybindHUDSide works", pcall(function() UI:SetKeybindHUDSide("Left") end))
check("SetKeybindHUDSide Right works", pcall(function() UI:SetKeybindHUDSide("Right") end))

-- Test 9: Loading
check("ShowLoading works", pcall(function() UI:ShowLoading() end))
task.delay(0.2, function()
    check("HideLoading works", pcall(function() UI:HideLoading() end))
end)

-- Test 10: Visibility
check("SetVisible works", pcall(function() tog:SetVisible(false) end))
check("IsVisible returns false", tog:IsVisible() == false)
check("SetVisible restore", pcall(function() tog:SetVisible(true) end))

-- Test 11: Disabled
check("SetDisabled works", pcall(function() tog:SetDisabled(true) end))
check("IsDisabled returns true", tog:IsDisabled() == true)
check("SetDisabled restore", pcall(function() tog:SetDisabled(false) end))

-- Test 12: Footer
check("SetFooterText works", pcall(function() UI:SetFooterText("Test footer") end))
check("GetFooterText returns value", UI:GetFooterText() == "Test footer")

-- Test 13: Geometry
check("SetSize works", pcall(function() UI:SetSize(UDim2.fromOffset(800, 500)) end))
check("GetGeometry works", type(UI:GetGeometry()) == "table")

-- Test 14: Notification
check("Notify:Push works", pcall(function()
    UI.Notify:Push({ Title = "Test", Content = "Verification", Duration = 1 })
end))

-- Test 15: Destroy controls
check("Destroy control works", pcall(function() kbHud:Destroy() end))

-- Summary
task.delay(0.5, function()
    print(`\n===== RESULTS: {PASS} passed, {FAIL} failed =====`)
    if FAIL == 0 then
        print("All tests passed!")
    else
        warn(`${FAIL} test(s) FAILED`)
    end
end)
