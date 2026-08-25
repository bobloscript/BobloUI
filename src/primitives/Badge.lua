--!nonstrict
local Create = require("@runtime/Create")
local Badge = {}
local BG = { Neutral = "SurfaceSecondary", Info = "Info", Success = "Success", Warning = "Warning", Danger = "Error" }
local FG = {
	Neutral = "TextSecondary",
	Info = "TextOnInfo",
	Success = "TextOnSuccess",
	Warning = "TextOnWarning",
	Danger = "TextOnError",
}
function Badge.new(window, text, style, parent)
	style = style or "Neutral"
	local label = Create.New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 0,
		Text = string.upper(text or ""),
		Font = window.Fonts.Bold,
		TextSize = window.Tokens:Get("FontCaption"),
		Parent = parent,
	})
	Create.New("UIPadding", {
		PaddingLeft = UDim.new(0, 7),
		PaddingRight = UDim.new(0, 7),
		PaddingTop = UDim.new(0, 3),
		PaddingBottom = UDim.new(0, 3),
		Parent = label,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = label })
	window:_bind(label, { BackgroundColor3 = BG[style] or BG.Neutral, TextColor3 = FG[style] or FG.Neutral })
	return label
end
return Badge
