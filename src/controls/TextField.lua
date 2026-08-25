--!nonstrict
local Create = require("@runtime/Create")
local Base = require("@controls/Base")
local TextField = setmetatable({}, { __index = Base })
TextField.__index = TextField
function TextField.new(section, options)
	local self = setmetatable({}, TextField)
	local default = options.Default
	if default == nil then
		default = if options.Numeric == true then 0 else ""
	end
	self.Placeholder = options.Placeholder or ""
	self.Numeric = options.Numeric == true
	self.MaxLength = options.MaxLength
	self.Multiline = options.Multiline == true
	self.Height = math.max(34, tonumber(options.Height) or (self.Multiline and 110 or 0))
	self.ClearOnFocus = options.ClearOnFocus == true or options.ClearTextOnFocus == true
	self.ClearTextOnBlur = options.ClearTextOnBlur == true
	self.AllowEmpty = if options.AllowEmpty ~= nil then options.AllowEmpty ~= false else not self.Numeric
	self.EmptyReset = if options.EmptyReset ~= nil then options.EmptyReset else (self.Numeric and 0 or default)
	self.Validate = options.Validate or options.VerifyValue
	self.CommitOn = options.CommitOn
		or if options.Finished == true then "Enter" elseif options.Finished == false then "Change" else "FocusLost"
	self._error = nil
	Base.init(self, section, "Input", options, {
		Stateful = true,
		Default = default,
		Adaptive = true,
		Layout = if self.Multiline then "Stacked" else nil,
	})
	return Base.finish(self)
end
function TextField:_measure()
	if self.Multiline then
		local t = self._window.Tokens
		return t:Get("ControlHeight") + self.Height + 10 + (self.Description and 12 or 0)
	end
	return Base._measure(self)
end
function TextField:_mountValue(host)
	local w = self._window
	local t = w.Tokens
	self._box = Create.New("TextBox", {
		Size = UDim2.new(1, 0, 0, if self.Multiline then self.Height else t:Get("FieldHeight")),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClearTextOnFocus = self.ClearOnFocus,
		MultiLine = self.Multiline,
		PlaceholderText = self.Placeholder,
		Text = tostring(self:GetValue() or ""),
		Font = w.Fonts.Regular,
		TextSize = t:Get("FontBody"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = if self.Multiline then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center,
		Parent = host,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, t:Get("FieldRadius")), Parent = self._box })
	Create.New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = self._box })
	self._stroke = Create.New("UIStroke", { Thickness = 1, Transparency = 0.45, Parent = self._box })
	w:_bind(self._stroke, { Color = "BorderSubtle" })
	w:_bind(self._box, { BackgroundColor3 = "ControlInset", TextColor3 = "Text", PlaceholderColor3 = "TextTertiary" })
	if self.CommitOn == "Change" then
		self._janitor:Add(self._box:GetPropertyChangedSignal("Text"):Connect(function()
			if not self._suppressCommit then
				self:_commit()
			end
		end))
	end
	self._janitor:Add(self._box.Focused:Connect(function()
		self._stroke.Color = w.Theme:Get("AccentBorder")
		self._stroke.Transparency = 0
		if w.Device.Layout == "Drawer" then
			task.defer(function()
				self:Reveal()
			end)
		end
	end))
	self._janitor:Add(self._box.FocusLost:Connect(function(enter)
		self._stroke.Color = w.Theme:Get("BorderSubtle")
		self._stroke.Transparency = 0.45
		if self.CommitOn == "FocusLost" or (self.CommitOn == "Enter" and enter) then
			self:_commit()
		end
		if self.ClearTextOnBlur then
			self._suppressCommit = true
			self._box.Text = ""
			self._suppressCommit = false
		end
	end))
end
function TextField:_commit()
	local text = self._box.Text
	if self.MaxLength and #text > self.MaxLength then
		text = string.sub(text, 1, self.MaxLength)
		self._box.Text = text
	end
	if text == "" then
		if self.AllowEmpty then
			self:SetError(nil)
			self:SetValue("")
			return
		end
		local reset = self.EmptyReset
		text = tostring(if reset == nil then (self.Numeric and 0 or "") else reset)
		self._box.Text = text
	end
	local value = if self.Numeric then tonumber(text) else text
	if self.Numeric and value == nil then
		self:SetError("Enter a number")
		self:_render(self:GetValue())
		return
	end
	if self.Validate then
		local ok, message = self.Validate(value)
		if not ok then
			self:SetError(message or "Invalid value")
			return
		end
	end
	self:SetError(nil)
	self:SetValue(value)
end
function TextField:_render(v)
	if self._box then
		if not self._box:IsFocused() then
			self._box.Text = tostring(v or "")
		end
		self._box.BackgroundColor3 = self._window.Theme:Get(self._error and "AccentSoft" or "ControlInset")
		if self._error then
			self._stroke.Color = self._window.Theme:Get("Error")
			self._stroke.Transparency = 0
		end
	end
end
function TextField:Focus()
	if self._box then
		self._box:CaptureFocus()
	end
	return self
end
function TextField:Blur()
	if self._box then
		self._box:ReleaseFocus()
	end
	return self
end
function TextField:Clear()
	if self.AllowEmpty then
		return self:SetValue("")
	end
	return self:SetValue(self.EmptyReset)
end
function TextField:SetAllowEmpty(enabled, emptyReset)
	self.AllowEmpty = enabled ~= false
	if emptyReset ~= nil then
		self.EmptyReset = emptyReset
	end
	if not self.AllowEmpty and self:GetValue() == "" then
		self:SetValue(self.EmptyReset)
	end
	return self
end
function TextField:SetError(text)
	self._error = text
	self:_render(self:GetValue())
	return self
end
function TextField:_applyDisabled()
	Base._applyDisabled(self)
	if self._box then
		self._box.TextEditable = not self._disabled
	end
end
function TextField:_applyValueTokens()
	if self._valueHost and self.Multiline then
		self._valueHost.Size = UDim2.new(1, -self._window.Tokens:Get("ControlPadding") * 2, 0, self.Height)
	end
	if self._box then
		self._box.Size =
			UDim2.new(1, 0, 0, if self.Multiline then self.Height else self._window.Tokens:Get("FieldHeight"))
		self._box.TextSize = self._window.Tokens:Get("FontBody")
	end
end
return TextField
