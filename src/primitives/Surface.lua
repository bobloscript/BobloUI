--!nonstrict
local Create = require("@runtime/Create")
local Surface = {}
function Surface.new(window, props, options)
	props = props or {}
	options = options or {}
	local frame = Create.New(options.ClassName or "Frame", props)
	if options.Corner ~= false then
		Create.New(
			"UICorner",
			{ CornerRadius = UDim.new(0, options.Corner or window.Tokens:Get("CornerMd")), Parent = frame }
		)
	end
	if options.Stroke ~= false then
		local stroke = Create.New("UIStroke", {
			Thickness = options.StrokeThickness or window.Tokens:Get("Stroke"),
			Transparency = if options.StrokeTransparency == nil then 0.18 else options.StrokeTransparency,
			LineJoinMode = Enum.LineJoinMode.Round,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = frame,
		})
		window:_bind(stroke, { Color = options.StrokeToken or "BorderSubtle" })
	end
	window:_bind(frame, { BackgroundColor3 = options.Token or "Surface" })
	if options.Sheen then
		local sheen = Create.New("Frame", {
			Name = "InnerSheen",
			Size = UDim2.new(1, -4, 0, 1),
			Position = UDim2.fromOffset(2, 1),
			BackgroundTransparency = options.SheenTransparency or 0.38,
			BorderSizePixel = 0,
			ZIndex = (props.ZIndex or 1) + 1,
			Parent = frame,
		})
		window:_bind(sheen, { BackgroundColor3 = "SurfaceSheen" })
	end
	return frame
end
return Surface
