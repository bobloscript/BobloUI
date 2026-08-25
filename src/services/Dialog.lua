--!nonstrict
local TextService = game:GetService("TextService")
local Create = require("@runtime/Create")
local Signal = require("@runtime/Signal")
local Janitor = require("@runtime/Janitor")
local Surface = require("@primitives/Surface")
local Sheet = require("@primitives/Sheet")
local Icon = require("@primitives/Icon")
local DialogSection = require("@services/DialogSection")
local Dialog = {}
Dialog.__index = Dialog

function Dialog.new(window)
	return setmetatable({ _window = window, _open = {} }, Dialog)
end

function Dialog:_width()
	return math.max(240, math.min(392, self._window.Device.Viewport.X - 32))
end
function Dialog:_measure(text, width)
	if not text or text == "" then
		return 0
	end
	local w = self._window
	local ok, size = pcall(function()
		return TextService:GetTextSize(
			tostring(text),
			w.Tokens:Get("FontBody"),
			w.Fonts.Regular,
			Vector2.new(width, 1000)
		)
	end)
	return if ok then math.max(18, size.Y) else 36
end
function Dialog:_surface(height, onDismiss, options)
	options = options or {}
	local w = self._window
	if w.Device.Layout == "Drawer" then
		local h = Sheet.open(w, height, { OnDismiss = onDismiss, Modal = options.OutsideClickDismiss ~= true })
		return h, h.Frame
	end
	local safeHeight = math.max(1, math.min(height, math.max(1, w.Device.Viewport.Y - 32)))
	local h = w.Layers:Push({
		Scrim = true,
		ScrimTransparency = options.ScrimTransparency,
		Modal = options.OutsideClickDismiss ~= true,
		OnDismiss = onDismiss,
	})
	local frame = Surface.new(w, {
		Size = UDim2.fromOffset(self:_width(), safeHeight),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = h.Container,
	}, {
		Token = "SurfaceRaised",
		StrokeToken = "Border",
		StrokeTransparency = 0.40,
		Corner = w.Tokens:Get("CornerLg"),
	})
	frame.ZIndex = h.Depth * 10 + 3
	return h, frame
end
function Dialog:_title(parent, text, icon, colorToken, titleColor)
	local w = self._window
	local iconHost = Create.New("Frame", {
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.fromOffset(16, 11),
		BorderSizePixel = 0,
		Parent = parent,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, 8), Parent = iconHost })
	local iconStroke = Create.New("UIStroke", { Thickness = 1, Transparency = 0.58, Parent = iconHost })
	w:_bind(iconHost, { BackgroundColor3 = "SurfaceInset" })
	w:_bind(iconStroke, { Color = "BorderSubtle" })
	local glyph = Icon.new(w, icon or "info", {
		Size = UDim2.fromOffset(15, 15),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = iconHost,
	})
	Icon.setColor(glyph, w.Theme:Get(colorToken or "Accent"))
	local title = Create.New("TextLabel", {
		Size = UDim2.new(1, -66, 0, 24),
		Position = UDim2.fromOffset(52, 14),
		BackgroundTransparency = 1,
		Font = w.Fonts.Bold,
		TextSize = w.Tokens:Get("FontTitle"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text or "",
		Parent = parent,
	})
	if typeof(titleColor) == "Color3" then
		title.TextColor3 = titleColor
	else
		w:_bind(title, { TextColor3 = "Text" })
	end
	return title
end
function Dialog:_button(parent, text, primary, danger, callback, options)
	options = options or {}
	local w = self._window
	local bg = if danger and primary then "Error" elseif primary then "AccentButton" else "ControlInset"
	local fg = if danger and primary then "TextOnError" elseif primary then "TextOnAccentButton" else "TextSecondary"
	local hoverBg = if danger and primary then "ErrorHover" elseif primary then "AccentButtonHover" else "ControlHover"
	local pressedBg = if danger and primary
		then "ErrorPressed"
		elseif primary then "AccentButtonPressed"
		else "ControlPressed"
	local full = options.FullWidth == true
	local b = Create.New("TextButton", {
		AutomaticSize = if full then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
		Size = if full then UDim2.new(1, 0, 0, 34) else UDim2.new(0, 0, 0, 34),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = if full then tostring(text) else "  " .. tostring(text) .. "  ",
		TextXAlignment = if full then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		Font = w.Fonts.Medium,
		TextSize = w.Tokens:Get("FontBody"),
		Parent = parent,
	})
	if full then
		Create.New("UIPadding", {
			PaddingLeft = UDim.new(0, if options.Icon then 36 else 11),
			PaddingRight = UDim.new(0, 11),
			Parent = b,
		})
		if options.Icon then
			local glyph = Icon.new(w, options.Icon, {
				Size = UDim2.fromOffset(15, 15),
				Position = UDim2.fromOffset(-25, 17),
				AnchorPoint = Vector2.new(0, 0.5),
				Parent = b,
			})
			Icon.setColor(glyph, w.Theme:Get(fg))
		end
	end
	Create.New("UICorner", { CornerRadius = UDim.new(0, w.Tokens:Get("FieldRadius")), Parent = b })
	local stroke = Create.New("UIStroke", { Thickness = 1, Transparency = 0.58, Parent = b })
	w:_bind(
		stroke,
		{ Color = if danger and primary then "ErrorHover" elseif primary then "AccentBorder" else "BorderSubtle" }
	)
	w:_bind(b, { BackgroundColor3 = bg, TextColor3 = fg })
	local hovered = false
	local pressed = false
	local function refresh()
		if b.Parent then
			b.BackgroundColor3 = w.Theme:Get(if pressed then pressedBg elseif hovered then hoverBg else bg)
		end
	end
	b.MouseEnter:Connect(function()
		hovered = true
		refresh()
	end)
	b.MouseLeave:Connect(function()
		hovered = false
		pressed = false
		refresh()
	end)
	b.MouseButton1Down:Connect(function()
		pressed = true
		refresh()
	end)
	b.MouseButton1Up:Connect(function()
		pressed = false
		refresh()
	end)
	local themeConnection = w.Theme.Changed:Connect(refresh)
	b.Destroying:Connect(function()
		themeConnection:Disconnect()
	end)
	b.MouseButton1Click:Connect(callback)
	return b
end

function Dialog:_make(options, kind)
	options = options or {}
	local w = self._window
	local resultSignal = Signal.new("Dialog.Resolved")
	local resultHandle = { Resolved = resultSignal, _resolved = false, _result = nil }
	local width = self:_width()
	local contentHeight = self:_measure(options.Content or "", width - 32)
	local titleY = 14
	local contentY = 44
	local afterContent = contentY + contentHeight
	if contentHeight == 0 then
		afterContent = 43
	end
	local inputY = afterContent + (kind == "Prompt" and 12 or 0)
	local buttonsY = if kind == "Prompt" then inputY + 34 + 16 else afterContent + 16
	local height = math.max(kind == "Prompt" and 184 or 138, buttonsY + 34 + 14)
	local layerHandle, frame
	local function removeOpen()
		local p = table.find(self._open, resultHandle)
		if p then
			table.remove(self._open, p)
		end
	end
	local function dismissed()
		if not resultHandle._resolved then
			resultHandle._resolved = true
			resultHandle._result = nil
			resultSignal:Fire(nil)
			removeOpen()
		end
	end
	layerHandle, frame = self:_surface(height, dismissed, options)
	resultHandle._layer = layerHandle

	local defaultIcon = if kind == "Prompt"
		then "text-cursor-input"
		elseif kind == "Confirm" then "circle-question-mark"
		elseif options.Danger then "triangle-alert"
		else "info"
	self:_title(frame, options.Title or "", options.Icon or defaultIcon, options.Danger and "Error" or "Accent")
	if contentHeight > 0 then
		local content = Create.New("TextLabel", {
			Size = UDim2.new(1, -32, 0, contentHeight),
			Position = UDim2.fromOffset(16, contentY),
			BackgroundTransparency = 1,
			Font = w.Fonts.Regular,
			TextSize = w.Tokens:Get("FontBody"),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = options.Content or "",
			Parent = frame,
		})
		w:_bind(content, { TextColor3 = "TextSecondary" })
	end
	local input = nil
	if kind == "Prompt" then
		input = Create.New("TextBox", {
			Size = UDim2.new(1, -32, 0, 34),
			Position = UDim2.fromOffset(16, inputY),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			PlaceholderText = options.Placeholder or "",
			Text = options.Default or "",
			Font = w.Fonts.Regular,
			TextSize = w.Tokens:Get("FontBody"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		Create.New("UICorner", { CornerRadius = UDim.new(0, w.Tokens:Get("FieldRadius")), Parent = input })
		Create.New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = input })
		local stroke = Create.New("UIStroke", { Thickness = 1, Transparency = 0.54, Parent = input })
		w:_bind(stroke, { Color = "BorderSubtle" })
		w:_bind(input, { BackgroundColor3 = "ControlInset", TextColor3 = "Text", PlaceholderColor3 = "TextTertiary" })
		input.Focused:Connect(function()
			stroke.Transparency = 0.08
			stroke.Color = w.Theme:Get("AccentBorder")
		end)
		input.FocusLost:Connect(function()
			stroke.Transparency = 0.54
			stroke.Color = w.Theme:Get("BorderSubtle")
		end)
	end

	local function resolve(v)
		if resultHandle._resolved then
			return
		end
		resultHandle._resolved = true
		resultHandle._result = v
		resultSignal:Fire(v)
		removeOpen()
		layerHandle:Dismiss()
	end
	function resultHandle:Resolve(v)
		resolve(v)
	end
	function resultHandle:Close()
		resolve(nil)
	end
	function resultHandle:IsOpen()
		return not self._resolved and layerHandle:IsOpen()
	end
	function resultHandle:Await()
		if self._resolved then
			return self._result
		end
		return self.Resolved:Wait()
	end
	function resultHandle:Destroy()
		self:Close()
		self.Resolved:Destroy()
	end
	local buttons = Create.New("Frame", {
		Size = UDim2.new(1, -32, 0, 34),
		Position = UDim2.fromOffset(16, buttonsY),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	Create.List(7, Enum.FillDirection.Horizontal, { HorizontalAlignment = Enum.HorizontalAlignment.Right }).Parent =
		buttons
	if kind == "Alert" then
		self:_button(buttons, options.Button or "OK", true, options.Danger == true, function()
			resolve(true)
		end)
	elseif kind == "Confirm" then
		self:_button(buttons, options.Cancel or "Cancel", false, false, function()
			resolve(false)
		end)
		self:_button(buttons, options.Confirm or "Confirm", true, options.Danger == true, function()
			resolve(true)
		end)
	else
		self:_button(buttons, options.Cancel or "Cancel", false, false, function()
			resolve(nil)
		end)
		self:_button(buttons, options.Confirm or "OK", true, false, function()
			resolve(input.Text)
		end)
	end
	table.insert(self._open, resultHandle)
	return resultHandle
end
function Dialog:Alert(o)
	return self:_make(o, "Alert")
end
function Dialog:Confirm(o)
	return self:_make(o, "Confirm")
end
function Dialog:Prompt(o)
	return self:_make(o, "Prompt")
end
function Dialog:Choice(options)
	options = options or {}
	local choices = options.Choices or {}
	local w = self._window
	local result = Signal.new("Dialog.Choice")
	local handle = { Resolved = result, _resolved = false, _result = nil }
	local rowHeight, gap = 34, 6
	local maxListHeight = math.max(34, math.min(274, w.Device.Viewport.Y - 150))
	local naturalHeight = #choices * rowHeight + math.max(0, #choices - 1) * gap
	local listHeight = math.min(maxListHeight, math.max(rowHeight, naturalHeight))
	local height = 50 + listHeight + 16
	local layer, frame
	local function resolve(v)
		if handle._resolved then
			return
		end
		handle._resolved = true
		handle._result = v
		result:Fire(v)
		if layer then
			layer:Dismiss()
		end
	end
	layer, frame = self:_surface(height, function()
		resolve(nil)
	end)
	self:_title(frame, options.Title or "Choose", options.Icon or "list-check", "Accent")
	local scroll = naturalHeight > listHeight
	local list
	if scroll then
		list = Create.New("ScrollingFrame", {
			Size = UDim2.new(1, -32, 0, listHeight),
			Position = UDim2.fromOffset(16, 50),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 2,
			Parent = frame,
		})
		w:_bind(list, { ScrollBarImageColor3 = "BorderStrong" })
	else
		list = Create.New("Frame", {
			Size = UDim2.new(1, -32, 0, listHeight),
			Position = UDim2.fromOffset(16, 50),
			BackgroundTransparency = 1,
			Parent = frame,
		})
	end
	Create.List(gap).Parent = list
	for _, choice in choices do
		self:_button(
			list,
			choice.Text or tostring(choice.Value),
			choice.Primary == true,
			choice.Danger == true,
			function()
				resolve(choice.Value)
			end,
			{ FullWidth = true, Icon = choice.Icon }
		)
	end
	function handle:Resolve(v)
		resolve(v)
	end
	function handle:Close()
		resolve(nil)
	end
	function handle:IsOpen()
		return not self._resolved and layer:IsOpen()
	end
	function handle:Await()
		if self._resolved then
			return self._result
		end
		return self.Resolved:Wait()
	end
	function handle:Destroy()
		self:Close()
		self.Resolved:Destroy()
	end
	return handle
end

function Dialog:Custom(options)
	options = options or {}
	local w = self._window
	local j = Janitor.new("Dialog.Custom")
	local handle = { _buttons = {}, _closed = false, _result = nil, Closed = Signal.new("Dialog.Custom.Closed") }
	j:Add(handle.Closed)
	local layer, frame
	local function removeOpen()
		local position = table.find(self._open, handle)
		if position then
			table.remove(self._open, position)
		end
	end
	local function dismissed()
		if handle._closed then
			return
		end
		handle._closed = true
		handle.Result = handle._result
		handle.Closed:Fire(handle._result)
		removeOpen()
		j:Destroy()
	end
	layer, frame = self:_surface(options.Height or 380, dismissed, options)
	handle._layer = layer
	handle._frame = frame
	handle._title =
		self:_title(frame, options.Title or "", options.Icon or "layout-template", "Accent", options.TitleColor)

	local descriptionHeight = self:_measure(options.Description or "", self:_width() - 32)
	local contentTop = if descriptionHeight > 0 then 53 + descriptionHeight else 48
	handle._description = Create.New("TextLabel", {
		Size = UDim2.new(1, -32, 0, descriptionHeight),
		Position = UDim2.fromOffset(16, 45),
		BackgroundTransparency = 1,
		Font = w.Fonts.Regular,
		TextSize = w.Tokens:Get("FontBody"),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = tostring(options.Description or ""),
		Visible = descriptionHeight > 0,
		Parent = frame,
	})
	if typeof(options.DescriptionColor) == "Color3" then
		handle._description.TextColor3 = options.DescriptionColor
	else
		w:_bind(handle._description, { TextColor3 = "TextSecondary" })
	end
	local footerHeight = 50
	local content = Create.New("ScrollingFrame", {
		Size = UDim2.new(1, -32, 1, -(contentTop + footerHeight)),
		Position = UDim2.fromOffset(16, contentTop),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 2,
		Parent = frame,
	})
	w:_bind(content, { ScrollBarImageColor3 = "BorderStrong" })
	handle._content = content
	local function reflowDescription(text)
		local height = self:_measure(text or "", self:_width() - 32)
		handle._description.Text = tostring(text or "")
		handle._description.Visible = height > 0
		handle._description.Size = UDim2.new(1, -32, 0, height)
		local top = if height > 0 then 53 + height else 48
		content.Position = UDim2.fromOffset(16, top)
		content.Size = UDim2.new(1, -32, 1, -(top + footerHeight))
	end
	Create.List(w.Tokens:Get("RowGap")).Parent = content
	local section = DialogSection.new(w, content, j)
	handle.Section = section

	local footer = Create.New("Frame", {
		Size = UDim2.new(1, -32, 0, 34),
		Position = UDim2.new(0, 16, 1, -42),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	Create.List(7, Enum.FillDirection.Horizontal, { HorizontalAlignment = Enum.HorizontalAlignment.Right }).Parent =
		footer
	handle._footer = footer

	local function refreshButton(entry)
		if not entry or not entry.Button then
			return
		end
		local unavailable = entry.Disabled or entry.Waiting
		entry.Button.Active = not unavailable
		entry.Button.TextTransparency = if unavailable then 0.48 else 0
		entry.Button.BackgroundTransparency = if unavailable then 0.42 else 0
	end

	function handle:AddFooterButton(id, spec)
		if type(id) ~= "string" or id == "" or type(spec) ~= "table" then
			error("[BobloUI] Dialog:AddFooterButton expects id and options table.", 2)
		end
		self:RemoveFooterButton(id)
		local variant = spec.Variant or (spec.Primary and "Primary") or (spec.Danger and "Destructive") or "Secondary"
		local primary = variant == "Primary" or variant == "Destructive"
		local danger = variant == "Destructive" or variant == "Danger"
		local entry = {
			Id = id,
			Spec = spec,
			Disabled = spec.Disabled == true,
			Waiting = (tonumber(spec.WaitTime) or 0) > 0,
		}
		entry.Button = self._dialog:_button(footer, spec.Title or spec.Text or id, primary, danger, function()
			if entry.Disabled or entry.Waiting or self._closed then
				return
			end
			if spec.Callback then
				local ok, result = xpcall(spec.Callback, debug.traceback, self, section)
				if not ok then
					warn(result)
					return
				end
				if result == false then
					return
				end
			end
			if spec.Close ~= false and options.AutoDismiss ~= false then
				self:Close(id)
			end
		end)
		entry.Button.LayoutOrder = tonumber(spec.Order) or 0
		self._buttons[id] = entry
		refreshButton(entry)
		local waitTime = math.max(0, tonumber(spec.WaitTime) or 0)
		if waitTime > 0 then
			entry.Progress = Create.New("Frame", {
				Size = UDim2.fromScale(0, 1),
				BackgroundTransparency = 0.7,
				BorderSizePixel = 0,
				Parent = entry.Button,
			})
			Create.New("UICorner", {
				CornerRadius = UDim.new(0, w.Tokens:Get("FieldRadius")),
				Parent = entry.Progress,
			})
			w:_bind(entry.Progress, { BackgroundColor3 = "Accent" })
			w.Motion:Tween(entry.Progress, TweenInfo.new(waitTime, Enum.EasingStyle.Linear), {
				Size = UDim2.fromScale(1, 1),
			})
			j:Add(task.delay(waitTime, function()
				if not self._closed and self._buttons[id] == entry then
					entry.Waiting = false
					if entry.Progress then
						entry.Progress:Destroy()
						entry.Progress = nil
					end
					refreshButton(entry)
				end
			end))
		end
		return self
	end
	function handle:RemoveFooterButton(id)
		local entry = self._buttons[id]
		if entry then
			self._buttons[id] = nil
			entry.Button:Destroy()
		end
		return self
	end
	function handle:SetButtonDisabled(id, disabled)
		local entry = self._buttons[id]
		if not entry then
			return false
		end
		entry.Disabled = disabled == true
		refreshButton(entry)
		return self
	end
	function handle:SetButtonOrder(id, order)
		local entry = self._buttons[id]
		if not entry then
			return false
		end
		entry.Button.LayoutOrder = tonumber(order) or 0
		return self
	end
	function handle:SetTitle(text)
		self._title.Text = tostring(text or "")
		return self
	end
	function handle:SetDescription(text)
		reflowDescription(text)
		return self
	end
	function handle:Close(result)
		self._result = result
		if self._layer:IsOpen() then
			self._layer:Dismiss()
		end
		return self
	end
	function handle:Dismiss()
		return self:Close(nil)
	end
	function handle:IsOpen()
		return not self._closed and self._layer:IsOpen()
	end
	function handle:Destroy()
		return self:Close(nil)
	end
	function handle:Await()
		if self._closed then
			return self.Result
		end
		return self.Closed:Wait()
	end
	handle._dialog = self

	local footerButtons = options.FooterButtons
	if type(footerButtons) == "table" then
		for id, spec in footerButtons do
			handle:AddFooterButton(tostring(id), spec)
		end
	else
		for index, spec in options.Buttons or { { Text = "Close" } } do
			handle:AddFooterButton(spec.Id or `Button{index}`, spec)
		end
	end
	if options.Build then
		options.Build(section, handle)
	end
	table.insert(self._open, handle)
	return handle
end
function Dialog:Destroy()
	for _, d in table.clone(self._open) do
		if d:IsOpen() then
			d:Close()
		end
	end
	self._open = {}
end
return Dialog
