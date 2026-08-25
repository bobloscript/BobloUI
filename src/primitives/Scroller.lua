--!nonstrict
local Create = require("@runtime/Create")
local Scroller = {}
function Scroller.new(window, props)
	props = props or {}
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	props.CanvasSize = props.CanvasSize or UDim2.new()
	props.AutomaticCanvasSize = props.AutomaticCanvasSize or Enum.AutomaticSize.Y
	props.ScrollingDirection = props.ScrollingDirection or Enum.ScrollingDirection.Y
	props.ScrollBarThickness = props.ScrollBarThickness or 4
	local frame = Create.New("ScrollingFrame", props)
	window:_bind(frame, { ScrollBarImageColor3 = "BorderStrong" })
	return frame
end
return Scroller
