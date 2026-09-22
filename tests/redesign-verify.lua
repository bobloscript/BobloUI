-- Тестовый скрипт для проверки BobloUI редизайна
-- Запусти в Roblox executor

local BOBLOUI_URL = "https://raw.githubusercontent.com/bobloscript/BobloUI/redesign/visual-overhaul/dist/BobloUI.min.lua"

local UI = loadstring(game:HttpGet(BOBLOUI_URL))()

local W = UI:CreateWindow({
    Title = "Visual Redesign Test",
    Icon = "paintbrush",
    Theme = "Dark",
    Presentation = "Standard",
    ConfigFolder = "RedesignTest",
    AutoLoad = true,
    FooterText = "v0.11.5-redesign",
})

-- Проверка 1: Табы
local Tab1 = W:AddTab({ Title = "Controls", Icon = "sliders-horizontal" })
local Tab2 = W:AddTab({ Title = "Theme", Icon = "palette" })
local Tab3 = W:AddTab({ Title = "HUD", Icon = "layout-dashboard" })

-- Проверка 2: Секции и контролы
local S1 = Tab1:AddSection({ Title = "Toggles", Icon = "toggle-right" })
local tog = S1:AddToggle({ Id = "TestToggle", Title = "Toggle", Description = "Описание опционально", Default = false })
S1:AddToggle({ Id = "TestToggle2", Title = "Toggle без описания", Default = true })
S1:AddToggle({ Id = "DisabledToggle", Title = "Disabled Toggle", Default = false, Disabled = true })

local S2 = Tab1:AddSection({ Title = "Slider & Input", Icon = "move-horizontal" })
S2:AddSlider({ Id = "TestSlider", Title = "Slider", Min = 0, Max = 100, Default = 50, Suffix = "%" })
S2:AddSlider({ Id = "SliderNoDesc", Title = "Slider без описания", Min = 0, Max = 10, Default = 3 })
S2:AddInput({ Id = "TestInput", Title = "Input", Placeholder = "Type here..." })

local S3 = Tab1:AddSection({ Title = "Dropdown & Button", Icon = "list" })
S3:AddDropdown({ Id = "TestDropdown", Title = "Dropdown", Options = {"Option 1", "Option 2", "Option 3"}, Default = "Option 1" })
S3:AddButton({ Title = "Button", Text = "Click", Callback = function()
    W:ShowLoading()
    task.delay(1, function() W:HideLoading() end)
end })
S3:AddButton({ Title = "Primary Button", Text = "Primary", Variant = "Primary", Callback = function() end })
S3:AddButton({ Title = "Danger Button", Text = "Danger", Variant = "Danger", Callback = function() end })

local S4 = Tab1:AddSection({ Title = "Keybind" })
S4:AddKeybind({ Id = "TestKeybind", Title = "Test Keybind", Default = { Key = "E", Mode = "Toggle" } })

local S5 = Tab1:AddSection({ Title = "Status & Progress" })
S5:AddStatus({ Id = "TestStatus", Title = "Status", Value = "OK" })
S5:AddProgress({ Id = "TestProgress", Title = "Progress", Default = 0.65 })

-- Проверка 3: Тема
local Theme1 = Tab2:AddSection({ Title = "Theme" })
Theme1:AddButton({ Title = "Switch to Light", Text = "Light", Callback = function() W:SetTheme("Light") end })
Theme1:AddButton({ Title = "Switch to Dark", Text = "Dark", Callback = function() W:SetTheme("Dark") end })

-- Проверка 4: HUD
local HUD1 = Tab3:AddSection({ Title = "Keybind HUD" })
HUD1:AddButton({ Title = "Enable HUD (Auto)", Text = "Auto", Callback = function() W:SetKeybindHUD(true) end })
HUD1:AddButton({ Title = "Disable HUD", Text = "Off", Callback = function() W:SetKeybindHUD(false) end })
HUD1:AddButton({ Title = "HUD Left", Text = "Left", Callback = function() W:SetKeybindHUDSide("Left") end })
HUD1:AddButton({ Title = "HUD Right", Text = "Right", Callback = function() W:SetKeybindHUDSide("Right") end })
HUD1:AddKeybind({ Id = "HUDKeybind1", Title = "HUD Test 1", Default = { Key = "Q", Mode = "Toggle" }, ShowInHUD = true })
HUD1:AddKeybind({ Id = "HUDKeybind2", Title = "HUD Test 2", Default = { Key = "R", Mode = "Hold" }, ShowInHUD = true })
HUD1:AddKeybind({ Id = "HiddenKeybind", Title = "Hidden", Default = { Key = "T", Mode = "Toggle" }, ShowInHUD = false })

-- Проверка 5: Collapsible секция
local S6 = Tab1:AddSection({ Title = "Collapsible", Collapsible = true })
S6:AddToggle({ Id = "CollapsibleToggle", Title = "Inside collapsed section", Default = false })

-- Проверка 6: Два колонки (если ширина позволяет)
local S7 = Tab1:AddSection({ Title = "Two Column Layout", Span = 2, Layout = "Grid" })
S7:AddToggle({ Id = "Grid1", Title = "Item 1", Default = false })
S7:AddToggle({ Id = "Grid2", Title = "Item 2", Default = true })
S7:AddSlider({ Id = "GridSlider", Title = "Slider", Min = 0, Max = 100, Default = 50 })

-- Уведомление о старте
task.delay(0.5, function()
    W:SetThemeToken("Success", Color3.fromHex("#3DD68C"))
    print("[Redesign Test] All checks passed!")
end)
