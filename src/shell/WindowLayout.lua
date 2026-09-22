--!nonstrict
-- Window geometry, responsive layout, drawer, drag, and resize behavior.

local Create = require("@runtime/Create")
local Icon = require("@primitives/Icon")

local New = Create.New
local WindowLayout = {}
local DRAWER_TIME = 0.18

function WindowLayout:_buildBody()
	local tokens = self.Tokens

	self._body = New("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 1, -(tokens:Get("HeaderHeight") + self._footerHeight)),
		Position = UDim2.new(0, 0, 0, tokens:Get("HeaderHeight")),
		BackgroundTransparency = 1,
		Parent = self._root,
	})

	self._navPanel = New("Frame", {
		Name = "Nav",
		Size = UDim2.new(0, self._sidebarWidth, 1, 0),
		BorderSizePixel = 0,
		Parent = self._body,
	})
	self:_bind(self._navPanel, { BackgroundColor3 = "Sidebar" })

	self._navLine = New("Frame", {
		Name = "Divider",
		Size = UDim2.new(0, 1, 1, 0),
		Position = UDim2.new(1, -1, 0, 0),
		BorderSizePixel = 0,
		Parent = self._navPanel,
	})
	self._navLine.BackgroundTransparency = 0.45
	self:_bind(self._navLine, { BackgroundColor3 = "BorderSubtle" })
	self._sidebarGrip = New("TextButton", {
		Name = "SidebarResizeGrip",
		Size = UDim2.new(0, 8, 1, 0),
		Position = UDim2.new(1, -4, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 8,
		Parent = self._navPanel,
	})
	self._janitor:Add(self._sidebarGrip.InputBegan:Connect(function(input)
		if
			not self._sidebarResizeEnabled
			or self._layout ~= "Wide"
			or self._sidebarHidden
			or (
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			)
		then
			return
		end
		local start = input.Position
		local width = self._sidebarWidth
		self.Input:CapturePointer(self._sidebarGrip, input, function(move)
			self:SetSidebarWidth(width + (move.Position.X - start.X) / math.max(0.01, self._scale or 1))
		end, function() end)
	end))

	-- Reparented between _navPanel and the drawer. Never rebuilt.
	self._navList = New("Frame", {
		Name = "NavList",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = self._navPanel,
	})
	New("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = self._navList,
	})
	Create.List(2).Parent = self._navList

	-- Sidebar header: brand mark + title + subtitle (absolute positioning, no list layout)
	local sidebarHeader = New("Frame", {
		Name = "SidebarHeader",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = -1000,
		Parent = self._navList,
	})

	-- Brand mark in sidebar
	self._sidebarBrand = New("Frame", {
		Name = "BrandMark",
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.fromOffset(0, 6),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Parent = sidebarHeader,
	})
	New("UICorner", { CornerRadius = UDim.new(0, tokens:Get("CornerSm")), Parent = self._sidebarBrand })
	local brandStroke = New("UIStroke", { Thickness = 1, Transparency = 0.46, Parent = self._sidebarBrand })
	self:_bind(self._sidebarBrand, { BackgroundColor3 = "AccentSoft" })
	self:_bind(brandStroke, { Color = "AccentBorder" })
	self._sidebarBrandDot = New("Frame", {
		Name = "StatusDot",
		Size = UDim2.fromOffset(5, 5),
		Position = UDim2.new(1, -1, 0, 1),
		AnchorPoint = Vector2.new(1, 0),
		BorderSizePixel = 0,
		Parent = self._sidebarBrand,
	})
	New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self._sidebarBrandDot })
	self:_bind(self._sidebarBrandDot, { BackgroundColor3 = "Accent" })
	if self.Icon then
		self._sidebarBrandGlyph = Icon.new(self, self.Icon, {
			Size = UDim2.fromOffset(15, 15),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Parent = self._sidebarBrand,
		})
		Icon.setColor(self._sidebarBrandGlyph, self.Theme:Get("Accent"))
	else
		self._sidebarBrandGlyph = New("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = self.Fonts.Bold,
			TextSize = 14,
			Text = self.Title:sub(1, 1):upper(),
			Parent = self._sidebarBrand,
		})
		self:_bind(self._sidebarBrandGlyph, { TextColor3 = "Accent" })
	end

	-- Title in sidebar (right of brand mark)
	self._sidebarTitle = New("TextLabel", {
		Name = "SidebarTitle",
		Size = UDim2.new(1, -36, 0, 16),
		Position = UDim2.fromOffset(34, 6),
		BackgroundTransparency = 1,
		Font = self.Fonts.Bold,
		TextSize = tokens:Get("FontBody"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = self.Title,
		Parent = sidebarHeader,
	})
	self:_bind(self._sidebarTitle, { TextColor3 = "Text" })

	-- Subtitle in sidebar (below title)
	self._sidebarSubtitle = New("TextLabel", {
		Name = "SidebarSubtitle",
		Size = UDim2.new(1, -36, 0, 12),
		Position = UDim2.fromOffset(34, 22),
		BackgroundTransparency = 1,
		Font = self.Fonts.Regular,
		TextSize = tokens:Get("FontCaption"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = self.Subtitle or "",
		Visible = self.Subtitle ~= nil and not self._minimal,
		Parent = sidebarHeader,
	})
	self:_bind(self._sidebarSubtitle, { TextColor3 = "TextTertiary" })

	-- Divider after sidebar header
	local sidebarDivider = New("Frame", {
		Name = "SidebarDivider",
		Size = UDim2.new(1, 0, 0, 1),
		BorderSizePixel = 0,
		LayoutOrder = -999,
		Parent = self._navList,
	})
	sidebarDivider.BackgroundTransparency = 0.5
	self:_bind(sidebarDivider, { BackgroundColor3 = "BorderSubtle" })

	self._content = New("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -self._sidebarWidth, 1, 0),
		Position = UDim2.new(0, self._sidebarWidth, 0, 0),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = self._body,
	})
	self:_bind(self._content, { BackgroundColor3 = "Canvas" })
	self._janitor:Add(self._content:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_scheduleSectionLayouts()
	end))
end

function WindowLayout:_buildResizeGrip()
	self._grip = New("TextButton", {
		Name = "ResizeGrip",
		Size = UDim2.fromOffset(32, self._footerHeight - 4),
		Position = UDim2.new(1, -4, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 5,
		Parent = self._footer,
	})
	New("UICorner", { CornerRadius = UDim.new(0, 6), Parent = self._grip })
	self:_bind(self._grip, { BackgroundColor3 = "ControlHover" })
	local glyph = New("Frame", {
		Name = "CornerGlyph",
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = self._grip,
	})
	for index, spec in
		{
			{ Length = 12, Position = UDim2.fromOffset(10, 10) },
			{ Length = 8, Position = UDim2.fromOffset(12, 12) },
			{ Length = 4, Position = UDim2.fromOffset(14, 14) },
		}
	do
		local line = New("Frame", {
			Name = `GripLine{index}`,
			Size = UDim2.fromOffset(spec.Length, 2),
			Position = spec.Position,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = -45,
			BorderSizePixel = 0,
			Parent = glyph,
		})
		New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = line })
		self:_bind(line, { BackgroundColor3 = "TextSecondary" })
	end
	self._janitor:Add(self._grip.MouseEnter:Connect(function()
		self._grip.BackgroundTransparency = 0.8
	end))
	self._janitor:Add(self._grip.MouseLeave:Connect(function()
		self._grip.BackgroundTransparency = 1
	end))

	self._janitor:Add(self._grip.InputBegan:Connect(function(input)
		if self._layout == "Drawer" or self._locked then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		local startPosition = input.Position
		local scale = math.max(0.01, self._scale or 1)
		local startSize = self._root.AbsoluteSize / scale
		self.Input:CapturePointer(self._grip, input, function(move)
			local delta = (move.Position - startPosition) / scale
			local _, safeSize = self.Device:SafeArea()
			local maxWidth = math.max(320, (safeSize.X - 40) / scale)
			local maxHeight = math.max(260, (safeSize.Y - 40) / scale)
			local minWidth = math.min(math.max(self._minSize.X, self._minContainerWidth), maxWidth)
			local minHeight = math.min(self._minSize.Y, maxHeight)
			local width = math.clamp(startSize.X + delta.X, minWidth, maxWidth)
			local height = math.clamp(startSize.Y + delta.Y, minHeight, maxHeight)
			self._size = UDim2.fromOffset(width, height)
			if self._layout ~= "Drawer" then
				self._root.Size = self._size
			end
			self:_scheduleSectionLayouts()
		end, function()
			self:_scheduleSectionLayouts()
		end)
	end))
end

function WindowLayout:_attachDrag(handle: GuiObject)
	local startPosition
	local dragJanitor = self.Input:AttachDrag(handle, function(delta)
		if not startPosition then
			return
		end
		self._root.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end, function()
		if self._layout == "Drawer" or self._locked then
			return false
		end
		startPosition = self._root.Position
		return true
	end)
	self._janitor:Add(dragJanitor)
end

-- ===== layout ====================================================

function WindowLayout:_scheduleSectionLayouts()
	if self._sectionLayoutPending or self._destroying then
		return
	end
	self._sectionLayoutPending = true
	local thread = task.defer(function()
		self._sectionLayoutPending = false
		if self._destroying then
			return
		end
		for _, tab in self._tabs do
			tab:_applySectionLayout(self._layout)
		end
		if self._minimal then
			self:_syncMinimalHeight()
		end
	end)
	self._janitor:Add(thread, nil, "sectionLayoutsTask")
end

function WindowLayout:_applyLayout(layout: string, initial: boolean?)
	if self._layout == layout and not initial then
		return
	end
	self._layout = layout
	if self._minimal then
		self:_applyMinimalLayout()
		return
	end

	if not initial then
		self.Layers:DismissAll()
	end
	self:CloseDrawer()

	local drawerMode = layout == "Drawer"
	local railMode = layout == "Rail"

	self._navToggle.Visible = drawerMode
	self._sidebarButton.Visible = true
	self._grip.Visible = not drawerMode and not self._locked
	if self._footer then
		self._footer.Visible = not drawerMode and self._footerTextValue ~= nil
	end
	self._navPanel.Visible = not drawerMode and not self._sidebarHidden
	if self._sidebarGrip then
		self._sidebarGrip.Visible = self._sidebarResizeEnabled and layout == "Wide" and not self._sidebarHidden
	end
	self._subtitleLabel.Visible = self.Subtitle ~= nil and not drawerMode

	if self._navList.Parent ~= self._navPanel then
		self._navList.Parent = self._navPanel
	end

	self:_refreshGroups()
	for _, tab in self._tabs do
		tab:_applySectionLayout(layout)
		tab._label.Visible = not railMode and not self._sidebarHidden
		if tab._badge then
			tab._badge.Visible = not railMode and not self._sidebarHidden
		end
		if tab._avatar then
			if railMode then
				tab._avatar.Position = UDim2.fromScale(0.5, 0.5)
				tab._avatar.AnchorPoint = Vector2.new(0.5, 0.5)
			else
				local t = self.Tokens
				tab._avatar.Position = UDim2.new(0, 8, 0.5, 0)
				tab._avatar.AnchorPoint = Vector2.new(0, 0.5)
			end
		end
	end

	self:_applyTokens()
	self:_applyGeometry()
	self:_refreshHeaderTitle()
	self:_refreshTopbarLayout()
end

--- Re-reads every metric from Tokens. Called on density change and on layout
--- change; never rebuilds Instances.
function WindowLayout:_applyTokens()
	if self._minimal then
		self:_applyMinimalTokens()
		return
	end
	local tokens = self.Tokens
	local layout = self._layout
	local drawerMode = layout == "Drawer"
	local railMode = layout == "Rail"

	local navWidth = if self._sidebarHidden and not drawerMode
		then 0
		elseif railMode then self._sidebarCompactWidth
		else self._sidebarWidth
	local headerHeight = tokens:Get("HeaderHeight")

	self._header.Size = UDim2.new(1, 0, 0, headerHeight)
	self._body.Size = UDim2.new(1, 0, 1, -(headerHeight + self._footerHeight))
	self._body.Position = UDim2.new(0, 0, 0, headerHeight)
	if self._footer then
		self._footer.Size = UDim2.new(1, 0, 0, self._footerHeight)
		self._footer.Position = UDim2.new(0, 0, 1, -self._footerHeight)
	end
	self:_applyCornerRadius()

	self._titleLabel.TextSize = tokens:Get("FontTitle")
	self._subtitleLabel.TextSize = tokens:Get("FontSmall")
	if self._footerHint then
		self._footerHint.TextSize = tokens:Get("FontCaption")
	end
	if self._footerText then
		self._footerText.TextSize = tokens:Get("FontCaption")
	end
	self._rootStroke.Thickness = tokens:Get("Stroke")

	local titleLeft = if drawerMode then 48 else 52
	self._brandMark.Visible = not drawerMode
	self._titleLabel.Position = UDim2.new(0, titleLeft, 0, if self._subtitleLabel.Visible then 9 else 0)
	self._titleLabel.Size = UDim2.new(1, -titleLeft - 184, 0, if self._subtitleLabel.Visible then 20 else headerHeight)
	self._subtitleLabel.Position = UDim2.new(0, titleLeft, 0, 29)

	if drawerMode then
		self._content.Size = UDim2.fromScale(1, 1)
		self._content.Position = UDim2.new()
	else
		self._navPanel.Size = UDim2.new(0, navWidth, 1, 0)
		self._content.Size = UDim2.new(1, -navWidth, 1, 0)
		self._content.Position = UDim2.new(0, navWidth, 0, 0)
	end

	for _, g in self._groups do
		if g.Label then
			g.Label.TextSize = tokens:Get("FontCaption")
		end
	end
	for _, tab in self._tabs do
		tab:_applyTokens()
		tab._button.Size = UDim2.new(1, 0, 0, tokens:Get("NavItemHeight"))
		tab._label.TextSize = tokens:Get("FontBody")
	end
	self:_refreshTopbarLayout()
	self:_scheduleSectionLayouts()
end

function WindowLayout:_applyGeometry()
	if self._minimal then
		self._root.AnchorPoint = Vector2.new(0.5, 0.5)
		local _, safeSize = self.Device:SafeArea()
		local scale = math.max(0.01, self._scale or 1)
		local width = math.min(math.max(1, self._size.X.Offset), math.max(1, safeSize.X / scale - 16))
		self._root.Size = UDim2.fromOffset(width, self._root.Size.Y.Offset)
		self:_syncMinimalHeight()
		self:_scheduleSectionLayouts()
		return
	end
	if self._layout == "Drawer" then
		local position, size = self.Device:SafeArea()
		self._root.AnchorPoint = Vector2.new(0, 0)
		self._root.Position = UDim2.fromOffset(position.X, position.Y)
		self._root.Size = UDim2.fromOffset(size.X, size.Y)
	else
		self._root.AnchorPoint = Vector2.new(0.5, 0.5)
		if self._root.Position.X.Scale == 0 then
			self._root.Position = UDim2.fromScale(0.5, 0.5)
		end
		local _, safeSize = self.Device:SafeArea()
		local scale = math.max(0.01, self._scale or 1)
		local maxWidth = math.max(self._minContainerWidth, (safeSize.X - 40) / scale)
		local maxHeight = math.max(260, (safeSize.Y - 40) / scale)
		self._root.Size =
			UDim2.fromOffset(math.min(self._size.X.Offset, maxWidth), math.min(self._size.Y.Offset, maxHeight))
	end
	self:_refreshTopbarLayout()
	self:_scheduleSectionLayouts()
end

function WindowLayout:OpenDrawer()
	if self._drawer or self._layout ~= "Drawer" then
		return
	end

	local tokens = self.Tokens
	local width = math.min(self._sidebarWidth, self.Device.Viewport.X - 60)

	local handle = self.Layers:Push({
		Scrim = true,
		OnDismiss = function()
			self._drawer = nil
			if self._navList and self._navList.Parent ~= self._navPanel then
				self._navList.Parent = self._navPanel
			end
		end,
	})

	local panel = New("Frame", {
		Name = "Drawer",
		Size = UDim2.new(0, width, 1, 0),
		Position = UDim2.fromOffset(-width, 0),
		BorderSizePixel = 0,
		Parent = handle.Container,
	})
	self:_bind(panel, { BackgroundColor3 = "Sidebar" })

	self._navList.Parent = panel

	self.Motion:Tween(panel, TweenInfo.new(DRAWER_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(0, 0),
	}, "Window")

	self._drawer = handle
end

function WindowLayout:CloseDrawer()
	if self._drawer then
		self._drawer:Dismiss()
		self._drawer = nil
	end
end

function WindowLayout:SetLocked(locked)
	self._locked = locked == true
	if self._grip then
		self._grip.Visible = not self._locked and self._layout ~= "Drawer" and not self._minimal
	end
	if self._footerHint then
		self._footerHint.Visible = not self._locked and self._layout ~= "Drawer" and not self._minimal
	end
	return self
end
function WindowLayout:IsLocked()
	return self._locked == true
end
function WindowLayout:SetRememberGeometry(enabled)
	self._rememberGeometry = enabled ~= false
	return self
end
function WindowLayout:GetRememberGeometry()
	return self._rememberGeometry
end
function WindowLayout:SetSidebarHidden(hidden)
	self._sidebarHidden = hidden == true
	self:_applyLayout(self._layout, true)
	return self
end
function WindowLayout:IsSidebarHidden()
	return self._sidebarHidden == true
end
function WindowLayout:ToggleSidebar()
	return self:SetSidebarHidden(not self._sidebarHidden)
end
function WindowLayout:SetSidebarWidth(width)
	if type(width) ~= "number" then
		error("[BobloUI] Window:SetSidebarWidth expects number.", 2)
	end
	local scale = math.max(0.01, self._scale or 1)
	local rootWidth = self._root.AbsoluteSize.X / scale
	if rootWidth < 320 then
		rootWidth = math.max(self._minContainerWidth, self._size.X.Offset)
	end
	local maxWidth = math.max(self._minSidebarWidth, math.min(420, rootWidth - 260))
	self._sidebarWidth = math.clamp(math.floor(width + 0.5), self._minSidebarWidth, maxWidth)
	self:_applyTokens()
	return self
end
function WindowLayout:GetSidebarWidth()
	return self._sidebarWidth
end
function WindowLayout:SetSidebarResizeEnabled(enabled)
	self._sidebarResizeEnabled = enabled ~= false
	if self._sidebarGrip then
		self._sidebarGrip.Visible = self._sidebarResizeEnabled and self._layout == "Wide" and not self._sidebarHidden
	end
	return self
end
function WindowLayout:SetCompact(enabled)
	self.Tokens:SetDensity(if enabled then "Compact" else "Comfortable")
	return self
end
function WindowLayout:IsCompact()
	return self.Tokens:GetDensity() == "Compact"
end
function WindowLayout:SetSidebarCompacted(enabled)
	self._sidebarCompacted = enabled == true
	self:_applyLayout(self:_responsiveLayout(), true)
	return self
end
function WindowLayout:IsSidebarCompacted()
	return self._sidebarCompacted == true
end
function WindowLayout:SetResponsiveThresholds(options)
	options = options or {}
	if options.MinContainerWidth ~= nil then
		self._minContainerWidth = math.max(320, tonumber(options.MinContainerWidth) or self._minContainerWidth)
	end
	if options.MinSidebarWidth ~= nil then
		self._minSidebarWidth = math.max(96, tonumber(options.MinSidebarWidth) or self._minSidebarWidth)
	end
	if options.SidebarCompactWidth ~= nil then
		self._sidebarCompactWidth = math.max(48, tonumber(options.SidebarCompactWidth) or self._sidebarCompactWidth)
	end
	if options.SidebarCollapseThreshold ~= nil then
		self._sidebarCollapseThreshold =
			math.max(320, tonumber(options.SidebarCollapseThreshold) or self._sidebarCollapseThreshold)
	end
	if options.CompactWidthActivation ~= nil then
		self._compactWidthActivation =
			math.max(360, tonumber(options.CompactWidthActivation) or self._compactWidthActivation)
	end
	if options.EnableCompacting ~= nil then
		self._enableCompacting = options.EnableCompacting ~= false
	end
	if options.DisableCompactingSnap ~= nil then
		self._disableCompactingSnap = options.DisableCompactingSnap == true
	end
	self:_applyLayout(self:_responsiveLayout(), true)
	return self
end
function WindowLayout:SetSearchEnabled(enabled)
	self._disableSearch = enabled == false
	if self._searchButton then
		self._searchButton.Visible = not self._disableSearch and not self._minimal
	end
	return self
end
function WindowLayout:SetGlobalSearch(enabled)
	self._globalSearch = enabled ~= false
	return self
end
function WindowLayout:SetSearchbarSize(size)
	if size ~= nil and type(size) ~= "number" and typeof(size) ~= "UDim2" then
		error("[BobloUI] Window:SetSearchbarSize expects number, UDim2, or nil.", 2)
	end
	self._searchbarSize = size
	return self
end
function WindowLayout:SetTabSwipe(offset, from)
	local transition = table.clone(self._tabTransition or {})
	transition.Offset = math.max(0, tonumber(offset) or tonumber(transition.Offset) or 10)
	transition.Direction = from or transition.Direction or "Right"
	return self:SetTabTransition(transition)
end
function WindowLayout:SetFont(font)
	local previous = self.Fonts
	local nextFonts
	if type(font) == "table" then
		nextFonts = {
			Regular = font.Regular or previous.Regular,
			Medium = font.Medium or font.Regular or previous.Medium,
			Bold = font.Bold or font.Medium or font.Regular or previous.Bold,
			Heavy = font.Heavy or font.Bold or font.Medium or font.Regular or previous.Heavy,
		}
	else
		local resolved = font
		if type(font) == "string" then
			local ok, enum = pcall(function()
				return Enum.Font[font]
			end)
			resolved = if ok then enum else nil
		end
		if typeof(resolved) ~= "EnumItem" or resolved.EnumType ~= Enum.Font then
			error("[BobloUI] Window:SetFont expects Enum.Font, font name, or font table.", 2)
		end
		nextFonts = { Regular = resolved, Medium = resolved, Bold = resolved, Heavy = resolved }
	end
	local replacements = {
		[previous.Regular] = nextFonts.Regular,
		[previous.Medium] = nextFonts.Medium,
		[previous.Bold] = nextFonts.Bold,
		[previous.Heavy] = nextFonts.Heavy,
	}
	self.Fonts = nextFonts
	for _, screen in { self.Layers.Root, self.Layers.Overlay, self.Layers.Toast } do
		for _, instance in screen:GetDescendants() do
			if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
				instance.Font = replacements[instance.Font] or nextFonts.Regular
			end
		end
	end
	return self
end
function WindowLayout:GetFont()
	return table.clone(self.Fonts)
end
function WindowLayout:SetCornerRadius(radius)
	if type(radius) == "boolean" then
		radius = if radius then self.Tokens:Get("CornerLg") else 0
	end
	if type(radius) ~= "number" then
		error("[BobloUI] Window:SetCornerRadius expects number.", 2)
	end
	self._cornerRadius = math.max(0, math.floor(radius + 0.5))
	self:_applyCornerRadius()
	return self
end

function WindowLayout:_applyCornerRadius()
	local value = UDim.new(0, self._cornerRadius)
	for _, corner in
		{
			self._rootCorner,
			self._headerCorner,
			self._footerCorner,
			self._backgroundImageCorner,
			self._flashCorner,
		}
	do
		if corner then
			corner.CornerRadius = value
		end
	end
end
function WindowLayout:SetRounded(enabled)
	return self:SetCornerRadius(enabled and self.Tokens:Get("CornerLg") or 0)
end
function WindowLayout:GetCornerRadius()
	return self._cornerRadius
end
function WindowLayout:SetSize(size)
	if typeof(size) == "Vector2" then
		size = UDim2.fromOffset(size.X, size.Y)
	end
	if typeof(size) ~= "UDim2" then
		error("[BobloUI] Window:SetSize expects UDim2 or Vector2.", 2)
	end
	self._size = size
	if self._minimal then
		self:_applyGeometry()
		return self
	end
	if self._layout ~= "Drawer" then
		self._root.Size = size
	end
	self:_scheduleSectionLayouts()
	return self
end
function WindowLayout:SetPosition(position)
	if typeof(position) ~= "UDim2" then
		error("[BobloUI] Window:SetPosition expects UDim2.", 2)
	end
	self._root.Position = position
	return self
end
function WindowLayout:GetGeometry()
	return {
		Size = self._size,
		Position = self._root.Position,
		Scale = self._scale,
		Locked = self._locked,
		Remember = self._rememberGeometry,
		SidebarWidth = self._sidebarWidth,
		SidebarHidden = self._sidebarHidden,
		Compact = self:IsCompact(),
		SidebarCompacted = self:IsSidebarCompacted(),
	}
end
function WindowLayout:ResetGeometry()
	self._size = if self._minimal then UDim2.fromOffset(340, 0) else UDim2.fromOffset(720, 480)
	self._root.Position = UDim2.fromScale(0.5, 0.5)
	if self._layout ~= "Drawer" then
		if self._minimal then
			self:_applyGeometry()
		else
			self._root.Size = self._size
		end
	end
	self:SetScale(1)
	self:SetLocked(false)
	self:SetCompact(false)
	self:SetSidebarCompacted(false)
	self:SetSidebarWidth(self.Tokens:Get("SidebarWidth"))
	self:SetSidebarHidden(false)
	return self
end
function WindowLayout:Minimize()
	return self:Hide()
end
function WindowLayout:Restore()
	return self:Show()
end
function WindowLayout:ResetAll()
	self.State:Batch(function()
		for _, entry in self.Registry:GetPersistable() do
			if entry.Id then
				self.State:Reset(entry.Id, { Source = "RESET" })
			end
		end
	end)
	return self
end

return WindowLayout
