--!nonstrict
local Create = require("@runtime/Create")
local Base = require("@controls/Base")
local Icon = require("@primitives/Icon")
local Slider = setmetatable({}, { __index = Base })
Slider.__index = Slider
function Slider.new(section, options)
	if type(options.Min) ~= "number" or type(options.Max) ~= "number" then
		error("[BobloUI] AddSlider requires Min and Max numbers.", 3)
	end
	local self = setmetatable({}, Slider)
	self.Min = options.Min
	self.Max = options.Max
	self.Step = options.Step or 1
	self.Precision = if options.Precision ~= nil then options.Precision else options.Rounding
	self.Prefix = options.Prefix or ""
	self.Suffix = options.Suffix or ""
	self.Format = options.Format or options.FormatDisplayValue
	self.ValueInput = options.ValueInput ~= false
	self.AllowRightClickInput = options.AllowRightClickInput == true
	self.FloatingValue = options.FloatingValue == true
	self.Compact = options.Compact == true
	-- Keep the historic BobloUI display unless HideMax is explicitly false.
	self.HideMax = options.HideMax ~= false
	self.IconFrom = options.IconFrom
	self.IconTo = options.IconTo
	local d = options.Default
	if d == nil then
		d = self.Min
	end
	d = math.clamp(d, self.Min, self.Max)
	Base.init(self, section, "Slider", options, {
		Stateful = true,
		Default = d,
		Layout = if self.Compact then nil else "Stacked",
	})
	return Base.finish(self)
end
function Slider:_format(v)
	if self.Format then
		return tostring(self.Format(v))
	end
	local value
	if self.Precision then
		value = string.format("%." .. self.Precision .. "f", v)
	else
		value = tostring(v)
	end
	local maximum = if self.Precision
		then string.format("%." .. self.Precision .. "f", self.Max)
		else tostring(self.Max)
	local range = if self.HideMax then value else `{value} / {maximum}`
	return self.Prefix .. range .. self.Suffix
end
function Slider:_normalize(v)
	v = tonumber(v) or self.Min
	v = math.clamp(v, self.Min, self.Max)
	v = math.round((v - self.Min) / self.Step) * self.Step + self.Min
	return math.clamp(v, self.Min, self.Max)
end
function Slider:_parseInput(text)
	text = tostring(text or "")
	if self.Prefix ~= "" and string.sub(text, 1, #self.Prefix) == self.Prefix then
		text = string.sub(text, #self.Prefix + 1)
	end
	if self.Suffix ~= "" and string.sub(text, -#self.Suffix) == self.Suffix then
		text = string.sub(text, 1, #text - #self.Suffix)
	end
	text = string.match(text, "^%s*([^/]+)") or text
	return tonumber(string.match(text, "^%s*(.-)%s*$"))
end
function Slider:SetValue(v, silent)
	return Base.SetValue(self, self:_normalize(v), silent)
end
function Slider:_mountValue(host)
	local w = self._window
	local t = w.Tokens
	self._valueBox = Create.New("TextBox", {
		Size = UDim2.fromOffset(if self.Compact then 92 else 72, 24),
		Position = if self.Compact
			then UDim2.new(1, 0, 0, 0)
			else UDim2.new(1, 0, 0, -t:Get("ControlHeight") + (self.Description and -5 or 2)),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Text = self:_format(self:GetValue()),
		TextEditable = self.ValueInput,
		Font = w.Fonts.Medium,
		TextSize = t:Get("FontSmall"),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = host,
	})
	w:_bind(self._valueBox, { TextColor3 = "TextSecondary" })
	local leftInset = if self.IconFrom then 20 else 2
	local rightInset = if self.IconTo then 20 else 2
	if self.IconFrom then
		self._fromIcon = Icon.new(w, self.IconFrom, {
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.new(0, 0, 0.5, 5),
			AnchorPoint = Vector2.new(0, 0.5),
			Parent = host,
		})
		Icon.setColor(self._fromIcon, w.Theme:Get("TextTertiary"))
	end
	if self.IconTo then
		self._toIcon = Icon.new(w, self.IconTo, {
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.new(1, 0, 0.5, 5),
			AnchorPoint = Vector2.new(1, 0.5),
			Parent = host,
		})
		Icon.setColor(self._toIcon, w.Theme:Get("TextTertiary"))
	end
	self._track = Create.New("Frame", {
		Size = UDim2.new(1, -leftInset - rightInset, 0, t:Get("SliderTrack")),
		Position = UDim2.new(0, leftInset, 0.5, 5),
		AnchorPoint = Vector2.new(0, 0.5),
		BorderSizePixel = 0,
		Parent = host,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self._track })
	local trackStroke = Create.New("UIStroke", { Thickness = 1, Transparency = 0.76, Parent = self._track })
	w:_bind(trackStroke, { Color = "BorderSubtle" })
	w:_bind(self._track, { BackgroundColor3 = "SurfaceInset" })
	self._fill = Create.New("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, Parent = self._track })
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self._fill })
	w:_bind(self._fill, { BackgroundColor3 = "Accent" })
	self._knob = Create.New("Frame", {
		Size = UDim2.fromOffset(t:Get("SliderKnob"), t:Get("SliderKnob")),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = self._track,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self._knob })
	Create.New("UIStroke", { Thickness = 1, Color = Color3.new(1, 1, 1), Transparency = 0.42, Parent = self._knob })
	w:_bind(self._knob, { BackgroundColor3 = "Accent" })
	if self.FloatingValue then
		self._bubble = Create.New("TextLabel", {
			Size = UDim2.fromOffset(64, 24),
			Position = UDim2.new(0, 0, 0.5, -18),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Visible = false,
			Font = w.Fonts.Medium,
			TextSize = t:Get("FontCaption"),
			ZIndex = 6,
			Parent = self._track,
		})
		Create.New("UICorner", { CornerRadius = UDim.new(0, 6), Parent = self._bubble })
		local bubbleStroke = Create.New("UIStroke", {
			Thickness = 1,
			Transparency = 0.38,
			LineJoinMode = Enum.LineJoinMode.Round,
			Parent = self._bubble,
		})
		w:_bind(self._bubble, { BackgroundColor3 = "SurfaceRaised", TextColor3 = "Text" })
		w:_bind(bubbleStroke, { Color = "Border" })
	end
	local hit = Create.New("TextButton", {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 4,
		Parent = self._track,
	})
	self._janitor:Add(hit.InputBegan:Connect(function(i)
		if self:IsDisabled() then
			return
		end
		if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local page = self._section._tab._page
		local oldScroll = page and page.ScrollingEnabled
		if i.UserInputType == Enum.UserInputType.Touch and page then
			page.ScrollingEnabled = false
		end
		if self._bubble then
			self._bubble.Visible = true
		end
		local function at(pos)
			local a = (pos.X - self._track.AbsolutePosition.X) / math.max(1, self._track.AbsoluteSize.X)
			self:SetValue(self.Min + math.clamp(a, 0, 1) * (self.Max - self.Min))
		end
		at(i.Position)
		w.Input:CapturePointer(self, i, function(m)
			at(m.Position)
		end, function()
			if page and oldScroll ~= nil then
				page.ScrollingEnabled = oldScroll
			end
			if self._bubble then
				self._bubble.Visible = false
			end
		end)
	end))
	if self.ValueInput or self.AllowRightClickInput then
		self._janitor:Add(self._valueBox.FocusLost:Connect(function()
			local parsed = self:_parseInput(self._valueBox.Text)
			if parsed == nil then
				self:_render(self:GetValue())
			else
				self:SetValue(parsed)
			end
			if not self.ValueInput then
				self._valueBox.TextEditable = false
			end
		end))
	end
	if self.AllowRightClickInput then
		self._janitor:Add(self._valueBox.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton2 or self:IsDisabled() then
				return
			end
			self._valueBox.TextEditable = true
			self._valueBox:CaptureFocus()
			self._valueBox.CursorPosition = #self._valueBox.Text + 1
		end))
	end
end
function Slider:_applyDisabled()
	Base._applyDisabled(self)
	if self._valueBox then
		self._valueBox.TextEditable = not self._disabled and self.ValueInput
	end
end
function Slider:_render(v)
	if not self._fill then
		return
	end
	local a = math.clamp((v - self.Min) / math.max(0.000001, self.Max - self.Min), 0, 1)
	self._fill.Size = UDim2.fromScale(a, 1)
	self._knob.Position = UDim2.fromScale(a, 0.5)
	if self._bubble then
		self._bubble.Position = UDim2.new(a, 0, 0.5, -18)
		self._bubble.Text = self:_format(v)
	end
	if not self._valueBox:IsFocused() then
		self._valueBox.Text = self:_format(v)
	end
end
function Slider:_applyValueTokens()
	if self._track then
		local leftInset = if self.IconFrom then 20 else 2
		local rightInset = if self.IconTo then 20 else 2
		self._track.Size = UDim2.new(1, -leftInset - rightInset, 0, self._window.Tokens:Get("SliderTrack"))
		local n = self._window.Tokens:Get("SliderKnob")
		self._knob.Size = UDim2.fromOffset(n, n)
		self._valueBox.TextSize = self._window.Tokens:Get("FontSmall")
	end
end
function Slider:SetMin(v)
	self.Min = v
	if self.Max < self.Min then
		self.Max = self.Min
	end
	self:SetValue(self:GetValue(), true)
	return self
end
function Slider:SetMax(v)
	self.Max = v
	if self.Min > self.Max then
		self.Min = self.Max
	end
	self:SetValue(self:GetValue(), true)
	return self
end
function Slider:SetStep(v)
	self.Step = math.max(0.000001, v)
	self:SetValue(self:GetValue(), true)
	return self
end
function Slider:SetPrefix(value)
	self.Prefix = tostring(value or "")
	self:_render(self:GetValue())
	return self
end
function Slider:SetSuffix(value)
	self.Suffix = tostring(value or "")
	self:_render(self:GetValue())
	return self
end
return Slider
