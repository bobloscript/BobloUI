--!nonstrict
local Create = require("@runtime/Create")
local Base = require("@controls/Base")
local Signal = require("@runtime/Signal")
local Spinner = require("@primitives/Spinner")
local Button = setmetatable({}, { __index = Base })
Button.__index = Button
function Button.new(section, options)
	local self = setmetatable({}, Button)
	Base.init(self, section, "Button", options, { Stateful = false, Persist = false, Adaptive = true })
	self.Variant = options.Variant or "Default"
	self.Text = options.Text or options.Title or "Run"
	self.Confirm = options.Confirm or (options.Risky and "Confirm this action?")
	self.DoubleClick = options.DoubleClick
	self.DoubleClickWindow = tonumber(options.DoubleClickWindow) or 0.45
	self.SubButtons = options.SubButtons or options.Actions or {}
	self._lastClick = 0
	self.Clicked = Signal.new("Button.Clicked")
	self._janitor:Add(self.Clicked)
	return Base.finish(self)
end
function Button:_tokens()
	if self.Variant == "Primary" then
		return "AccentButton", "TextOnAccentButton", "AccentButtonHover", "AccentButtonPressed"
	end
	if self.Variant == "Danger" then
		return "Error", "TextOnError", "ErrorHover", "ErrorPressed"
	end
	if self.Variant == "Ghost" then
		return "ControlInset", "TextSecondary", "ControlHover", "ControlPressed"
	end
	return "SurfaceSecondary", "Text", "ControlHover", "ControlPressed"
end
function Button:_refreshInteractive()
	if not self._button then
		return
	end
	local bg, _, hover, pressed = self:_tokens()
	local token = if self._pressed then pressed elseif self._hovered then hover else bg
	self._button.BackgroundColor3 = self._window.Theme:Get(token)
end
function Button:_mountValue(host)
	local w = self._window
	local bg, fg = self:_tokens()
	local h = w.Tokens:Get("FieldHeight")
	self._button = Create.New("TextButton", {
		Size = UDim2.new(#self.SubButtons > 0 and 0.68 or 1, #self.SubButtons > 0 and -3 or 0, 0, h),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = self:_resolve(self.Text),
		Font = w.Fonts.Medium,
		TextSize = w.Tokens:Get("FontBody"),
		Parent = host,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, w.Tokens:Get("FieldRadius")), Parent = self._button })
	self._buttonScale = Create.New("UIScale", { Scale = 1, Parent = self._button })
	self._stroke = Create.New("UIStroke", { Thickness = 1, Transparency = 0.48, Parent = self._button })
	w:_bind(self._stroke, { Color = if self.Variant == "Primary" then "AccentBorder" else "BorderSubtle" })
	w:_bind(self._button, { BackgroundColor3 = bg, TextColor3 = fg })
	self._janitor:Add(self._button.MouseEnter:Connect(function()
		if not self._loading and not self:IsDisabled() then
			self._hovered = true
			self:_refreshInteractive()
			w.Motion:Tween(self._stroke, "Fast", { Transparency = 0.2 })
		end
	end))
	self._janitor:Add(self._button.MouseLeave:Connect(function()
		self._hovered = false
		self._pressed = false
		self:_refreshInteractive()
		w.Motion:Tween(self._stroke, "Fast", { Transparency = 0.48 })
		w.Motion:Tween(self._buttonScale, "Fast", { Scale = 1 })
	end))
	self._janitor:Add(self._button.MouseButton1Down:Connect(function()
		if not self:IsDisabled() and not self._loading then
			self._pressed = true
			self:_refreshInteractive()
			w.Motion:Tween(self._buttonScale, "Fast", { Scale = 0.985 })
		end
	end))
	self._janitor:Add(self._button.MouseButton1Up:Connect(function()
		self._pressed = false
		self:_refreshInteractive()
		w.Motion:Tween(self._buttonScale, "Fast", { Scale = 1 })
	end))
	self._janitor:Add(w.Theme.Changed:Connect(function()
		self:_refreshInteractive()
	end))
	self._janitor:Add(self._button.MouseButton1Click:Connect(function()
		self:Click()
	end))
	self._actionButtons = {}
	for _, action in self.SubButtons do
		self:_mountAction(host, action)
	end
end
function Button:_mountAction(host, action)
	local w = self._window
	local count = math.max(1, #self.SubButtons)
	local index = #self._actionButtons + 1
	local button = Create.New("TextButton", {
		Size = UDim2.new(0.32 / count, -3, 0, w.Tokens:Get("FieldHeight")),
		Position = UDim2.new(0.68 + ((index - 1) * 0.32 / count), 3, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = tostring(action.Text or action.Title or "…"),
		Font = w.Fonts.Medium,
		TextSize = w.Tokens:Get("FontSmall"),
		Parent = host,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, w.Tokens:Get("FieldRadius")), Parent = button })
	local stroke = Create.New("UIStroke", {
		Thickness = 1,
		Transparency = 0.48,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = button,
	})
	w:_bind(button, { BackgroundColor3 = "ControlInset", TextColor3 = "TextSecondary" })
	w:_bind(stroke, { Color = "BorderSubtle" })
	button.MouseButton1Click:Connect(function()
		if not self:IsDisabled() and not self._loading and action.Callback then
			local ok, err = xpcall(action.Callback, debug.traceback, self)
			if not ok then
				warn(err)
			end
		end
	end)
	table.insert(self._actionButtons, button)
	return button
end
function Button:AddAction(action)
	table.insert(self.SubButtons, action or {})
	if self._button then
		self._button.Size = UDim2.new(0.68, -3, 0, self._window.Tokens:Get("FieldHeight"))
		for _, button in self._actionButtons or {} do
			button:Destroy()
		end
		self._actionButtons = {}
		for _, spec in self.SubButtons do
			self:_mountAction(self._valueHost, spec)
		end
	end
	return self
end
function Button:AddKeybind(options)
	options = table.clone(options or {})
	options.AttachTo = self
	return require("@controls/Keybind").new(self._section, options)
end
function Button:Click()
	if self:IsDisabled() or self._loading then
		return self
	end
	if self._window.Sound then
		self._window.Sound:Play("Click")
	end
	if self.DoubleClick then
		local now = os.clock()
		if now - self._lastClick > self.DoubleClickWindow then
			self._lastClick = now
			return self
		end
		self._lastClick = 0
	end
	local function run()
		if self.Callback then
			local ok, err = xpcall(self.Callback, debug.traceback)
			if not ok then
				warn(`[BobloUI] Button "{self.Title}" callback failed:\n{err}`)
			end
		end
		self.Clicked:Fire()
	end
	if self.Confirm and self._window.Dialog then
		task.spawn(function()
			local ok = self._window.Dialog:Confirm({ Title = self.Title, Content = self.Confirm }):Await()
			if ok then
				run()
			end
		end)
	else
		run()
	end
	return self
end
function Button:_setLoadingVisual(v)
	if not self._button then
		return
	end
	self._button.Text = if v then "" else self:_resolve(self.Text)
	if self._spinner then
		self._spinner:Destroy()
		self._spinner = nil
	end
	if v then
		self._spinner = Spinner.new(self._window, self._button, 15)
		self._spinner.Position = UDim2.fromScale(0.5, 0.5)
		self._spinner.AnchorPoint = Vector2.new(0.5, 0.5)
	end
end
function Button:_refreshText()
	Base._refreshText(self)
	if self._button and not self._loading then
		self._button.Text = self:_resolve(self.Text)
	end
end
function Button:_applyValueTokens()
	if self._button then
		self._button.Size = UDim2.new(
			#self.SubButtons > 0 and 0.68 or 1,
			#self.SubButtons > 0 and -3 or 0,
			0,
			self._window.Tokens:Get("FieldHeight")
		)
		self._button.TextSize = self._window.Tokens:Get("FontBody")
	end
	for _, button in self._actionButtons or {} do
		button.Size = UDim2.new(0.32 / math.max(1, #self.SubButtons), -3, 0, self._window.Tokens:Get("FieldHeight"))
		button.TextSize = self._window.Tokens:Get("FontSmall")
	end
end
return Button
