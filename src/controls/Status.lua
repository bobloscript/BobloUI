--!nonstrict
local Create = require("@runtime/Create")
local Base = require("@controls/Base")
local Status = setmetatable({}, { __index = Base })
Status.__index = Status
local TOKENS = {
	Neutral = "TextSecondary",
	Success = "Success",
	Warning = "Warning",
	Error = "Error",
	Info = "Info",
	Pending = "Warning",
}
function Status.new(section, options)
	local self = setmetatable({}, Status)
	self.Status = options.Status or "Neutral"
	self.Pulse = options.Pulse == true
	Base.init(
		self,
		section,
		"Status",
		options,
		{ Stateful = options.Id ~= nil, Default = options.Value, Persist = false, Adaptive = true }
	)
	if not options.Id then
		self._value = options.Value
	end
	return Base.finish(self)
end
function Status:_mountValue(host)
	local w = self._window
	self._statusWrap = Create.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Parent = host,
	})
	local layout = Create.New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		Parent = self._statusWrap,
	})
	self._dot = Create.New(
		"Frame",
		{ Size = UDim2.fromOffset(7, 7), BorderSizePixel = 0, LayoutOrder = 1, Parent = self._statusWrap }
	)
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self._dot })
	w:_bind(self._dot, {
		BackgroundColor3 = function(palette)
			return palette[TOKENS[self.Status] or "TextSecondary"]
		end,
	})
	self._valueLabel = Create.New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundTransparency = 1,
		Font = w.Fonts.Medium,
		TextSize = w.Tokens:Get("FontSmall"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		LayoutOrder = 2,
		Parent = self._statusWrap,
	})
	w:_bind(self._valueLabel, { TextColor3 = "TextSecondary" })
	self:SetStatus(self.Status)
	if self.Pulse and w.Motion:IsEnabled("Controls") then
		local tw = w.Motion:Tween(
			self._dot,
			TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ BackgroundTransparency = 0.65 }
		)
		if tw then
			self._janitor:Add(tw)
		end
	end
end
function Status:_render(v)
	if self._valueLabel then
		self._valueLabel.Text = tostring(v or "")
	end
end
function Status:SetStatus(s)
	self.Status = s
	if self._dot then
		self._dot.BackgroundColor3 = self._window.Theme:Get(TOKENS[s] or "TextSecondary")
	end
	return self
end
function Status:_applyValueTokens()
	if self._valueLabel then
		self._valueLabel.TextSize = self._window.Tokens:Get("FontSmall")
	end
end
return Status
