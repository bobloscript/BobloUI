--!nonstrict
-- Tab navigation, lazy page mounting, and responsive section placement.

local Create = require("@runtime/Create")
local Janitor = require("@runtime/Janitor")
local Util = require("@runtime/Util")
local Section = require("@shell/Section")
local Icon = require("@primitives/Icon")
local Badge = require("@primitives/Badge")

local New = Create.New

local Tab = {}
Tab.__index = Tab

function Tab.new(window, options)
	local self = setmetatable({
		Id = options.Id or Util.slug(options.Title),
		Title = options.Title,
		Description = options.Description,
		Icon = options.Icon,
		Badge = options.Badge,
		Group = options.Group,
		Locked = options.Locked == true,
		LockedReason = options.LockedReason,
		Order = options.Order or (#window._tabs + 1),

		_window = window,
		_janitor = Janitor.new(`Tab[{options.Title}]`),
		_mounted = false,
		_selected = false,
		_sections = {},
		_defaultSection = nil,
		_twoColumn = false,
		_layoutPending = false,
	}, Tab)

	window._janitor:Add(self, "Destroy", self)

	local tokens = window.Tokens

	-- Nav entry ---------------------------------------------------
	local button = New("TextButton", {
		Name = `Nav_{self.Id}`,
		Size = UDim2.new(1, 0, 0, tokens:Get("NavItemHeight")),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = window:_navLayoutOrder(self.Group, self.Order),
		Visible = options.Visible ~= false,
		Parent = window._navList,
	})
	New("UICorner", { CornerRadius = UDim.new(0, tokens:Get("CornerSm")), Parent = button })
	local indicator = New("Frame", {
		Name = "Indicator",
		Size = UDim2.fromOffset(3, 20),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BorderSizePixel = 0,
		Visible = false,
		Parent = button,
	})
	New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = indicator })
	window:_bind(indicator, { BackgroundColor3 = "Accent" })
	self._indicator = indicator
	self._janitor:Add(button)

	-- A small icon tile makes every destination identifiable before its label is
	-- read, and keeps rail mode from feeling like a row of loose glyphs.
	local avatarBack = New("Frame", {
		Name = "IconTile",
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(0, 6, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BorderSizePixel = 0,
		BackgroundTransparency = 0.82,
		Parent = button,
	})
	New("UICorner", { CornerRadius = UDim.new(0, 7), Parent = avatarBack })
	local avatarStroke = New("UIStroke", { Thickness = 1, Transparency = 0.68, Parent = avatarBack })
	window:_bind(avatarBack, { BackgroundColor3 = "AccentSoft" })
	window:_bind(avatarStroke, { Color = "AccentBorder" })

	-- Built-in vector icons keep navigation consistent even without external assets.
	local avatarProps = {
		Name = "Avatar",
		Size = UDim2.fromOffset(tokens:Get("IconMd"), tokens:Get("IconMd")),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = avatarBack,
	}
	local avatar = Icon.new(window, options.Icon or "star", avatarProps)

	local label = New("TextLabel", {
		Name = "Label",
		Size = UDim2.new(1, -48, 1, 0),
		Position = UDim2.new(0, 40, 0, 0),
		BackgroundTransparency = 1,
		Font = window.Fonts.Medium,
		TextSize = tokens:Get("FontBody"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = window.Locale:Resolve(options.Title),
		Parent = button,
	})

	window:_bind(button, { BackgroundColor3 = "SurfaceHover" })
	window:_bind(label, { TextColor3 = "TextSecondary" })

	self._button = button
	self._avatarBack = avatarBack
	self._avatarStroke = avatarStroke
	self._avatar = avatar
	self._label = label
	self._badge = nil
	if options.Badge then
		self:SetBadge(options.Badge)
	end

	self._janitor:Add(button.MouseEnter:Connect(function()
		self:_applyNavVisual(true)
	end))
	self._janitor:Add(button.MouseLeave:Connect(function()
		self:_applyNavVisual(false)
	end))
	self._janitor:Add(button.MouseButton1Click:Connect(function()
		if self.Locked then
			if window.Notify then
				window.Notify:Push({
					Title = self.Title,
					Content = self.LockedReason or "This tab is locked",
					Variant = "Warning",
					Duration = 3,
				})
			end
			return
		end
		self:Select()
	end))

	-- Page --------------------------------------------------------
	self._page = New("ScrollingFrame", {
		Name = `Page_{self.Id}`,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		ScrollBarImageTransparency = 0.4,
		ClipsDescendants = true,
		Parent = window._content,
	})
	self._janitor:Add(self._page)

	self._pagePadding = New("UIPadding", {
		PaddingTop = UDim.new(0, tokens:Get("PagePadding")),
		PaddingBottom = UDim.new(0, tokens:Get("PagePadding")),
		PaddingLeft = UDim.new(0, 0),
		PaddingRight = UDim.new(0, 0),
		Parent = self._page,
	})
	-- Keep a 12 px visual gap below the 34 px icon when a tab has no description.
	-- Tabs with a description already end at y=42 inside a 54 px intro.
	self._introHeight = if window._minimal then 0 elseif self.Description then 54 else 46
	local pagePadding = tokens:Get("PagePadding")
	self._pageIntro = New("Frame", {
		Name = "PageIntro",
		Size = UDim2.new(1, -(pagePadding * 2), 0, self._introHeight),
		Position = UDim2.fromOffset(pagePadding, 0),
		BackgroundTransparency = 1,
		Parent = self._page,
	})
	self._pageIntro.Visible = not window._minimal
	self._pageIconBack = New("Frame", {
		Name = "PageIconTile",
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.fromOffset(0, 0),
		BorderSizePixel = 0,
		Parent = self._pageIntro,
	})
	New("UICorner", { CornerRadius = UDim.new(0, 10), Parent = self._pageIconBack })
	local pageIconStroke = New("UIStroke", { Thickness = 1, Transparency = 0.55, Parent = self._pageIconBack })
	window:_bind(self._pageIconBack, { BackgroundColor3 = "AccentSoft" })
	window:_bind(pageIconStroke, { Color = "AccentBorder" })
	self._pageIcon = Icon.new(window, options.Icon or "star", {
		Name = "PageIcon",
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = self._pageIconBack,
	})
	Icon.setColor(self._pageIcon, window.Theme:Get("Accent"))
	self._pageTitle = New("TextLabel", {
		Size = UDim2.new(1, -46, 0, 22),
		Position = UDim2.fromOffset(46, 0),
		BackgroundTransparency = 1,
		Font = window.Fonts.Bold,
		TextSize = tokens:Get("FontHeading"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = window.Locale:Resolve(self.Title),
		Parent = self._pageIntro,
	})
	window:_bind(self._pageTitle, { TextColor3 = "Text" })
	if self.Description then
		self._pageDescription = New("TextLabel", {
			Size = UDim2.new(1, -46, 0, 16),
			Position = UDim2.fromOffset(46, 26),
			BackgroundTransparency = 1,
			Font = window.Fonts.Regular,
			TextSize = tokens:Get("FontSmall"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = window.Locale:Resolve(self.Description),
			Parent = self._pageIntro,
		})
		window:_bind(self._pageDescription, { TextColor3 = "TextTertiary" })
	end
	self._sectionHost = New("Frame", {
		Name = "SectionHost",
		Size = UDim2.new(1, -(pagePadding * 2), 0, 0),
		Position = UDim2.fromOffset(pagePadding, self._introHeight),
		AutomaticSize = Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = self._page,
	})
	self._emptyState = New("TextLabel", {
		Name = "EmptyState",
		Size = UDim2.new(1, -(pagePadding * 2), 0, 54),
		Position = UDim2.fromOffset(pagePadding, self._introHeight + 24),
		BackgroundTransparency = 1,
		Font = window.Fonts.Regular,
		TextSize = tokens:Get("FontBody"),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		Text = "Nothing here yet",
		Visible = false,
		Parent = self._page,
	})
	window:_bind(self._emptyState, { TextColor3 = "TextTertiary" })
	self._column1 = New("Frame", {
		Name = "Column1",
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = self._sectionHost,
	})
	self._column2 = New("Frame", {
		Name = "Column2",
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = self._sectionHost,
	})
	self._column1Layout = Create.List(tokens:Get("SectionGap"))
	self._column1Layout.Parent = self._column1
	self._column2Layout = Create.List(tokens:Get("SectionGap"))
	self._column2Layout.Parent = self._column2
	self._janitor:Add(self._sectionHost:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_scheduleSectionLayout()
	end))

	window:_bind(self._page, { ScrollBarImageColor3 = "BorderStrong" })

	return self
end

--[[
	Lazy mounting.

	State registration and search indexing must NOT wait for this — a control
	that only exists once its tab is opened is the classic lazy-UI bug. Step 8
	builds Instances here and nothing else.
]]
function Tab:_ensureMounted()
	self._mounted = true
	for _, section in self._sections do
		if not section._mounted then
			section:_mount()
		end
	end
	if self._emptyState then
		self._emptyState.Visible = #self._sections == 0
	end
end

function Tab:_applyTokens()
	local t = self._window.Tokens
	local pagePadding = t:Get("PagePadding")
	if self._window._minimal then
		self._introHeight = 0
	end
	if self._pagePadding then
		self._pagePadding.PaddingTop = UDim.new(0, pagePadding)
		self._pagePadding.PaddingBottom = UDim.new(0, pagePadding)
		self._pagePadding.PaddingLeft = UDim.new(0, 0)
		self._pagePadding.PaddingRight = UDim.new(0, 0)
	end
	if self._pageIntro then
		self._pageIntro.Position = UDim2.fromOffset(pagePadding, 0)
		self._pageIntro.Size = UDim2.new(1, -(pagePadding * 2), 0, self._introHeight)
	end
	if self._sectionHost then
		self._sectionHost.Position = UDim2.fromOffset(pagePadding, self._introHeight)
		self._sectionHost.Size = UDim2.new(1, -(pagePadding * 2), 0, 0)
	end
	if self._emptyState then
		self._emptyState.Position = UDim2.fromOffset(
			pagePadding,
			self._introHeight + (if self._window._minimal then 0 else 24)
		)
		self._emptyState.Size = UDim2.new(1, -(pagePadding * 2), 0, 54)
		self._emptyState.TextSize = t:Get("FontBody")
	end
	if self._pageTitle then
		self._pageTitle.TextSize = t:Get("FontHeading")
	end
	if self._avatar then
		self._avatar.Size = UDim2.fromOffset(t:Get("IconMd"), t:Get("IconMd"))
	end
	if self._pageDescription then
		self._pageDescription.TextSize = t:Get("FontSmall")
	end
	if self._column1Layout then
		self._column1Layout.Padding = UDim.new(0, t:Get("SectionGap"))
	end
	if self._column2Layout then
		self._column2Layout.Padding = UDim.new(0, t:Get("SectionGap"))
	end
	for _, section in self._sections do
		if section._applyTokens then
			section:_applyTokens()
		end
	end
	self:_scheduleSectionLayout()
end

function Tab:_sectionParent(column)
	return self._sectionHost
end

function Tab:_scheduleSectionLayout()
	if self._layoutPending or self._destroyed then
		return
	end
	self._layoutPending = true
	local thread = task.defer(function()
		self._layoutPending = false
		if not self._destroyed then
			self:_applySectionLayout(self._window._layout)
		end
	end)
	self._janitor:Add(thread, nil, "sectionLayoutTask")
end

function Tab:_applySectionLayout(layout)
	if not self._sectionHost or not self._sectionHost.Parent then
		return
	end
	local t = self._window.Tokens
	local scale = math.max(0.01, self._window._scale or 1)
	-- AbsoluteSize already includes UIScale. Convert back to logical pixels before
	-- assigning Offset sizes, otherwise a 110% UI scale gets applied twice.
	local available = math.floor((self._sectionHost.AbsoluteSize.X / scale) + 0.5)
	if available <= 0 then
		available = math.max(0, math.floor((self._page.AbsoluteSize.X / scale) - (t:Get("PagePadding") * 2) + 0.5))
	end
	-- UIStroke touches the host edge when a card is positioned at x=0. A one-pixel
	-- inset keeps every side visible even though SectionHost clips its descendants.
	local edgeInset = 1
	local layoutWidth = math.max(1, available - edgeInset * 2)
	local gap = t:Get("ColumnGap")
	local minWidth = t:Get("MinSectionWidth")
	local twoColumn = (layout ~= "Drawer" and not self._window._minimal)
		and layoutWidth >= math.max(t:Get("TwoColumnMinWidth"), minWidth * 2 + gap)
	self._twoColumn = twoColumn
	if self._column1 then
		self._column1.Visible = false
	end
	if self._column2 then
		self._column2.Visible = false
	end
	local visible = {}
	for _, section in self._sections do
		if section._root and section:IsVisible() then
			section._root.Parent = self._sectionHost
			table.insert(visible, section)
		end
	end
	if self._window._minimal then
		for _, section in visible do
			section:_applyMinimalHeader(#visible > 1)
		end
	end
	local function heightOf(section)
		local physical = (section._root and section._root.AbsoluteSize.Y or scale)
		return math.max(1, math.floor((physical / scale) + 0.5))
	end
	if not twoColumn then
		local y = edgeInset
		for _, sec in visible do
			sec._root.Size = UDim2.fromOffset(layoutWidth, 0)
			sec._root.Position = UDim2.fromOffset(edgeInset, y)
			y += heightOf(sec) + gap
		end
		self._sectionHost.Size = UDim2.new(1, -(t:Get("PagePadding") * 2), 0, math.max(0, y - gap + edgeInset))
		if self._window._minimal and self._selected then
			self._window:_syncMinimalHeight()
		end
		return
	end
	local leftWidth = math.max(1, math.floor((layoutWidth - gap) / 2))
	local rightWidth = math.max(1, layoutWidth - gap - leftWidth)
	local y = edgeInset
	local index = 1
	while index <= #visible do
		local first = visible[index]
		local firstFull = first.Span == 2 or (first.Span == "Auto" and #visible == 1)
		if firstFull then
			first._root.Size = UDim2.fromOffset(layoutWidth, 0)
			first._root.Position = UDim2.fromOffset(edgeInset, y)
			y += heightOf(first) + gap
			index += 1
		else
			local second = visible[index + 1]
			local secondFull = second and (second.Span == 2)
			first._root.Size = UDim2.fromOffset(leftWidth, 0)
			first._root.Position = UDim2.fromOffset(edgeInset, y)
			local rowHeight = heightOf(first)
			if second and not secondFull then
				second._root.Size = UDim2.fromOffset(rightWidth, 0)
				second._root.Position = UDim2.fromOffset(edgeInset + leftWidth + gap, y)
				rowHeight = math.max(rowHeight, heightOf(second))
				index += 2
			else
				index += 1
			end
			y += rowHeight + gap
		end
	end
	self._sectionHost.Size = UDim2.new(1, -(t:Get("PagePadding") * 2), 0, math.max(0, y - gap + edgeInset))
	if self._window._minimal and self._selected then
		self._window:_syncMinimalHeight()
	end
end

function Tab:AddSection(options)
	options = options or {}
	if not options.Title and not options._implicit then
		error("[BobloUI] AddSection requires Title.", 2)
	end
	local section = Section.new(self, options)
	if self._emptyState then
		self._emptyState.Visible = false
	end
	return section
end

function Tab:_default()
	if not self._defaultSection then
		self._defaultSection = Section.new(self, { _implicit = true })
	end
	return self._defaultSection
end
function Tab:AddCustom(name, o)
	return self:_default():AddCustom(name, o)
end
function Tab:AddButton(o)
	return self:_default():AddButton(o)
end
function Tab:AddToggle(o)
	return self:_default():AddToggle(o)
end
function Tab:AddSlider(o)
	return self:_default():AddSlider(o)
end
function Tab:AddDropdown(o)
	return self:_default():AddDropdown(o)
end
function Tab:AddInput(o)
	return self:_default():AddInput(o)
end
function Tab:AddKeybind(o)
	return self:_default():AddKeybind(o)
end
function Tab:AddColorPicker(o)
	return self:_default():AddColorPicker(o)
end
function Tab:AddParagraph(o)
	return self:_default():AddParagraph(o)
end
function Tab:AddDivider(o)
	return self:_default():AddDivider(o)
end
function Tab:AddStatus(o)
	return self:_default():AddStatus(o)
end
function Tab:AddProgress(o)
	return self:_default():AddProgress(o)
end
function Tab:AddCode(o)
	return self:_default():AddCode(o)
end
function Tab:AddImage(o)
	return self:_default():AddImage(o)
end
function Tab:AddPassthrough(o)
	return self:_default():AddPassthrough(o)
end
function Tab:AddViewport(o)
	return self:_default():AddViewport(o)
end
function Tab:AddVideo(o)
	return self:_default():AddVideo(o)
end
function Tab:AddRow(o)
	return self:_default():AddRow(o or {})
end
function Tab:AddTabBox(o)
	return self:_default():AddTabBox(o or {})
end

function Tab:Select()
	self._window:_selectTab(self)
	return self
end

function Tab:IsSelected(): boolean
	return self._selected
end

function Tab:_applyNavVisual(hover: boolean)
	if not self._button then
		return
	end
	self._navHover = hover == true
	local selected = self._selected
	self._window.Motion:Tween(self._button, "Fast", {
		BackgroundTransparency = if selected then 0.56 elseif hover then 0.76 else 1,
	}, "Tabs")
	if self._avatarBack then
		self._window.Motion:Tween(self._avatarBack, "Fast", {
			BackgroundTransparency = if selected then 0.4 elseif hover then 0.68 else 0.82,
		}, "Tabs")
	end
	if self._avatarStroke then
		self._window.Motion:Tween(self._avatarStroke, "Fast", {
			Transparency = if selected then 0.22 elseif hover then 0.48 else 0.68,
		}, "Tabs")
	end
end

function Tab:_setSelected(selected: boolean)
	self._selected = selected
	self._page.Visible = selected
	if self._indicator then
		self._indicator.Visible = selected
	end
	self:_applyNavVisual(self._navHover == true)

	local theme = self._window.Theme
	self._label.TextColor3 = theme:Get(if selected then "Text" else "TextSecondary")
	Icon.setColor(self._avatar, theme:Get(if selected then "Accent" else "TextSecondary"))
	if self._pageIcon then
		Icon.setColor(self._pageIcon, theme:Get("Accent"))
	end

	if selected then
		self:_ensureMounted()
	end
end

function Tab:_refreshLocale()
	local shown = self._window.Locale:Resolve(self.Title)
	self._label.Text = shown
	if self._pageTitle then
		self._pageTitle.Text = shown
	end
	if self._pageDescription then
		self._pageDescription.Text = self._window.Locale:Resolve(self.Description or "")
	end
	if self._window.Registry then
		self._window.Registry:Update(self, { Title = shown, Path = shown })
	end
	for _, section in self._sections do
		if section._refreshLocale then
			section:_refreshLocale()
		end
	end
	if self._selected then
		self._window:_refreshHeaderTitle()
	end
	self._window:_refreshGroups()
end

function Tab:SetGroup(group)
	self.Group = group
	if self._button then
		self._button.LayoutOrder = self._window:_navLayoutOrder(group, self.Order)
	end
	self._window:_refreshGroups()
	return self
end

function Tab:SetTitle(title: string)
	self.Title = title
	local shown = self._window.Locale:Resolve(title)
	self._label.Text = shown
	if self._pageTitle then
		self._pageTitle.Text = shown
	end
	if self._window.Registry then
		self._window.Registry:Update(self, { Title = shown, Path = shown })
	end
	if self._selected then
		self._window:_refreshHeaderTitle()
	end
	return self
end

function Tab:SetDescription(description: string?)
	self.Description = description
	if self._pageDescription then
		self._pageDescription:Destroy()
		self._pageDescription = nil
	end
	self._introHeight = if self._window._minimal then 0 elseif description then 54 else 46
	local pagePadding = self._window.Tokens:Get("PagePadding")
	if self._pageIntro then
		self._pageIntro.Size = UDim2.new(1, -(pagePadding * 2), 0, self._introHeight)
		self._pageIntro.Position = UDim2.fromOffset(pagePadding, 0)
	end
	if self._sectionHost then
		self._sectionHost.Position = UDim2.fromOffset(pagePadding, self._introHeight)
		self._sectionHost.Size = UDim2.new(1, -(pagePadding * 2), 0, 0)
	end
	if self._emptyState then
		self._emptyState.Position = UDim2.fromOffset(
			pagePadding,
			self._introHeight + (if self._window._minimal then 0 else 24)
		)
		self._emptyState.Size = UDim2.new(1, -(pagePadding * 2), 0, 54)
	end
	self:_scheduleSectionLayout()
	if description and self._pageIntro then
		self._pageDescription = New("TextLabel", {
			Size = UDim2.new(1, -46, 0, 16),
			Position = UDim2.fromOffset(46, 26),
			BackgroundTransparency = 1,
			Font = self._window.Fonts.Regular,
			TextSize = self._window.Tokens:Get("FontSmall"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = self._window.Locale:Resolve(description),
			Parent = self._pageIntro,
		})
		self._window:_bind(self._pageDescription, { TextColor3 = "TextTertiary" })
	end
	return self
end

function Tab:SetIcon(icon)
	self.Icon = icon
	if self._avatar then
		self._avatar:Destroy()
	end
	local t = self._window.Tokens
	local props = {
		Name = "Avatar",
		Size = UDim2.fromOffset(t:Get("IconMd"), t:Get("IconMd")),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = self._avatarBack or self._button,
	}
	self._avatar = Icon.new(self._window, icon or "star", props)
	if self._pageIcon then
		self._pageIcon:Destroy()
		self._pageIcon = nil
	end
	if self._pageIconBack then
		self._pageIcon = Icon.new(self._window, icon or "star", {
			Name = "PageIcon",
			Size = UDim2.fromOffset(18, 18),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Parent = self._pageIconBack,
		})
	end
	self:_setSelected(self._selected)
	self._window:_applyLayout(self._window._layout, true)
	return self
end

function Tab:SetBadge(text)
	self.Badge = text
	if self._badge then
		self._badge:Destroy()
		self._badge = nil
	end
	if text then
		self._badge = Badge.new(self._window, text, "Neutral", self._button)
		self._badge.Position = UDim2.new(1, -8, 0.5, 0)
		self._badge.AnchorPoint = Vector2.new(1, 0.5)
		self._badge.Visible = self._window._layout ~= "Rail"
	end
	return self
end

function Tab:SetVisible(visible: boolean)
	self._button.Visible = visible
	if not visible and self._selected then
		if self._window._minimal then
			self:_setSelected(false)
		end
		self._window:_selectFirstVisible()
	end
	if self._window._minimal then
		self._window:_refreshMinimalMenu()
	end
	return self
end
function Tab:SetLocked(locked, reason)
	self.Locked = locked == true
	if reason ~= nil then
		self.LockedReason = reason
	end
	if self._label then
		self._label.TextTransparency = if self.Locked then 0.38 else 0
	end
	if self.Locked and self._selected then
		if self._window._minimal then
			self:_setSelected(false)
		end
		self._window:_selectFirstVisible()
	end
	if self._window._minimal then
		self._window:_refreshMinimalMenu()
	end
	return self
end
function Tab:IsLocked()
	return self.Locked == true
end

function Tab:GetInstance(): Instance
	return self._page
end

function Tab:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	local window = self._window
	window._janitor:Release(self)
	if window.Registry then
		window.Registry:Remove(self)
	end
	local position = table.find(window._tabs, self)
	if position then
		table.remove(window._tabs, position)
	end
	local wasSelected = self._selected
	self._janitor:Destroy()
	if wasSelected and not window._destroying then
		window:_selectFirstVisible()
	end
	if window._minimal and not window._destroying then
		window:_refreshMinimalMenu()
	end
end
return Tab
