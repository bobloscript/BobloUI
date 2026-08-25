--!nonstrict
-- Header, footer, topbar, restore button, appearance, and visibility chrome.

local Create = require("@runtime/Create")
local Icon = require("@primitives/Icon")

local New = Create.New
local WindowChrome = {}
local FADE_TIME = 0.12

local function addToolbarStroke(window, button)
	local stroke = New("UIStroke", { Thickness = 1, Transparency = 0.72, Parent = button })
	window:_bind(stroke, { Color = "BorderSubtle" })
	return stroke
end

local function drawToolbarIcon(window, parent, name, size)
	local glyph = Icon.new(window, name, {
		Size = UDim2.fromOffset(size or 16, size or 16),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = parent,
	})
	Icon.setColor(glyph, window.Theme:Get("TextSecondary"))
	return glyph
end

local function drawSearchIcon(window, parent)
	return drawToolbarIcon(window, parent, "search", 16)
end

local function drawThemeIcon(window, parent)
	return drawToolbarIcon(window, parent, "sun-moon", 17)
end

function WindowChrome:_buildHeader()
	local tokens = self.Tokens

	self._header = New("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, tokens:Get("HeaderHeight")),
		BorderSizePixel = 0,
		Parent = self._root,
	})
	self._headerCorner = New("UICorner", {
		CornerRadius = UDim.new(0, self._cornerRadius),
		Parent = self._header,
	})
	self:_bind(self._header, { BackgroundColor3 = "Canvas" })

	self._headerLine = New("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BorderSizePixel = 0,
		Parent = self._header,
	})
	self._headerLine.BackgroundTransparency = 0.35
	self:_bind(self._headerLine, { BackgroundColor3 = "BorderSubtle" })

	-- Hamburger, drawn rather than typed: no font ships a guaranteed glyph.
	self._navToggle = New("TextButton", {
		Name = "NavToggle",
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		Parent = self._header,
	})
	drawToolbarIcon(self, self._navToggle, "menu", 17)
	self._janitor:Add(self._navToggle.MouseButton1Click:Connect(function()
		self:OpenDrawer()
	end))

	self._brandMark = New("Frame", {
		Name = "BrandMark",
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(0, 14, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BorderSizePixel = 0,
		Parent = self._header,
	})
	New("UICorner", { CornerRadius = UDim.new(0, 8), Parent = self._brandMark })
	local brandStroke = New("UIStroke", { Thickness = 1, Transparency = 0.46, Parent = self._brandMark })
	self:_bind(self._brandMark, { BackgroundColor3 = "AccentSoft" })
	self:_bind(brandStroke, { Color = "AccentBorder" })
	self._brandDot = New("Frame", {
		Name = "StatusDot",
		Size = UDim2.fromOffset(5, 5),
		Position = UDim2.new(1, -1, 0, 1),
		AnchorPoint = Vector2.new(1, 0),
		BorderSizePixel = 0,
		Parent = self._brandMark,
	})
	New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self._brandDot })
	self:_bind(self._brandDot, { BackgroundColor3 = "Accent" })
	if self.Icon then
		self._brandGlyph = Icon.new(self, self.Icon, {
			Size = UDim2.fromOffset(15, 15),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Parent = self._brandMark,
		})
		Icon.setColor(self._brandGlyph, self.Theme:Get("Accent"))
	else
		self._brandGlyph = New("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = self.Fonts.Bold,
			TextSize = 14,
			Text = self.Title:sub(1, 1):upper(),
			Parent = self._brandMark,
		})
		self:_bind(self._brandGlyph, { TextColor3 = "Accent" })
	end

	self._titleLabel = New("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, -176, 0, 18),
		Position = UDim2.new(0, 52, 0, 9),
		BackgroundTransparency = 1,
		Font = self.Fonts.Bold,
		TextSize = tokens:Get("FontTitle"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = self.Title,
		Parent = self._header,
	})
	self:_bind(self._titleLabel, { TextColor3 = "Text" })

	self._subtitleLabel = New("TextLabel", {
		Name = "Subtitle",
		Size = UDim2.new(1, -176, 0, 14),
		Position = UDim2.new(0, 52, 0, 29),
		BackgroundTransparency = 1,
		Font = self.Fonts.Regular,
		TextSize = tokens:Get("FontSmall"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = self.Subtitle or "",
		Visible = self.Subtitle ~= nil,
		Parent = self._header,
	})
	self:_bind(self._subtitleLabel, { TextColor3 = "TextSecondary" })

	self._topbarExtras = New("Frame", {
		Name = "TopbarExtras",
		Size = UDim2.fromOffset(230, 30),
		Position = UDim2.new(1, -188, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = self._header,
	})
	local topbarLayout = Create.List(
		5,
		Enum.FillDirection.Horizontal,
		{ HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center }
	)
	topbarLayout.Parent = self._topbarExtras

	self._sidebarButton = New("TextButton", {
		Name = "SidebarToggle",
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, -152, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 0.82,
		AutoButtonColor = false,
		Text = "",
		Parent = self._header,
	})
	New("UICorner", { CornerRadius = UDim.new(0, tokens:Get("CornerSm")), Parent = self._sidebarButton })
	addToolbarStroke(self, self._sidebarButton)
	self:_bind(self._sidebarButton, { BackgroundColor3 = "ControlHover" })
	local sidebarIcon = Icon.new(self, "menu", {
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = self._sidebarButton,
	})
	Icon.setColor(sidebarIcon, self.Theme:Get("TextSecondary"))
	self._janitor:Add(self._sidebarButton.MouseEnter:Connect(function()
		self._sidebarButton.BackgroundTransparency = 0.48
	end))
	self._janitor:Add(self._sidebarButton.MouseLeave:Connect(function()
		self._sidebarButton.BackgroundTransparency = 0.82
	end))
	self._janitor:Add(self._sidebarButton.MouseButton1Click:Connect(function()
		if self._layout == "Drawer" then
			self:OpenDrawer()
		else
			self:ToggleSidebar()
		end
	end))

	self._searchButton = New("TextButton", {
		Name = "Search",
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, -116, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 0.82,
		AutoButtonColor = false,
		Text = "",
		Visible = not self._disableSearch,
		Parent = self._header,
	})
	New("UICorner", { CornerRadius = UDim.new(0, tokens:Get("CornerSm")), Parent = self._searchButton })
	addToolbarStroke(self, self._searchButton)
	self:_bind(self._searchButton, { BackgroundColor3 = "ControlHover" })
	drawSearchIcon(self, self._searchButton)
	self._janitor:Add(self._searchButton.MouseEnter:Connect(function()
		self._searchButton.BackgroundTransparency = 0.48
	end))
	self._janitor:Add(self._searchButton.MouseLeave:Connect(function()
		self._searchButton.BackgroundTransparency = 0.82
	end))
	self._janitor:Add(self._searchButton.MouseButton1Click:Connect(function()
		if self.OpenSearch then
			self:OpenSearch()
		end
	end))

	self._themeButton = New("TextButton", {
		Name = "Theme",
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, -80, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 0.82,
		AutoButtonColor = false,
		Text = "",
		Parent = self._header,
	})
	New("UICorner", { CornerRadius = UDim.new(0, tokens:Get("CornerSm")), Parent = self._themeButton })
	addToolbarStroke(self, self._themeButton)
	self:_bind(self._themeButton, { BackgroundColor3 = "ControlHover" })
	drawThemeIcon(self, self._themeButton)
	self._janitor:Add(self._themeButton.MouseEnter:Connect(function()
		self._themeButton.BackgroundTransparency = 0.48
	end))
	self._janitor:Add(self._themeButton.MouseLeave:Connect(function()
		self._themeButton.BackgroundTransparency = 0.82
	end))
	self._janitor:Add(self._themeButton.MouseButton1Click:Connect(function()
		if self.SetTheme then
			self:SetTheme(self.Theme:Current() == "Dark" and "Light" or "Dark")
		end
	end))

	self._minimizeButton = New("TextButton", {
		Name = "Minimize",
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, -44, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 0.86,
		AutoButtonColor = false,
		Text = "",
		Parent = self._header,
	})
	New("UICorner", { CornerRadius = UDim.new(0, tokens:Get("CornerSm")), Parent = self._minimizeButton })
	addToolbarStroke(self, self._minimizeButton)
	drawToolbarIcon(self, self._minimizeButton, "minus", 15)
	self:_bind(self._minimizeButton, { BackgroundColor3 = "ControlHover" })
	self._janitor:Add(self._minimizeButton.MouseEnter:Connect(function()
		self._minimizeButton.BackgroundTransparency = 0.48
	end))
	self._janitor:Add(self._minimizeButton.MouseLeave:Connect(function()
		self._minimizeButton.BackgroundTransparency = 0.86
	end))
	self._janitor:Add(self._minimizeButton.MouseButton1Click:Connect(function()
		self:Minimize()
	end))

	self._closeButton = New("TextButton", {
		Name = "Close",
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 0.88,
		AutoButtonColor = false,
		Text = "",
		Parent = self._header,
	})
	New("UICorner", { CornerRadius = UDim.new(0, tokens:Get("CornerSm")), Parent = self._closeButton })
	addToolbarStroke(self, self._closeButton)
	drawToolbarIcon(self, self._closeButton, "x", 16)
	self:_bind(self._closeButton, { BackgroundColor3 = "ControlHover" })
	self._closeButton.BackgroundTransparency = 0.88

	self._janitor:Add(self._closeButton.MouseEnter:Connect(function()
		self._closeButton.BackgroundTransparency = 0.48
	end))
	self._janitor:Add(self._closeButton.MouseLeave:Connect(function()
		self._closeButton.BackgroundTransparency = 0.88
	end))
	self._janitor:Add(self._closeButton.MouseButton1Click:Connect(function()
		self:Hide()
	end))

	self:_attachDrag(self._header)
end

function WindowChrome:_buildFooter()
	self._footer = New("Frame", {
		Name = "Footer",
		Size = UDim2.new(1, 0, 0, self._footerHeight),
		Position = UDim2.new(0, 0, 1, -self._footerHeight),
		BorderSizePixel = 0,
		Parent = self._root,
	})
	self._footerCorner = New("UICorner", {
		CornerRadius = UDim.new(0, self._cornerRadius),
		Parent = self._footer,
	})
	self:_bind(self._footer, { BackgroundColor3 = "Canvas" })
	self._footerLine = New("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 0, 0),
		BorderSizePixel = 0,
		Parent = self._footer,
	})
	self._footerLine.BackgroundTransparency = 0.45
	self:_bind(self._footerLine, { BackgroundColor3 = "BorderSubtle" })
	self._footerText = New("TextLabel", {
		Name = "FooterText",
		Size = UDim2.new(1, -112, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		Font = self.Fonts.Regular,
		TextSize = self.Tokens:Get("FontCaption"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = self._footer,
	})
	self:_bind(self._footerText, { TextColor3 = "TextTertiary" })
	self._footerHint = New("TextLabel", {
		Name = "ResizeHint",
		Size = UDim2.fromOffset(52, self._footerHeight),
		Position = UDim2.new(1, -42, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Font = self.Fonts.Medium,
		TextSize = self.Tokens:Get("FontCaption"),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "Resize",
		Parent = self._footer,
	})
	self:_bind(self._footerHint, { TextColor3 = "TextSecondary" })
	self:_refreshFooterText()
end

function WindowChrome:_refreshFooterText()
	if self._footerText then
		self._footerText.Text = if self._footerTextValue == nil
			then ""
			else self.Locale:Resolve(tostring(self._footerTextValue))
	end
end

function WindowChrome:SetFooterText(text)
	self._footerTextValue = if text == nil or text == false then nil else tostring(text)
	self:_refreshFooterText()
	return self
end

function WindowChrome:GetFooterText()
	return self._footerTextValue
end

function WindowChrome:_refreshChromeIcons()
	if self._brandGlyph and not self._brandGlyph:IsA("TextLabel") then
		Icon.setColor(self._brandGlyph, self.Theme:Get("Accent"))
	end
end

function WindowChrome:_refreshHeaderTitle()
	if self._layout == "Drawer" and self._active then
		self._titleLabel.Text = self.Locale:Resolve(self._active.Title)
	else
		self._titleLabel.Text = self.Title
	end
end

function WindowChrome:_flashThemeSwap()
	local flash = self._flash
	if not flash or not flash.Parent then
		return
	end
	flash.BackgroundColor3 = self.Theme:Get("Canvas")
	flash.BackgroundTransparency = 0.55
	flash.Visible = true
	local tween = self.Motion:Tween(flash, TweenInfo.new(FADE_TIME), { BackgroundTransparency = 1 }, "Window")
	if tween then
		tween.Completed:Once(function()
			flash.Visible = false
		end)
	else
		flash.Visible = false
	end
end

function WindowChrome:_refreshTopbarLayout()
	if not self._topbarExtras or not self._titleLabel then
		return
	end
	local count = 0
	for _, item in self._topbarItems do
		if item.Instance and item.Instance.Parent then
			count += 1
		end
	end
	local visible = count > 0 and self._layout ~= "Drawer" and self._root.AbsoluteSize.X >= 680
	self._topbarExtras.Visible = visible
	local titleLeft = if self._layout == "Drawer" then 48 else 52
	local reserve = if visible then 414 else 184
	self._titleLabel.Size = UDim2.new(
		1,
		-titleLeft - reserve,
		0,
		if self._subtitleLabel.Visible then 20 else self.Tokens:Get("HeaderHeight")
	)
end

function WindowChrome:AddTopbarButton(options)
	options = options or {}
	local w = self
	local item = { Id = options.Id or tostring(#self._topbarItems + 1), _window = self }
	local b = New("TextButton", {
		AutomaticSize = if options.Text then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
		Size = if options.Text then UDim2.fromOffset(0, 28) else UDim2.fromOffset(28, 28),
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = options.Text and ("  " .. tostring(options.Text) .. "  ") or "",
		Font = self.Fonts.Medium,
		TextSize = self.Tokens:Get("FontCaption"),
		LayoutOrder = options.Order or #self._topbarItems + 1,
		Parent = self._topbarExtras,
	})
	New("UICorner", { CornerRadius = UDim.new(0, self.Tokens:Get("CornerSm")), Parent = b })
	self:_bind(b, { BackgroundColor3 = "ControlHover", TextColor3 = "TextSecondary" })
	if options.Icon and not options.Text then
		item.Icon = Icon.new(self, options.Icon, {
			Size = UDim2.fromOffset(15, 15),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Parent = b,
		})
		Icon.setColor(item.Icon, self.Theme:Get("TextSecondary"))
	end
	self._janitor:Add(b.MouseButton1Click:Connect(function()
		if options.Callback then
			local ok, err = xpcall(options.Callback, debug.traceback, item)
			if not ok then
				warn(err)
			end
		end
	end))
	item.Instance = b
	function item:SetText(text)
		b.Text = "  " .. tostring(text or "") .. "  "
		return self
	end
	function item:SetVisible(v)
		b.Visible = v == true
		return self
	end
	function item:Destroy()
		if b and b.Parent then
			b:Destroy()
		end
		local p = table.find(w._topbarItems, self)
		if p then
			table.remove(w._topbarItems, p)
		end
		w:_refreshTopbarLayout()
	end
	table.insert(self._topbarItems, item)
	self:_refreshTopbarLayout()
	return item
end
function WindowChrome:AddTopbarTag(options)
	if type(options) == "string" then
		options = { Text = options }
	end
	options = options or {}
	local item = { Id = options.Id or tostring(#self._topbarItems + 1) }
	local label = New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Text = "  " .. tostring(options.Text or "") .. "  ",
		Font = self.Fonts.Medium,
		TextSize = self.Tokens:Get("FontCaption"),
		LayoutOrder = options.Order or #self._topbarItems + 1,
		Parent = self._topbarExtras,
	})
	New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = label })
	self:_bind(
		label,
		{ BackgroundColor3 = options.Token or "AccentSoft", TextColor3 = options.TextToken or "TextSecondary" }
	)
	item.Instance = label
	function item:SetText(text)
		label.Text = "  " .. tostring(text or "") .. "  "
		return self
	end
	function item:SetVisible(v)
		label.Visible = v == true
		return self
	end
	function item:Destroy()
		if label.Parent then
			label:Destroy()
		end
		local p = table.find(self._window and self._window._topbarItems or {}, self)
		if p and self._window then
			table.remove(self._window._topbarItems, p)
			self._window:_refreshTopbarLayout()
		end
	end
	item._window = self
	table.insert(self._topbarItems, item)
	self:_refreshTopbarLayout()
	return item
end
function WindowChrome:SetWindowOpacity(opacity)
	self._windowOpacity = math.clamp(tonumber(opacity) or 1, 0.25, 1)
	local tr = 1 - self._windowOpacity
	for _, obj in { self._root, self._header, self._navPanel, self._content, self._footer } do
		if obj then
			obj.BackgroundTransparency = tr
		end
	end
	return self
end
function WindowChrome:GetWindowOpacity()
	return self._windowOpacity
end
function WindowChrome:SetBackgroundImage(image, transparency, surfaceOpacity)
	if not self._backgroundImage then
		return self
	end
	if not image or image == "" then
		self._backgroundImage.Visible = false
		self._backgroundImage.Image = ""
		return self
	end
	self._backgroundImage.Image = tostring(image)
	self._backgroundImage.ImageTransparency = math.clamp(tonumber(transparency) or 0.18, 0, 1)
	self._backgroundImage.Visible = true
	if surfaceOpacity ~= nil then
		self:SetWindowOpacity(surfaceOpacity)
	elseif self._windowOpacity >= 0.999 then
		self:SetWindowOpacity(0.9)
	end
	return self
end
function WindowChrome:SetTabTransition(options)
	self._tabTransition = options or { Style = "None" }
	return self
end
function WindowChrome:SetWindowAnimation(options)
	self._windowAnimation = options or { Style = "None" }
	return self
end
function WindowChrome:SetAnimations(options, transitionTime, swipeOffset, swipeFrom)
	options = options or {}
	if options.ToggleWindow ~= nil then
		options.Window = options.ToggleWindow
	end
	if options.TabSwitch ~= nil then
		options.Tabs = options.TabSwitch
	end
	if options.Groupbox ~= nil or options.Dropdown ~= nil or options.KeyPicker ~= nil then
		options.Controls = options.Groupbox ~= false and options.Dropdown ~= false and options.KeyPicker ~= false
	end
	if options.All ~= nil then
		local enabled = options.All ~= false
		self._animationFlags.Window = enabled
		self._animationFlags.Tabs = enabled
		self._animationFlags.Controls = enabled
		self.Motion:SetCategory("Window", enabled)
		self.Motion:SetCategory("Tabs", enabled)
		self.Motion:SetCategory("Controls", enabled)
	end
	if options.Window ~= nil then
		self._animationFlags.Window = options.Window ~= false
		self.Motion:SetCategory("Window", options.Window ~= false)
	end
	if options.Tabs ~= nil then
		self._animationFlags.Tabs = options.Tabs ~= false
		self.Motion:SetCategory("Tabs", options.Tabs ~= false)
	end
	if options.Controls ~= nil then
		self._animationFlags.Controls = options.Controls ~= false
		self.Motion:SetCategory("Controls", options.Controls ~= false)
	end
	if transitionTime ~= nil or swipeOffset ~= nil or swipeFrom ~= nil then
		local transition = table.clone(self._tabTransition or {})
		transition.Duration = tonumber(transitionTime) or transition.Duration
		transition.Offset = tonumber(swipeOffset) or transition.Offset
		transition.Direction = swipeFrom or transition.Direction
		self:SetTabTransition(transition)
	end
	return self
end
function WindowChrome:SetAnimationEnabled(component, enabled)
	if component == "All" then
		return self:SetAnimations({ All = enabled })
	end
	if self._animationFlags[component] == nil then
		error("[BobloUI] animation component must be Window, Tabs, Controls, or All.", 2)
	end
	return self:SetAnimations({ [component] = enabled })
end
function WindowChrome:_shouldShowRestoreButton()
	if not self._showMobileButtons and self.Device.IsTouch then
		return false
	end
	if self._restoreMode == "Never" then
		return false
	end
	if self._restoreMode == "Always" then
		return true
	end
	if self._restoreMode == "Mobile" then
		return self.Device.IsTouch == true
	end
	if self._restoreMode == "Auto" then
		return true
	end
	return false
end
function WindowChrome:_refreshRestoreButton()
	local b = self._restoreButton
	if not b then
		return
	end
	b.Visible = (not self._visible) and self:_shouldShowRestoreButton()
end
function WindowChrome:SetRestoreButton(options)
	if options == false then
		self._restoreSpec = false
		self._restoreMode = "Never"
		self:_refreshRestoreButton()
		return self
	end
	options = options or {}
	self._restoreSpec = options
	local b = self._restoreButton
	if not b then
		return self
	end
	if options.Enabled == false then
		self._restoreMode = "Never"
	elseif options.Mode then
		self._restoreMode = options.Mode
	elseif next(options) ~= nil then
		self._restoreMode = "Always"
	elseif self._restoreMode == nil then
		self._restoreMode = "Always"
	end
	local custom = next(options) ~= nil
	if custom and options.Size then
		local size = options.Size
		if typeof(size) == "Vector2" then
			b.Size = UDim2.fromOffset(size.X, size.Y)
		elseif typeof(size) == "UDim2" then
			b.Size = size
		end
	elseif not custom then
		b.Size = UDim2.fromOffset(132, 32)
	end
	if custom and options.Position and typeof(options.Position) == "UDim2" then
		b.Position = options.Position
		b.AnchorPoint = options.AnchorPoint or b.AnchorPoint
	elseif not custom then
		if self._mobileButtonsSide == "Left" then
			b.Position = UDim2.new(0, 12, 0, math.max(12, self.Device.Insets.Top + 10))
			b.AnchorPoint = Vector2.new(0, 0)
		elseif self._mobileButtonsSide == "Right" then
			b.Position = UDim2.new(1, -12, 0, math.max(12, self.Device.Insets.Top + 10))
			b.AnchorPoint = Vector2.new(1, 0)
		else
			b.Position = UDim2.new(0.5, 0, 0, math.max(12, self.Device.Insets.Top + 10))
			b.AnchorPoint = Vector2.new(0.5, 0)
		end
	end
	if self._restoreIcon then
		self._restoreIcon:Destroy()
		self._restoreIcon = nil
	end
	if custom and options.Icon then
		b.Text = ""
		self._restoreIcon = Icon.new(self, options.Icon, {
			Size = UDim2.fromOffset(18, 18),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Parent = b,
		})
		Icon.setColor(self._restoreIcon, self.Theme:Get("Text"))
	else
		b.Text = tostring((custom and options.Text) or self._showText)
	end
	local c = self._restoreCorner or b:FindFirstChildOfClass("UICorner")
	if c then
		if custom and options.Shape == "Circle" then
			c.CornerRadius = UDim.new(1, 0)
		elseif custom and options.Shape == "Square" then
			c.CornerRadius = UDim.new(0, 3)
		else
			c.CornerRadius = UDim.new(0, self.Tokens:Get("CornerMd"))
		end
	end
	self._janitor:Remove("restoreDrag")
	local allowDrag = (not custom and true) or options.Draggable ~= false
	if allowDrag then
		local base = b.Position
		self._janitor:Add(
			self.Input:AttachDrag(b, function(delta)
				b.Position = UDim2.new(base.X.Scale, base.X.Offset + delta.X, base.Y.Scale, base.Y.Offset + delta.Y)
			end, function()
				if self._visible then
					return false
				end
				base = b.Position
				return true
			end),
			"Destroy",
			"restoreDrag"
		)
	end
	self:_refreshRestoreButton()
	return self
end
function WindowChrome:SetShowText(text)
	self._showTextExplicit = text ~= nil
	self._showText = tostring(text or "Show BobloUI")
	if self._restoreButton and not self._restoreIcon then
		self._restoreButton.Text = self._showText
	end
	return self
end

function WindowChrome:_animatedPosition(base, offset)
	local style = (self._windowAnimation and self._windowAnimation.Style) or "None"
	if style == "SlideLeft" then
		return UDim2.new(base.X.Scale, base.X.Offset - offset, base.Y.Scale, base.Y.Offset)
	elseif style == "SlideRight" then
		return UDim2.new(base.X.Scale, base.X.Offset + offset, base.Y.Scale, base.Y.Offset)
	elseif style == "SlideUp" then
		return UDim2.new(base.X.Scale, base.X.Offset, base.Y.Scale, base.Y.Offset - offset)
	else
		return UDim2.new(base.X.Scale, base.X.Offset, base.Y.Scale, base.Y.Offset + offset)
	end
end
function WindowChrome:Show()
	self._visibilityToken += 1
	local token = self._visibilityToken
	self._visible = true
	local root = self._root
	local target = self._hiddenRestPosition or root.Position
	self._hiddenRestPosition = nil
	root.Visible = true
	if self._restoreButton then
		self._restoreButton.Visible = false
	end
	local spec = self._windowAnimation or {}
	if self._layout ~= "Drawer" and self._animationFlags.Window ~= false and spec.Style ~= "None" then
		local offset = tonumber(spec.Offset) or 8
		root.Position = self:_animatedPosition(target, offset)
		self.Motion:Tween(
			root,
			TweenInfo.new(tonumber(spec.Duration) or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = target },
			"Window"
		)
	else
		root.Position = target
	end
	return self
end

function WindowChrome:Hide()
	if not self._visible then
		return self
	end
	self._visibilityToken += 1
	local token = self._visibilityToken
	self._visible = false
	self:CloseDrawer()
	local root = self._root
	local target = root.Position
	self._hiddenRestPosition = target
	local spec = self._windowAnimation or {}
	if self._layout ~= "Drawer" and self._animationFlags.Window ~= false and spec.Style ~= "None" then
		local tween = self.Motion:Tween(
			root,
			TweenInfo.new(tonumber(spec.Duration) or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = self:_animatedPosition(target, tonumber(spec.Offset) or 8) },
			"Window"
		)
		if tween then
			tween.Completed:Once(function()
				if self._visibilityToken == token and not self._visible then
					root.Visible = false
					root.Position = target
					self:_refreshRestoreButton()
				end
			end)
		else
			root.Visible = false
			root.Position = target
			self:_refreshRestoreButton()
		end
	else
		root.Visible = false
		self:_refreshRestoreButton()
	end
	return self
end

function WindowChrome:Toggle()
	if self._visible then
		self:Hide()
	else
		self:Show()
	end
	return self
end

function WindowChrome:IsVisible(): boolean
	return self._visible
end

function WindowChrome:SetTitle(title: string)
	self.Title = title
	if self._brandGlyph and self._brandGlyph:IsA("TextLabel") then
		self._brandGlyph.Text = title:sub(1, 1):upper()
	end
	self:_refreshHeaderTitle()
	return self
end

function WindowChrome:SetIcon(icon)
	self.Icon = icon
	if self._brandGlyph then
		self._brandGlyph:Destroy()
		self._brandGlyph = nil
	end
	if not self._brandMark then
		return self
	end
	if icon then
		self._brandGlyph = Icon.new(self, icon, {
			Size = UDim2.fromOffset(15, 15),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Parent = self._brandMark,
		})
		Icon.setColor(self._brandGlyph, self.Theme:Get("Accent"))
	else
		self._brandGlyph = New("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = self.Fonts.Bold,
			TextSize = 14,
			Text = self.Title:sub(1, 1):upper(),
			Parent = self._brandMark,
		})
		self:_bind(self._brandGlyph, { TextColor3 = "Accent" })
	end
	self:_refreshChromeIcons()
	return self
end

function WindowChrome:SetSubtitle(text: string?)
	self.Subtitle = text
	self._subtitleLabel.Text = text or ""
	self._subtitleLabel.Visible = text ~= nil and self._layout ~= "Drawer"
	self:_applyTokens()
	return self
end

return WindowChrome
