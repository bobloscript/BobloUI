--!nonstrict
local Create = require("@runtime/Create")
local Janitor = require("@runtime/Janitor")
local Icon = require("@primitives/Icon")
local Notify = {}
Notify.__index = Notify
local TOK = { Default = "Accent", Success = "Success", Warning = "Warning", Error = "Error", Loading = "Info" }
local GLYPH = {
	Default = "bell",
	Success = "circle-check",
	Warning = "triangle-alert",
	Error = "circle-x",
	Loading = "loader-circle",
}

local function normalizeOptions(options)
	local out = table.clone(options or {})
	if out.Content == nil and out.Description ~= nil then
		out.Content = out.Description
	end
	if out.Image == nil then
		out.Image = out.BigImage or out.BigIcon
	end
	if out.Color == nil then
		out.Color = out.AccentColor or out.IconColor
	end
	if out.ContentColor == nil and out.DescriptionColor ~= nil then
		out.ContentColor = out.DescriptionColor
	end
	if out.Sound == nil and out.SoundId ~= nil then
		out.Sound = out.SoundId
	end
	if out.SoundOptions == nil and out.Volume ~= nil then
		out.SoundOptions = { Volume = out.Volume }
	end
	if out.Duration == nil then
		if out.Persist == true then
			out.Duration = 0
		elseif out.Time ~= nil then
			out.Duration = out.Time
		end
	end
	if out.Steps ~= nil and out.Progress == nil then
		local total = math.max(1, tonumber(out.Steps) or 1)
		out.Progress = math.max(0, tonumber(out.CurrentStep) or 0) / total
	end
	return out
end

function Notify.new(window, position)
	local self = setmetatable({
		_window = window,
		_items = {},
		_queue = {},
		_host = nil,
		_janitor = Janitor.new("Notify"),
		_position = position or "BottomRight",
	}, Notify)
	self:_ensureHost()
	self._janitor:Add(window.Device.Changed:Connect(function()
		self:_applyLayout()
	end))
	self._janitor:Add(window.Theme.Changed:Connect(function()
		self:_refreshTheme()
	end))
	return self
end
function Notify:_ensureHost()
	if self._host and self._host.Parent then
		return
	end
	local w = self._window
	self._host = Create.New("Frame", { Name = "Notifications", BackgroundTransparency = 1, Parent = w.Layers.Toast })
	self._layout = Create.List(8)
	self._layout.Parent = self._host
	self:_applyLayout()
end
function Notify:_applyLayout()
	if not self._host then
		return
	end
	local w = self._window
	local mobile = w.Device.Layout == "Drawer"
	if mobile then
		self._host.Size = UDim2.new(1, -16, 0, math.min(500, w.Device.Viewport.Y - 24))
		if string.sub(self._position, 1, 6) == "Bottom" then
			self._host.Position = UDim2.new(0, 8, 1, -(w.Device.Insets.Bottom + 8))
			self._host.AnchorPoint = Vector2.new(0, 1)
			self._layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		else
			self._host.Position = UDim2.fromOffset(8, w.Device.Insets.Top + 8)
			self._host.AnchorPoint = Vector2.new(0, 0)
			self._layout.VerticalAlignment = Enum.VerticalAlignment.Top
		end
	else
		self._host.Size = UDim2.fromOffset(320, 560)
		local pos = self._position
		if pos == "TopLeft" then
			self._host.Position = UDim2.fromOffset(14, 14)
			self._host.AnchorPoint = Vector2.new(0, 0)
			self._layout.VerticalAlignment = Enum.VerticalAlignment.Top
		elseif pos == "TopRight" then
			self._host.Position = UDim2.new(1, -14, 0, 14)
			self._host.AnchorPoint = Vector2.new(1, 0)
			self._layout.VerticalAlignment = Enum.VerticalAlignment.Top
		elseif pos == "BottomLeft" then
			self._host.Position = UDim2.new(0, 14, 1, -14)
			self._host.AnchorPoint = Vector2.new(0, 1)
			self._layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		else
			self._host.Position = UDim2.new(1, -14, 1, -14)
			self._host.AnchorPoint = Vector2.new(1, 1)
			self._layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		end
	end
end
function Notify:SetPosition(position)
	self._position = position or "BottomRight"
	self:_applyLayout()
	return self
end
function Notify:GetPosition()
	return self._position
end
function Notify:_refreshTheme()
	for _, item in self._items do
		local color = typeof(item.Color) == "Color3" and item.Color
			or self._window.Theme:Get(TOK[item.Variant] or "Accent")
		if item._rail then
			item._rail.BackgroundColor3 = color
		end
		if item._variantIcon then
			Icon.setColor(item._variantIcon, color)
		end
	end
end
function Notify:_mount(item)
	local w = self._window
	local j = Janitor.new("Notification")
	item._janitor = j
	local hasActions = item.Actions and #item.Actions > 0
	local hasProgress = item.Progress ~= nil
	local imageBlock = item.Image and 88 or 0
	local height = 66 + imageBlock + (hasActions and 34 or 0) + (hasProgress and 9 or 0)
	local frame = Create.New(
		"Frame",
		{ Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 0, BorderSizePixel = 0, Parent = self._host }
	)
	Create.New("UICorner", { CornerRadius = UDim.new(0, w.Tokens:Get("CornerMd")), Parent = frame })
	local stroke = Create.New("UIStroke", { Thickness = 1, Transparency = 0.44, Parent = frame })
	w:_bind(frame, { BackgroundColor3 = "SurfaceRaised" })
	w:_bind(stroke, { Color = "Border" })
	j:Add(frame)
	local rail = Create.New("Frame", {
		Size = UDim2.fromOffset(3, 32),
		Position = UDim2.fromOffset(0, 17),
		BorderSizePixel = 0,
		Parent = frame,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = rail })
	local iconHost = Create.New("Frame", {
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.fromOffset(11, 10),
		BorderSizePixel = 0,
		Parent = frame,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, 8), Parent = iconHost })
	local iconStroke = Create.New("UIStroke", { Thickness = 1, Transparency = 0.58, Parent = iconHost })
	w:_bind(iconHost, { BackgroundColor3 = "SurfaceInset" })
	w:_bind(iconStroke, { Color = "BorderSubtle" })
	local function renderVariantIcon()
		if item._variantIcon then
			item._variantIcon:Destroy()
		end
		item._variantIcon = Icon.new(w, item.Icon or GLYPH[item.Variant] or GLYPH.Default, {
			Size = UDim2.fromOffset(15, 15),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Parent = iconHost,
		})
		local color = typeof(item.Color) == "Color3" and item.Color or w.Theme:Get(TOK[item.Variant] or "Accent")
		rail.BackgroundColor3 = color
		Icon.setColor(item._variantIcon, color)
	end
	renderVariantIcon()
	item._title = Create.New("TextLabel", {
		Size = UDim2.new(1, -76, 0, 20),
		Position = UDim2.fromOffset(48, 8),
		BackgroundTransparency = 1,
		Font = w.Fonts.Medium,
		TextSize = w.Tokens:Get("FontBody"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = item.Title or "",
		Parent = frame,
	})
	w:_bind(item._title, { TextColor3 = "Text" })
	if typeof(item.TitleColor) == "Color3" then
		item._title.TextColor3 = item.TitleColor
	end
	item._content = Create.New("TextLabel", {
		Size = UDim2.new(1, -76, 0, 28),
		Position = UDim2.fromOffset(48, 29),
		BackgroundTransparency = 1,
		Font = w.Fonts.Regular,
		TextSize = w.Tokens:Get("FontSmall"),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = item.Content or "",
		Parent = frame,
	})
	w:_bind(item._content, { TextColor3 = "TextSecondary" })
	if typeof(item.ContentColor) == "Color3" then
		item._content.TextColor3 = item.ContentColor
	end
	if item.Image then
		item._image = Create.New("ImageLabel", {
			Size = UDim2.new(1, -26, 0, 78),
			Position = UDim2.fromOffset(13, 60),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Image = tostring(item.Image),
			ScaleType = item.ImageScaleType or Enum.ScaleType.Crop,
			Parent = frame,
		})
		Create.New("UICorner", { CornerRadius = UDim.new(0, 8), Parent = item._image })
		w:_bind(item._image, { BackgroundColor3 = "ControlInset" })
	end
	if hasProgress then
		local track = Create.New("Frame", {
			Size = UDim2.new(1, -26, 0, 3),
			Position = UDim2.new(0, 13, 1, -7),
			BorderSizePixel = 0,
			BackgroundTransparency = 0,
			Parent = frame,
		})
		Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
		w:_bind(track, { BackgroundColor3 = "ControlInset" })
		item._progressFill = Create.New("Frame", {
			Size = UDim2.new(math.clamp(tonumber(item.Progress) or 0, 0, 1), 0, 1, 0),
			BorderSizePixel = 0,
			Parent = track,
		})
		Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = item._progressFill })
		w:_bind(item._progressFill, { BackgroundColor3 = "Accent" })
	end
	local close = Create.New("TextButton", {
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, -5, 0, 5),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Parent = frame,
	})
	local closeIcon = Icon.new(w, "close", {
		Size = UDim2.fromOffset(12, 12),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = close,
	})
	Icon.setColor(closeIcon, w.Theme:Get("TextTertiary"))
	j:Add(close.MouseEnter:Connect(function()
		Icon.setColor(closeIcon, w.Theme:Get("Text"))
	end))
	j:Add(close.MouseLeave:Connect(function()
		Icon.setColor(closeIcon, w.Theme:Get("TextTertiary"))
	end))
	j:Add(close.MouseButton1Click:Connect(function()
		item:Dismiss()
	end))
	item._rail = rail
	item._renderIcon = renderVariantIcon
	if hasActions then
		local row = Create.New("Frame", {
			Size = UDim2.new(1, -26, 0, 28),
			Position = UDim2.fromOffset(13, 66 + imageBlock),
			BackgroundTransparency = 1,
			Parent = frame,
		})
		Create.List(6, Enum.FillDirection.Horizontal, { HorizontalAlignment = Enum.HorizontalAlignment.Right }).Parent =
			row
		for _, action in item.Actions do
			local b = Create.New("TextButton", {
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Text = "  " .. (action.Text or "Action") .. "  ",
				Font = w.Fonts.Medium,
				TextSize = w.Tokens:Get("FontSmall"),
				Parent = row,
			})
			Create.New("UICorner", { CornerRadius = UDim.new(0, 7), Parent = b })
			w:_bind(b, { BackgroundColor3 = "ControlInset", TextColor3 = "TextSecondary" })
			j:Add(b.MouseEnter:Connect(function()
				b.BackgroundColor3 = w.Theme:Get("ControlHover")
				b.TextColor3 = w.Theme:Get("Text")
			end))
			j:Add(b.MouseLeave:Connect(function()
				b.BackgroundColor3 = w.Theme:Get("ControlInset")
				b.TextColor3 = w.Theme:Get("TextSecondary")
			end))
			j:Add(b.MouseButton1Click:Connect(function()
				local ok, err = xpcall(action.Callback or function() end, debug.traceback)
				if not ok then
					warn(err)
				end
			end))
		end
	end
	if item.Sound and w.Sound then
		w.Sound:Play(item.Sound, item.SoundOptions)
	end
	if item.Duration and item.Duration > 0 then
		j:Add(task.delay(item.Duration, function()
			item:Dismiss()
		end))
	end
end
function Notify:Push(options)
	options = normalizeOptions(options)
	local item = {
		Title = options.Title or "Notification",
		Content = options.Content or "",
		Variant = options.Variant or "Default",
		Icon = options.Icon,
		Image = options.Image,
		ImageScaleType = options.ImageScaleType,
		Color = options.Color,
		TitleColor = options.TitleColor,
		ContentColor = options.ContentColor,
		Sound = options.Sound,
		SoundOptions = options.SoundOptions,
		Actions = options.Actions,
		Steps = math.max(0, tonumber(options.Steps) or 0),
		CurrentStep = math.max(0, tonumber(options.CurrentStep) or 0),
		Progress = if options.Progress ~= nil then options.Progress else if tonumber(options.Steps) then 0 else nil,
		Duration = if options.Duration == nil then 4 else options.Duration,
		_service = self,
		_dismissed = false,
	}
	function item:Update(o)
		if self._dismissed then
			return self
		end
		o = normalizeOptions(o)
		local hadImage = self.Image ~= nil
		local hadActions = self.Actions and #self.Actions > 0 or false
		local hadProgress = self.Progress ~= nil
		for k, v in o do
			self[k] = v
		end
		local hasImage = self.Image ~= nil
		local hasActions = self.Actions and #self.Actions > 0 or false
		local hasProgress = self.Progress ~= nil
		if
			hadImage ~= hasImage
			or hadActions ~= hasActions
			or hadProgress ~= hasProgress
			or o.Actions ~= nil
			or o.Duration ~= nil
			or o.Sound ~= nil
		then
			if self._janitor then
				self._janitor:Destroy()
				self._service:_mount(self)
			end
			return self
		end
		if self._title then
			self._title.Text = self.Title or ""
			self._content.Text = self.Content or ""
			self._renderIcon()
			self._title.TextColor3 = if typeof(self.TitleColor) == "Color3"
				then self.TitleColor
				else self._service._window.Theme:Get("Text")
			self._content.TextColor3 = if typeof(self.ContentColor) == "Color3"
				then self.ContentColor
				else self._service._window.Theme:Get("TextSecondary")
			if self._image then
				self._image.Image = tostring(self.Image or "")
				self._image.ScaleType = self.ImageScaleType or Enum.ScaleType.Crop
			end
			if self._progressFill and self.Progress ~= nil then
				self._progressFill.Size = UDim2.new(math.clamp(tonumber(self.Progress) or 0, 0, 1), 0, 1, 0)
			end
		end
		return self
	end
	function item:SetImage(image, scaleType)
		if self._dismissed then
			return self
		end
		self.Image = image
		if scaleType ~= nil then
			self.ImageScaleType = scaleType
		end
		if self._janitor then
			self._janitor:Destroy()
			self._service:_mount(self)
		end
		return self
	end
	function item:SetColors(accent, title, content)
		self.Color = accent
		self.TitleColor = title
		self.ContentColor = content
		if self._title then
			self._renderIcon()
			self._title.TextColor3 = if typeof(title) == "Color3"
				then title
				else self._service._window.Theme:Get("Text")
			self._content.TextColor3 = if typeof(content) == "Color3"
				then content
				else self._service._window.Theme:Get("TextSecondary")
		end
		return self
	end
	function item:SetProgress(value)
		self.Progress = math.clamp(tonumber(value) or 0, 0, 1)
		if self._progressFill then
			self._progressFill.Size = UDim2.new(self.Progress, 0, 1, 0)
		end
		return self
	end
	function item:ChangeTitle(title)
		return self:Update({ Title = title })
	end
	function item:ChangeDescription(description)
		return self:Update({ Content = description })
	end
	function item:ChangeStep(step, total)
		self.CurrentStep = math.max(0, tonumber(step) or 0)
		if total ~= nil then
			self.Steps = math.max(0, tonumber(total) or 0)
		end
		return self:SetProgress(if self.Steps > 0 then self.CurrentStep / self.Steps else 0)
	end
	function item:SetStep(step, total)
		return self:ChangeStep(step, total)
	end
	function item:Dismiss()
		if self._dismissed then
			return
		end
		self._dismissed = true
		local p = table.find(self._service._items, self)
		if p then
			table.remove(self._service._items, p)
		end
		if self._janitor then
			self._janitor:Destroy()
		end
		self._service:_drain()
	end
	function item:Destroy()
		self:Dismiss()
	end
	if #self._items < 4 then
		table.insert(self._items, item)
		self:_mount(item)
	else
		table.insert(self._queue, item)
	end
	return item
end
function Notify:_drain()
	while #self._items < 4 and #self._queue > 0 do
		local item = table.remove(self._queue, 1)
		if not item._dismissed then
			table.insert(self._items, item)
			self:_mount(item)
		end
	end
end
function Notify:Destroy()
	for i = #self._items, 1, -1 do
		self._items[i]:Dismiss()
	end
	self._queue = {}
	self._janitor:Destroy()
	if self._host then
		self._host:Destroy()
		self._host = nil
	end
end
return Notify
