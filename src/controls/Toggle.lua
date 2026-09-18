--!nonstrict
local Create = require("@runtime/Create")
local Base = require("@controls/Base")
local Icon = require("@primitives/Icon")
local Toggle = setmetatable({}, { __index = Base })
Toggle.__index = Toggle
function Toggle:AddKeybind(options)
	options = table.clone(options or {})
	options.AttachTo = self
	if options.SyncToggle == nil then
		options.SyncToggle = true
	end
	return require("@controls/Keybind").new(self._section, options)
end
function Toggle.new(section, options)
	local self = setmetatable({}, Toggle)
	self.Style = options.Style or (if section._window._minimal then "Checkbox" else "Switch")
	Base.init(self, section, "Toggle", options, { Stateful = true, Default = options.Default == true })
	return Base.finish(self)
end
function Toggle:_mountValue(host)
	local w = self._window
	local t = w.Tokens
	local checkbox = self.Style == "Checkbox"
	self._button = Create.New("TextButton", {
		Size = if checkbox then UDim2.fromOffset(20, 20) else UDim2.fromOffset(34, 18),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Parent = host,
	})
	Create.New(
		"UICorner",
		{ CornerRadius = if checkbox then UDim.new(0, 5) else UDim.new(1, 0), Parent = self._button }
	)
	self._stroke = Create.New("UIStroke", { Thickness = 1, Transparency = 0.45, Parent = self._button })
	w:_bind(self._stroke, { Color = "BorderStrong" })
	w:_bind(self._button, { BackgroundColor3 = "SurfaceInset" })
	if checkbox then
		self._check = Icon.new(w, "check", {
			Size = UDim2.fromOffset(12, 12),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Visible = false,
			Parent = self._button,
		})
		Icon.setColor(self._check, w.Theme:Get("TextOnAccent"))
	else
		self._knob = Create.New("Frame", {
			Size = UDim2.fromOffset(12, 12),
			Position = UDim2.new(0, 3, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BorderSizePixel = 0,
			Parent = self._button,
		})
		Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self._knob })
		w:_bind(self._knob, { BackgroundColor3 = "TextTertiary" })
	end
	self._janitor:Add(self._button.MouseButton1Click:Connect(function()
		if not self:IsDisabled() then
			self:Flip()
		end
	end))
	if w._minimal then
		self._root.Active = true
		self._janitor:Add(self._root.InputBegan:Connect(function(input)
			if self:IsDisabled() or (
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			) then
				return
			end
			local point = input.Position
			local buttonPos, buttonSize = self._button.AbsolutePosition, self._button.AbsoluteSize
			if point.X >= buttonPos.X and point.X <= buttonPos.X + buttonSize.X
				and point.Y >= buttonPos.Y and point.Y <= buttonPos.Y + buttonSize.Y then
				return
			end
			self:Flip()
		end))
	end
end
function Toggle:_render(value)
	if not self._button then
		return
	end
	local on = value == true
	local w = self._window
	self._button.BackgroundColor3 = w.Theme:Get(if on then "Accent" else "SurfaceInset")
	self._stroke.Color = w.Theme:Get(if on then "AccentBorder" else "BorderSubtle")
	self._stroke.Transparency = if on then 0.2 else 0.45
	if self.Style == "Checkbox" then
		if self._check then
			self._check.Visible = on
		end
	elseif self._knob then
		self._knob.BackgroundColor3 = w.Theme:Get(if on then "TextOnAccent" else "TextSecondary")
		w.Motion:Tween(
			self._knob,
			"Fast",
			{ Position = if on then UDim2.new(1, -15, 0.5, 0) else UDim2.new(0, 3, 0.5, 0) }
		)
	end
end
function Toggle:Flip()
	if self._window.Sound then
		self._window.Sound:Play("Toggle")
	end
	return self:SetValue(not self:GetValue())
end
return Toggle
