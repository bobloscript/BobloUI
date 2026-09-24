-- Manual drag regression test for an executor or Roblox Studio.
local BobloUI =
	loadstring(game:HttpGet("https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.min.lua"))()

local UI = BobloUI:CreateWindow({
	Id = "drag-stability-smoke",
	Title = "Drag Stability Test",
	Subtitle = "Move the window quickly and repeatedly",
	Size = UDim2.fromOffset(680, 460),
	FooterText = "Mouse: fast circles · Touch: drag with one finger while tapping with another",
	WindowAnimation = {
		Style = "Slide",
		Duration = 0.3,
		Offset = 28,
	},
})

local Main = UI:AddTab({
	Id = "drag-test",
	Title = "Drag test",
	Icon = "move",
})

local Instructions = Main:AddSection({
	Title = "Instructions",
	Description = "The window must remain under the pointer without jumping or leaving the screen.",
})

Instructions:AddParagraph({
	Content = "Drag immediately after showing the window. On touch, keep dragging the header with one finger and tap elsewhere with a second finger.",
	Variant = "Info",
})

local Controls = Main:AddSection({
	Title = "Dummy controls",
	Description = "These controls only make the window resemble a real script hub.",
})

Controls:AddToggle({
	Id = "DragTestAutoFarm",
	Title = "Auto Farm",
	Default = false,
})

Controls:AddSlider({
	Id = "DragTestSpeed",
	Title = "Movement Speed",
	Min = 1,
	Max = 100,
	Default = 25,
})

Controls:AddDropdown({
	Id = "DragTestMethod",
	Title = "Farm Method",
	Options = { "Nearest", "Strongest", "Selected" },
	Default = "Nearest",
})

Controls:AddInput({
	Id = "DragTestNote",
	Title = "Test Note",
	Default = "Drag remains stable",
})

local Scale = Main:AddSection({
	Title = "Scale checks",
	Description = "Repeat the drag test after every scale change.",
})

for _, value in { 0.75, 1, 1.25 } do
	Scale:AddButton({
		Title = `Set scale to {value}`,
		Text = tostring(value),
		Callback = function()
			UI:SetScale(value)
		end,
	})
end

Scale:AddButton({
	Title = "Reset window geometry",
	Text = "Reset",
	Callback = function()
		UI:ResetGeometry()
	end,
})

Scale:AddButton({
	Title = "Replay show animation",
	Text = "Hide and show",
	Callback = function()
		UI:Hide()
		task.delay(0.45, function()
			if UI and not UI._destroying then
				UI:Show()
			end
		end)
	end,
})

print("[BobloUI] Drag stability smoke loaded")
