--!nonstrict
local Create = require("@runtime/Create")
local Base = require("@controls/Base")
local Popover = require("@primitives/Popover")
local Sheet = require("@primitives/Sheet")
local Util = require("@runtime/Util")
local ColorPicker = setmetatable({}, { __index = Base })
ColorPicker.__index = ColorPicker

local HUE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
	ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
	ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
	ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
	ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
	ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
	ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
})

function ColorPicker.new(section, options)
	local self = setmetatable({}, ColorPicker)
	self.Alpha = options.Alpha == true
	self.Presets = options.Presets or {}
	self._popup = nil
	local d = options.Default or Color3.new(1, 1, 1)
	if self.Alpha then
		d = { Color = d, Alpha = math.clamp(options.DefaultAlpha or 1, 0, 1) }
	end
	Base.init(self, section, "ColorPicker", options, { Stateful = true, Default = d, Adaptive = true })
	return Base.finish(self)
end
function ColorPicker:_colour(v)
	return self.Alpha and (type(v) == "table" and v.Color or Color3.new(1, 1, 1)) or v
end
function ColorPicker:_mountValue(host)
	local w = self._window
	local t = w.Tokens
	self._button = Create.New("TextButton", {
		Size = UDim2.new(1, 0, 0, t:Get("FieldHeight")),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Parent = host,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, t:Get("FieldRadius")), Parent = self._button })
	self._triggerStroke = Create.New("UIStroke", { Thickness = 1, Transparency = 0.45, Parent = self._button })
	w:_bind(self._triggerStroke, { Color = "BorderSubtle" })
	w:_bind(self._button, { BackgroundColor3 = "ControlInset" })
	self._hexLabel = Create.New("TextLabel", {
		Size = UDim2.new(1, -44, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		Font = w.Fonts.Medium,
		TextSize = t:Get("FontSmall"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self._button,
	})
	w:_bind(self._hexLabel, { TextColor3 = "TextSecondary" })
	self._swatch = Create.New("Frame", {
		Size = UDim2.fromOffset(24, 18),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BorderSizePixel = 0,
		Parent = self._button,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, 6), Parent = self._swatch })
	Create.New("UIStroke", { Thickness = 1, Color = Color3.new(1, 1, 1), Transparency = 0.76, Parent = self._swatch })
	self._janitor:Add(self._button.MouseEnter:Connect(function()
		if not self._popup then
			self._button.BackgroundColor3 = w.Theme:Get("ControlHover")
		end
	end))
	self._janitor:Add(self._button.MouseLeave:Connect(function()
		if not self._popup then
			self._button.BackgroundColor3 = w.Theme:Get("ControlInset")
		end
	end))
	self._janitor:Add(self._button.MouseButton1Click:Connect(function()
		if not self:IsDisabled() then
			if self._popup then
				self:Close()
			else
				self:Open()
			end
		end
	end))
end
function ColorPicker:_render(v)
	local c = self:_colour(v)
	if typeof(c) ~= "Color3" then
		c = Color3.new(1, 1, 1)
	end
	if self._swatch then
		self._swatch.BackgroundColor3 = c
		self._hexLabel.Text = Util.toHex(c)
	end
	self:_syncPopup(c)
end
function ColorPicker:_syncPopup(c)
	if not self._sv then
		return
	end
	local h, s, v = c:ToHSV()
	self._h = h
	self._s = s
	self._v = v
	self._sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
	self._svCursor.Position = UDim2.fromScale(s, 1 - v)
	self._hueCursor.Position = UDim2.fromScale(h, 0.5)
	if self._hexBox and not self._hexBox:IsFocused() then
		self._hexBox.Text = Util.toHex(c)
	end
	if self._rgbBoxes then
		local vals = { math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255) }
		for i, b in self._rgbBoxes do
			if not b:IsFocused() then
				b.Text = tostring(vals[i])
			end
		end
	end
	if self._alphaBox and not self._alphaBox:IsFocused() then
		self._alphaBox.Text = tostring(math.round(self:GetAlpha() * 100)) .. "%"
	end
end
function ColorPicker:_fieldStroke(box)
	local w = self._window
	local s = Create.New("UIStroke", { Thickness = 1, Transparency = 0.55, Parent = box })
	w:_bind(s, { Color = "BorderSubtle" })
	box.Focused:Connect(function()
		s.Transparency = 0.10
		s.Color = w.Theme:Get("AccentBorder")
	end)
	box.FocusLost:Connect(function()
		s.Transparency = 0.55
		s.Color = w.Theme:Get("BorderSubtle")
	end)
end
function ColorPicker:_buildPopup(frame)
	local w = self._window
	local c = self:_colour(self:GetValue())
	local h, s, v = c:ToHSV()
	self._h = h
	self._s = s
	self._v = v
	local top = if w.Device.Layout == "Drawer" then 20 else 8
	local sv = Create.New("Frame", {
		Name = "SV",
		Size = UDim2.new(1, -16, 0, 94),
		Position = UDim2.fromOffset(8, top),
		BackgroundColor3 = Color3.fromHSV(h, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = frame,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, w.Tokens:Get("CornerSm")), Parent = sv })
	self._sv = sv
	local white = Create.New(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = sv }
	)
	Create.New("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		Parent = white,
	})
	local black = Create.New(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = sv }
	)
	Create.New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
		Parent = black,
	})
	self._svCursor = Create.New("Frame", {
		Size = UDim2.fromOffset(11, 11),
		Position = UDim2.fromScale(s, 1 - v),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = sv,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self._svCursor })
	Create.New("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), Parent = self._svCursor })
	local svHit = Create.New(
		"TextButton",
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5, Parent = sv }
	)
	local function setSV(pos)
		local x = math.clamp((pos.X - sv.AbsolutePosition.X) / math.max(1, sv.AbsoluteSize.X), 0, 1)
		local y = math.clamp((pos.Y - sv.AbsolutePosition.Y) / math.max(1, sv.AbsoluteSize.Y), 0, 1)
		self._s = x
		self._v = 1 - y
		self:_setColour(Color3.fromHSV(self._h, self._s, self._v))
	end
	svHit.InputBegan:Connect(function(i)
		if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		setSV(i.Position)
		w.Input:CapturePointer(self, i, function(move)
			setSV(move.Position)
		end, function() end)
	end)

	local hueY = top + 102
	local hue = Create.New("Frame", {
		Name = "Hue",
		Size = UDim2.new(1, -16, 0, 12),
		Position = UDim2.fromOffset(8, hueY),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Parent = frame,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = hue })
	Create.New("UIGradient", { Color = HUE, Parent = hue })
	self._hue = hue
	self._hueCursor = Create.New("Frame", {
		Size = UDim2.fromOffset(4, 18),
		Position = UDim2.fromScale(h, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = hue,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self._hueCursor })
	Create.New("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0.5, Parent = self._hueCursor })
	local hueHit = Create.New("TextButton", {
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 5,
		Parent = hue,
	})
	local function setHue(pos)
		self._h = math.clamp((pos.X - hue.AbsolutePosition.X) / math.max(1, hue.AbsoluteSize.X), 0, 1)
		self:_setColour(Color3.fromHSV(self._h, self._s, self._v))
	end
	hueHit.InputBegan:Connect(function(i)
		if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		setHue(i.Position)
		w.Input:CapturePointer(self, i, function(move)
			setHue(move.Position)
		end, function() end)
	end)

	local fieldsY = top + 126
	self._hexBox = Create.New("TextBox", {
		Size = UDim2.new(0.36, -5, 0, 28),
		Position = UDim2.fromOffset(8, fieldsY),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Text = Util.toHex(c),
		Font = w.Fonts.Regular,
		TextSize = w.Tokens:Get("FontSmall"),
		Parent = frame,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, w.Tokens:Get("CornerSm")), Parent = self._hexBox })
	w:_bind(self._hexBox, { BackgroundColor3 = "ControlInset", TextColor3 = "Text" })
	self:_fieldStroke(self._hexBox)
	local boxes = {}
	self._rgbBoxes = boxes
	for i in { 1, 2, 3 } do
		local box = Create.New("TextBox", {
			Size = UDim2.new(0.213, -4, 0, 28),
			Position = UDim2.new(0.36 + (i - 1) * 0.213, 4, 0, fieldsY),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Text = tostring(math.round(({ c.R, c.G, c.B })[i] * 255)),
			Font = w.Fonts.Regular,
			TextSize = w.Tokens:Get("FontSmall"),
			Parent = frame,
		})
		Create.New("UICorner", { CornerRadius = UDim.new(0, w.Tokens:Get("CornerSm")), Parent = box })
		w:_bind(box, { BackgroundColor3 = "ControlInset", TextColor3 = "Text" })
		self:_fieldStroke(box)
		boxes[i] = box
	end
	local function commitBoxes()
		local r = math.clamp(tonumber(boxes[1].Text) or 0, 0, 255)
		local g = math.clamp(tonumber(boxes[2].Text) or 0, 0, 255)
		local b = math.clamp(tonumber(boxes[3].Text) or 0, 0, 255)
		self:_setColour(Color3.fromRGB(r, g, b))
	end
	for _, box in boxes do
		box.FocusLost:Connect(commitBoxes)
	end
	self._hexBox.FocusLost:Connect(function()
		local raw = string.gsub(self._hexBox.Text, "#", "")
		local ok, new = pcall(Color3.fromHex, raw)
		if ok then
			self:_setColour(new)
		else
			self:_syncPopup(self:_colour(self:GetValue()))
		end
	end)

	local nextY = fieldsY + 36
	if self.Alpha then
		local alphaLabel = Create.New("TextLabel", {
			Size = UDim2.new(0.55, 0, 0, 28),
			Position = UDim2.fromOffset(8, nextY),
			BackgroundTransparency = 1,
			Text = "Alpha",
			Font = w.Fonts.Regular,
			TextSize = w.Tokens:Get("FontSmall"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		w:_bind(alphaLabel, { TextColor3 = "TextSecondary" })
		self._alphaBox = Create.New("TextBox", {
			Size = UDim2.new(0.35, -8, 0, 28),
			Position = UDim2.new(0.65, 0, 0, nextY),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Text = tostring(math.round(self:GetAlpha() * 100)) .. "%",
			Font = w.Fonts.Regular,
			TextSize = w.Tokens:Get("FontSmall"),
			Parent = frame,
		})
		Create.New("UICorner", { CornerRadius = UDim.new(0, w.Tokens:Get("CornerSm")), Parent = self._alphaBox })
		w:_bind(self._alphaBox, { BackgroundColor3 = "ControlInset", TextColor3 = "Text" })
		self:_fieldStroke(self._alphaBox)
		self._alphaBox.FocusLost:Connect(function()
			local n = tonumber(string.gsub(self._alphaBox.Text, "%%", ""))
			if n then
				self:SetAlpha(math.clamp(n / 100, 0, 1))
			else
				self:_syncPopup(self:_colour(self:GetValue()))
			end
		end)
		nextY += 34
	end
	if #self.Presets > 0 then
		local row = Create.New("Frame", {
			Size = UDim2.new(1, -16, 0, 24),
			Position = UDim2.fromOffset(8, nextY),
			BackgroundTransparency = 1,
			Parent = frame,
		})
		Create.List(6, Enum.FillDirection.Horizontal).Parent = row
		for _, p in self.Presets do
			if typeof(p) == "Color3" then
				local b = Create.New("TextButton", {
					Size = UDim2.fromOffset(24, 24),
					BackgroundColor3 = p,
					Text = "",
					BorderSizePixel = 0,
					Parent = row,
				})
				Create.New("UICorner", { CornerRadius = UDim.new(0, 6), Parent = b })
				Create.New("UIStroke", { Thickness = 1, Color = Color3.new(1, 1, 1), Transparency = 0.78, Parent = b })
				b.MouseButton1Click:Connect(function()
					self:_setColour(p)
				end)
			end
		end
	end
	self:_syncPopup(c)
end
function ColorPicker:_clearPopupRefs()
	self._sv = nil
	self._hue = nil
	self._svCursor = nil
	self._hueCursor = nil
	self._hexBox = nil
	self._rgbBoxes = nil
	self._alphaBox = nil
end
function ColorPicker:_setColour(c)
	if self.Alpha then
		local v = table.clone(self:GetValue() or {})
		v.Color = c
		v.Alpha = v.Alpha or 1
		self:SetValue(v)
	else
		self:SetValue(c)
	end
end
function ColorPicker:_popupHeight()
	local base = 178
	if self.Alpha then
		base += 34
	end
	if #self.Presets > 0 then
		base += 32
	end
	if self._window.Device.Layout == "Drawer" then
		base += 12
	end
	return base
end
function ColorPicker:Open()
	if self._window.Sound then
		self._window.Sound:Play("Open")
	end
	if self._popup then
		return self
	end
	local height = self:_popupHeight()
	local h
	local function dismissed()
		self._popup = nil
		self:_clearPopupRefs()
		self._window.Input:CancelCapture(self)
	end
	if self._window.Device.Layout == "Drawer" then
		h = Sheet.open(self._window, height, { OnDismiss = dismissed })
	else
		h = Popover.open(self._window, self._button, Vector2.new(248, height), { OnDismiss = dismissed, Corner = 8 })
	end
	self._popup = h
	self:_buildPopup(h.Frame)
	return self
end
function ColorPicker:Close()
	if self._popup then
		local h = self._popup
		self._popup = nil
		self._window.Input:CancelCapture(self)
		self:_clearPopupRefs()
		h:Dismiss()
	end
	return self
end
function ColorPicker:SetAlpha(a)
	if not self.Alpha then
		return self
	end
	local v = table.clone(self:GetValue() or {})
	v.Alpha = math.clamp(tonumber(a) or 1, 0, 1)
	return self:SetValue(v)
end
function ColorPicker:GetAlpha()
	local v = self:GetValue()
	return self.Alpha and type(v) == "table" and tonumber(v.Alpha) or 1
end
function ColorPicker:Destroy()
	self:Close()
	Base.Destroy(self)
end
function ColorPicker:_applyValueTokens()
	if self._button then
		self._button.Size = UDim2.new(1, 0, 0, self._window.Tokens:Get("FieldHeight"))
		self._hexLabel.TextSize = self._window.Tokens:Get("FontSmall")
	end
end
return ColorPicker
