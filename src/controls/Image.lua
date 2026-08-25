--!nonstrict
local Create = require("@runtime/Create")
local Base = require("@controls/Base")
local Image = setmetatable({}, { __index = Base })
Image.__index = Image
function Image.new(section, options)
	options = options or {}
	local self = setmetatable({}, Image)
	self.Image = options.Image or ""
	self.Height = math.max(64, tonumber(options.Height) or 160)
	self.ScaleType = options.ScaleType or Enum.ScaleType.Fit
	self.Caption = options.Caption
	self.Tint = options.Tint or options.ImageColor3 or Color3.new(1, 1, 1)
	self.Transparency = math.clamp(tonumber(options.Transparency or options.ImageTransparency) or 0, 0, 1)
	self.BackgroundTransparency = math.clamp(tonumber(options.BackgroundTransparency) or 0, 0, 1)
	self.RectOffset = options.RectOffset or options.ImageRectOffset or Vector2.new()
	self.RectSize = options.RectSize or options.ImageRectSize or Vector2.new()
	Base.init(self, section, "Image", options, { Stateful = false, Default = nil, Layout = "Stacked" })
	return Base.finish(self)
end
function Image:_measure()
	local t = self._window.Tokens
	return t:Get("ControlHeight") + self.Height + (self.Caption and 28 or 10) + (self.Description and 12 or 0)
end
function Image:_mountValue(host)
	local w = self._window
	local t = w.Tokens
	self._image = Create.New("ImageLabel", {
		Size = UDim2.new(1, 0, 0, self.Height),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Image = self.Image,
		ScaleType = self.ScaleType,
		ImageColor3 = self.Tint,
		ImageTransparency = self.Transparency,
		BackgroundTransparency = self.BackgroundTransparency,
		ImageRectOffset = self.RectOffset,
		ImageRectSize = self.RectSize,
		Parent = host,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, t:Get("FieldRadius")), Parent = self._image })
	local s = Create.New("UIStroke", { Thickness = 1, Transparency = 0.58, Parent = self._image })
	w:_bind(s, { Color = "BorderSubtle" })
	w:_bind(self._image, { BackgroundColor3 = "ControlInset" })
	self._caption = Create.New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, self.Height + 6),
		BackgroundTransparency = 1,
		Text = tostring(self.Caption or ""),
		Visible = self.Caption ~= nil,
		Font = w.Fonts.Regular,
		TextSize = t:Get("FontSmall"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = host,
	})
	w:_bind(self._caption, { TextColor3 = "TextTertiary" })
end
function Image:_applyValueTokens()
	if self._valueHost then
		self._valueHost.Size =
			UDim2.new(1, -self._window.Tokens:Get("ControlPadding") * 2, 0, self.Height + (self.Caption and 26 or 0))
	end
	if self._image then
		self._image.Size = UDim2.new(1, 0, 0, self.Height)
	end
	if self._caption then
		self._caption.Position = UDim2.fromOffset(0, self.Height + 6)
	end
end
function Image:SetImage(value)
	self.Image = value or ""
	if self._image then
		self._image.Image = self.Image
	end
	return self
end
function Image:SetCaption(value)
	self.Caption = value
	if self._caption then
		self._caption.Text = tostring(value or "")
		self._caption.Visible = value ~= nil
	end
	if self._mounted then
		self:_applyTokens()
	end
	return self
end
function Image:SetHeight(value)
	self.Height = math.max(64, tonumber(value) or self.Height)
	if self._mounted then
		self:_applyTokens()
	end
	return self
end
function Image:SetTint(value)
	if typeof(value) ~= "Color3" then
		error("[BobloUI] Image:SetTint expects Color3.", 2)
	end
	self.Tint = value
	if self._image then
		self._image.ImageColor3 = value
	end
	return self
end
function Image:SetTransparency(value, background)
	self.Transparency = math.clamp(tonumber(value) or self.Transparency, 0, 1)
	if background ~= nil then
		self.BackgroundTransparency = math.clamp(tonumber(background) or self.BackgroundTransparency, 0, 1)
	end
	if self._image then
		self._image.ImageTransparency = self.Transparency
		self._image.BackgroundTransparency = self.BackgroundTransparency
	end
	return self
end
function Image:SetRect(offset, size)
	if typeof(offset) ~= "Vector2" or typeof(size) ~= "Vector2" then
		error("[BobloUI] Image:SetRect expects Vector2 offset and size.", 2)
	end
	self.RectOffset = offset
	self.RectSize = size
	if self._image then
		self._image.ImageRectOffset = offset
		self._image.ImageRectSize = size
	end
	return self
end
function Image:SetScaleType(scaleType)
	self.ScaleType = scaleType or Enum.ScaleType.Fit
	if self._image then
		self._image.ScaleType = self.ScaleType
	end
	return self
end
return Image
