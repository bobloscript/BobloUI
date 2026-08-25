--!nonstrict
local TweenService = game:GetService("TweenService")
local Create = require("@runtime/Create")
local Spinner = {}
function Spinner.new(window, parent, size)
	local label = Create.New("TextLabel", {
		Size = UDim2.fromOffset(size or 16, size or 16),
		BackgroundTransparency = 1,
		Text = window.Motion and not window.Motion.Enabled and "…" or "◌",
		Font = window.Fonts.Bold,
		TextSize = size or 16,
		Parent = parent,
	})
	window:_bind(label, { TextColor3 = "Text" })
	if not window.Motion or window.Motion.Enabled then
		local tween = TweenService:Create(
			label,
			TweenInfo.new(0.8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
			{ Rotation = 360 }
		)
		tween:Play()
		label.Destroying:Once(function()
			pcall(function()
				tween:Cancel()
			end)
		end)
	end
	return label
end
return Spinner
