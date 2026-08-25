--!nonstrict
local Create = require("@runtime/Create")
local Base = require("@controls/Base")
local Progress = setmetatable({}, { __index = Base })
Progress.__index = Progress

function Progress.new(section, options)
	options = options or {}
	local self = setmetatable({}, Progress)
	self.Min = tonumber(options.Min) or 0
	self.Max = tonumber(options.Max) or 100
	if self.Max <= self.Min then
		self.Max = self.Min + 1
	end
	self.Suffix = options.Suffix or "%"
	self.Format = options.Format
	self.ShowValue = options.ShowValue ~= false
	self.Indeterminate = options.Indeterminate == true
	local d = tonumber(options.Default)
	if d == nil then
		d = self.Min
	end
	d = math.clamp(d, self.Min, self.Max)
	Base.init(self, section, "Progress", options, { Stateful = true, Default = d, Layout = "Stacked" })
	return Base.finish(self)
end
function Progress:_format(v)
	if self.Format then
		return self.Format(v)
	end
	return tostring(math.floor(v * 100 + 0.5) / 100) .. self.Suffix
end
function Progress:SetValue(v, silent)
	v = math.clamp(tonumber(v) or self.Min, self.Min, self.Max)
	return Base.SetValue(self, v, silent)
end
function Progress:_mountValue(host)
	local w = self._window
	local t = w.Tokens
	self._valueLabel = Create.New("TextLabel", {
		Size = UDim2.fromOffset(84, 18),
		Position = UDim2.new(1, 0, 0, -t:Get("ControlHeight") + 2),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Font = w.Fonts.Medium,
		TextSize = t:Get("FontSmall"),
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = self.ShowValue,
		Parent = host,
	})
	w:_bind(self._valueLabel, { TextColor3 = "TextSecondary" })
	self._track = Create.New("Frame", {
		Size = UDim2.new(1, -4, 0, 6),
		Position = UDim2.new(0, 2, 0.5, 5),
		AnchorPoint = Vector2.new(0, 0.5),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = host,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self._track })
	w:_bind(self._track, { BackgroundColor3 = "SurfaceInset" })
	self._fill = Create.New("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, Parent = self._track })
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self._fill })
	w:_bind(self._fill, { BackgroundColor3 = "Accent" })
	self:_render(self:GetValue())
	if self.Indeterminate then
		self:_startIndeterminate()
	end
end
function Progress:_startIndeterminate()
	if self._indeterminateTask then
		return
	end
	self._indeterminateTask = task.spawn(function()
		while not self._destroyed and self.Indeterminate do
			if self._fill then
				self._fill.Size = UDim2.fromScale(0.28, 1)
				self._fill.Position = UDim2.fromScale(-0.28, 0)
				local tween = self._window.Motion:Tween(
					self._fill,
					TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
					{ Position = UDim2.fromScale(1, 0) }
				)
				if tween then
					tween.Completed:Wait()
				else
					task.wait(0.8)
				end
			else
				task.wait(0.1)
			end
		end
		self._indeterminateTask = nil
	end)
	self._janitor:Add(self._indeterminateTask, nil, "indeterminate")
end
function Progress:SetIndeterminate(v)
	self.Indeterminate = v == true
	if self.Indeterminate then
		self:_startIndeterminate()
	else
		self._janitor:Remove("indeterminate")
		self._indeterminateTask = nil
		self:_render(self:GetValue())
	end
	return self
end
function Progress:_render(v)
	if self._valueLabel then
		self._valueLabel.Text = self:_format(v)
	end
	if self._fill and not self.Indeterminate then
		local a = math.clamp((v - self.Min) / (self.Max - self.Min), 0, 1)
		self._fill.Position = UDim2.new()
		self._fill.Size = UDim2.fromScale(a, 1)
	end
end
function Progress:_applyValueTokens()
	if self._valueLabel then
		self._valueLabel.TextSize = self._window.Tokens:Get("FontSmall")
	end
end
return Progress
