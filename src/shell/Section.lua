--!nonstrict
local Create = require("@runtime/Create")
local Janitor = require("@runtime/Janitor")
local Dependency = require("@runtime/Dependency")
local Surface = require("@primitives/Surface")
local Icon = require("@primitives/Icon")
local Button = require("@controls/Button")
local Toggle = require("@controls/Toggle")
local Slider = require("@controls/Slider")
local Dropdown = require("@controls/Dropdown")
local TextField = require("@controls/TextField")
local Keybind = require("@controls/Keybind")
local ColorPicker = require("@controls/ColorPicker")
local Paragraph = require("@controls/Paragraph")
local Divider = require("@controls/Divider")
local Status = require("@controls/Status")
local Progress = require("@controls/Progress")
local Code = require("@controls/Code")
local Image = require("@controls/Image")
local Passthrough = require("@controls/Passthrough")
local Viewport = require("@controls/Viewport")
local Video = require("@controls/Video")
local Row = require("@shell/Row")
local TabBox = require("@shell/TabBox")
local Section = {}
Section.__index = Section
function Section.new(tab, options)
	options = options or {}
	if options.Id then
		tab._window.Registry:AssertAvailable(options.Id, 3)
	end
	local order = #tab._sections + 1
	local column = options.Column == 2 and 2 or 1
	local span = options.Span or "Auto"
	if span ~= "Auto" and span ~= 1 and span ~= 2 then
		error("[BobloUI] Section Span must be 'Auto', 1, or 2.", 3)
	end
	local layout = options.Layout or "Stack"
	if layout ~= "Stack" and layout ~= "Grid" and layout ~= "Auto" then
		error("[BobloUI] Section Layout must be 'Stack', 'Grid', or 'Auto'.", 3)
	end
	local self = setmetatable({
		Id = options.Id,
		Title = options.Title,
		Description = options.Description,
		Icon = options.Icon or "layers",
		Collapsible = options.Collapsible == true,
		Collapsed = options.Collapsed == true,
		Column = column,
		Span = span,
		Layout = layout,
		_columnExplicit = options.Column ~= nil,
		_effectiveContentLayout = nil,
		_order = order,
		_implicit = options._implicit == true,
		_tab = tab,
		_window = tab._window,
		_janitor = Janitor.new(`Section[{options.Title or "Default"}]`),
		_controls = {},
		_mounted = false,
		_manualVisible = options.Visible ~= false,
		_dependencyVisible = true,
		_manualEnabled = not (options.Disabled == true or type(options.Disabled) == "string"),
		_dependencyEnabled = true,
		_parentEnabled = true,
	}, Section)
	tab._janitor:Add(self, "Destroy", self)
	table.insert(tab._sections, self)
	if self.Id then
		self._window.Registry:Add(self, {
			Id = self.Id,
			Type = "Section",
			Title = self.Title or "Section",
			Tab = tab.Id,
			Path = tab.Title,
			Persist = false,
		})
	end
	self._janitor:Add(self._window.Tokens.Changed:Connect(function()
		if self._mounted then
			self:_applyTokens()
		end
	end))
	self._janitor:Add(self._window.Theme.Changed:Connect(function()
		if self._sectionIcon then
			Icon.setColor(self._sectionIcon, self._window.Theme:Get("Accent"))
		end
	end))
	Dependency.Bind(self, options.VisibleWhen, "visible")
	Dependency.Bind(self, options.EnabledWhen, "enabled")
	if tab._mounted then
		self:_mount()
	end
	tab:_scheduleSectionLayout()
	return self
end
function Section:_mount()
	if self._mounted then
		return
	end
	self._mounted = true
	local w = self._window
	local t = w.Tokens
	self._root = Surface.new(w, {
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		LayoutOrder = self._order,
		Visible = self._manualVisible and self._dependencyVisible,
		Parent = self._tab:_sectionParent(self.Column),
	}, {
		Token = if self._implicit or w._minimal then "Canvas" else "Surface",
		Stroke = not self._implicit and not w._minimal,
		StrokeToken = "Border",
		StrokeTransparency = 0.3,
		Corner = if self._implicit or w._minimal then 0 else t:Get("CornerMd"),
		Sheen = false,
	})
	self._janitor:Add(self._root)
	if w._minimal then
		self._root.BackgroundTransparency = 1
	end
	self._janitor:Add(self._root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if not self._destroyed then
			self:_updateContentLayout()
			self:_updateAdaptiveControls()
			self._tab:_scheduleSectionLayout()
		end
	end))
	local pad = if self._implicit then 0 else t:Get("SectionPadding")
	self._padding = Create.New("UIPadding", {
		PaddingTop = UDim.new(0, pad),
		PaddingBottom = UDim.new(0, pad),
		PaddingLeft = UDim.new(0, pad),
		PaddingRight = UDim.new(0, pad),
		Parent = self._root,
	})
	self._rootLayout = Create.List(if self._implicit then t:Get("RowGap") elseif w._minimal then 6 else 12)
	self._rootLayout.Parent = self._root
	if not self._implicit and self.Title then
		local headerClass = if self.Collapsible then "TextButton" else "Frame"
		self._header = Create.New(headerClass, {
			Name = "SectionHeader",
			Size = UDim2.new(1, 0, 0, if w._minimal then 28 elseif self.Description then 52 else 42),
			BackgroundTransparency = if w._minimal then 1 else 0.28,
			BorderSizePixel = 0,
			Text = headerClass == "TextButton" and "" or nil,
			AutoButtonColor = headerClass == "TextButton" and false or nil,
			Parent = self._root,
		})
		if w._minimal then
			self._header.Visible = self.Collapsible
		end
		Create.New("UICorner", { CornerRadius = UDim.new(0, math.max(6, t:Get("CornerSm"))), Parent = self._header })
		self._headerStroke = Create.New("UIStroke", {
			Thickness = 1,
			Transparency = 0.5,
			LineJoinMode = Enum.LineJoinMode.Round,
			Parent = self._header,
		})
		w:_bind(self._header, { BackgroundColor3 = "SurfaceRaised" })
		w:_bind(self._headerStroke, { Color = "BorderSubtle" })
		if w._minimal then
			self._headerStroke.Enabled = false
		end
		self._headerAccent = Create.New("Frame", {
			Name = "AccentRail",
			Size = UDim2.fromOffset(3, 18),
			Position = UDim2.new(0, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BorderSizePixel = 0,
			Parent = self._header,
		})
		Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self._headerAccent })
		w:_bind(self._headerAccent, { BackgroundColor3 = "Accent" })
		if w._minimal then
			self._headerAccent.Visible = false
		end
		self._sectionIconHost = Create.New("Frame", {
			Name = "IconTile",
			Size = UDim2.fromOffset(28, 28),
			Position = UDim2.new(0, 8, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BorderSizePixel = 0,
			Parent = self._header,
		})
		Create.New("UICorner", { CornerRadius = UDim.new(0, 8), Parent = self._sectionIconHost })
		local iconStroke =
			Create.New("UIStroke", { Thickness = 1, Transparency = 0.62, Parent = self._sectionIconHost })
		w:_bind(self._sectionIconHost, { BackgroundColor3 = "AccentSoft" })
		w:_bind(iconStroke, { Color = "AccentBorder" })
		self._sectionIcon = Icon.new(w, self.Icon, {
			Size = UDim2.fromOffset(15, 15),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Parent = self._sectionIconHost,
		})
		Icon.setColor(self._sectionIcon, w.Theme:Get("Accent"))
		if w._minimal then
			self._sectionIconHost.Visible = false
		end
		self._title = Create.New("TextLabel", {
			Size = UDim2.new(1, if self.Collapsible then -82 else -50, 0, if self.Description then 20 else 42),
			Position = UDim2.fromOffset(44, if self.Description then 5 else 0),
			BackgroundTransparency = 1,
			Font = w.Fonts.Medium,
			TextSize = t:Get("FontTitle"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = w.Locale:Resolve(self.Title),
			Parent = self._header,
		})
		w:_bind(self._title, { TextColor3 = "Text" })
		if w._minimal then
			self._title.Position = UDim2.fromOffset(4, 0)
			self._title.Size = UDim2.new(1, if self.Collapsible then -38 else -4, 1, 0)
			self._title.TextSize = t:Get("FontSmall")
		end
		if self.Description then
			self._desc = Create.New("TextLabel", {
				Size = UDim2.new(1, if self.Collapsible then -82 else -50, 0, 16),
				Position = UDim2.fromOffset(44, 27),
				BackgroundTransparency = 1,
				Font = w.Fonts.Regular,
				TextSize = t:Get("FontSmall"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = w.Locale:Resolve(self.Description),
				Parent = self._header,
			})
			w:_bind(self._desc, { TextColor3 = "TextTertiary" })
			if w._minimal then
				self._desc.Visible = false
			end
		end
		if self.Collapsible then
			self._chevronBack = Create.New("Frame", {
				Name = "ChevronTile",
				Size = UDim2.fromOffset(26, 26),
				Position = UDim2.new(1, -7, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BorderSizePixel = 0,
				BackgroundTransparency = 0.32,
				Parent = self._header,
			})
			Create.New("UICorner", { CornerRadius = UDim.new(0, 7), Parent = self._chevronBack })
			w:_bind(self._chevronBack, { BackgroundColor3 = "ControlHover" })
			self._chevron = Icon.new(w, "chevron_down", {
				Size = UDim2.fromOffset(15, 15),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Parent = self._chevronBack,
			})
			self._chevron.Rotation = if self.Collapsed then -90 else 0
			self._janitor:Add(self._header.MouseEnter:Connect(function()
				w.Motion:Tween(self._header, "Fast", { BackgroundTransparency = 0.12 })
				w.Motion:Tween(self._headerStroke, "Fast", { Transparency = 0.46 })
			end))
			self._janitor:Add(self._header.MouseLeave:Connect(function()
				w.Motion:Tween(self._header, "Fast", { BackgroundTransparency = 0.28 })
				w.Motion:Tween(self._headerStroke, "Fast", { Transparency = 0.7 })
			end))
			self._janitor:Add(self._header.MouseButton1Click:Connect(function()
				self:SetCollapsed(not self.Collapsed)
			end))
		end
	end
	self._content = Create.New("Frame", {
		Name = "Controls",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = not self.Collapsed,
		Parent = self._root,
	})
	self:_updateContentLayout(true)
	for _, control in self._controls do
		control:_mount()
	end
	self:_reparentControls()
	self:_applyContainerState()
end
function Section:_applyMinimalHeader(multiple)
	if not self._header then
		return
	end
	local shown = multiple or self.Collapsible
	if self._header.Visible ~= shown then
		self._header.Visible = shown
	end
end
function Section:_wantedContentLayout()
	if self._window._minimal then
		return "Stack"
	end
	if self.Layout == "Stack" or self.Layout == "Grid" then
		return self.Layout
	end
	if not self._root then
		return "Stack"
	end
	local scale = math.max(0.01, self._window._scale or 1)
	return (self._root.AbsoluteSize.X / scale) >= self._window.Tokens:Get("ControlGridMinWidth") and "Grid" or "Stack"
end
function Section:_measureControlLayout()
	if not self._root or self._root.AbsoluteSize.X <= 0 then
		return "Inline"
	end
	local scale = math.max(0.01, self._window._scale or 1)
	local width = self._root.AbsoluteSize.X / scale
	if not self._implicit then
		width -= self._window.Tokens:Get("SectionPadding") * 2
	end
	if self._effectiveContentLayout == "Grid" then
		width = (width - self._window.Tokens:Get("ColumnGap")) / 2
	end
	return width < self._window.Tokens:Get("ControlStackBreakpoint") and "Stacked" or "Inline"
end
function Section:_controlLayout()
	return self._adaptiveControlLayout or "Inline"
end
function Section:_updateAdaptiveControls(force)
	local layout = self:_measureControlLayout()
	if not force and self._adaptiveControlLayout == layout then
		return
	end
	self._adaptiveControlLayout = layout
	for _, control in self._controls do
		if control._adaptive and control._updateResponsiveLayout then
			control:_updateResponsiveLayout()
		end
	end
end
function Section:_destroyGridColumns()
	for _, col in self._gridColumns or {} do
		if col and col.Parent then
			col:Destroy()
		end
	end
	self._gridColumns = nil
	self._gridLayouts = nil
end
function Section:_buildGridColumns()
	if self._gridColumns then
		return
	end
	local gap = self._window.Tokens:Get("ColumnGap")
	self._gridColumns = {}
	self._gridLayouts = {}
	for i = 1, 2 do
		local col = Create.New("Frame", {
			Name = "ControlColumn" .. i,
			Size = UDim2.new(0.5, -gap / 2, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = if i == 1 then UDim2.new(0, 0, 0, 0) else UDim2.new(0.5, gap / 2, 0, 0),
			BackgroundTransparency = 1,
			Parent = self._content,
		})
		local layout = Create.List(self._window.Tokens:Get("RowGap"))
		layout.Parent = col
		self._gridColumns[i] = col
		self._gridLayouts[i] = layout
	end
end
function Section:_reparentControls()
	if not self._content then
		return
	end
	if self._effectiveContentLayout == "Grid" then
		self:_buildGridColumns()
		local visibleIndex = 0
		for _, control in self._controls do
			if control._root then
				visibleIndex += 1
				control._root.Parent = self._gridColumns[((visibleIndex - 1) % 2) + 1]
			end
		end
	else
		for _, control in self._controls do
			if control._root then
				control._root.Parent = self._content
			end
		end
	end
	self:_refreshSeparators()
end
function Section:_updateContentLayout(force)
	if not self._content then
		return
	end
	local wanted = self:_wantedContentLayout()
	if not force and self._effectiveContentLayout == wanted then
		self:_updateAdaptiveControls()
		return
	end
	-- Move controls out before destroying old layout containers.
	for _, control in self._controls do
		if control._root then
			control._root.Parent = self._content
		end
	end
	if self._contentLayout then
		self._contentLayout:Destroy()
		self._contentLayout = nil
	end
	self:_destroyGridColumns()
	self._effectiveContentLayout = wanted
	if wanted == "Grid" then
		self:_buildGridColumns()
	else
		self._contentLayout = Create.List(self._window.Tokens:Get("RowGap"))
		self._contentLayout.Parent = self._content
	end
	self:_reparentControls()
	self:_updateAdaptiveControls(true)
end
function Section:_controlParent(control)
	if not self._content then
		return nil
	end
	if self._effectiveContentLayout == "Grid" then
		self:_buildGridColumns()
		local index = table.find(self._controls, control) or #self._controls
		return self._gridColumns[((math.max(1, index) - 1) % 2) + 1]
	end
	return self._content
end
function Section:_applyTokens()
	if not self._mounted then
		return
	end
	local t = self._window.Tokens
	local pad = if self._implicit then 0 else t:Get("SectionPadding")
	local u = UDim.new(0, pad)
	if self._padding then
		self._padding.PaddingTop = u
		self._padding.PaddingBottom = u
		self._padding.PaddingLeft = u
		self._padding.PaddingRight = u
	end
	if self._rootLayout then
		self._rootLayout.Padding =
			UDim.new(0, if self._implicit then t:Get("RowGap") elseif self._window._minimal then 6 else 12)
	end
	if self._contentLayout then
		self._contentLayout.Padding = UDim.new(0, t:Get("RowGap"))
	end
	for _, layout in self._gridLayouts or {} do
		layout.Padding = UDim.new(0, t:Get("RowGap"))
	end
	self:_updateContentLayout()
	self:_updateAdaptiveControls(true)
	if self._title then
		self._title.TextSize = t:Get(if self._window._minimal then "FontSmall" else "FontTitle")
	end
	if self._desc then
		self._desc.TextSize = t:Get("FontSmall")
	end
	if self._header then
		self._header.Size = UDim2.new(1, 0, 0, if self._window._minimal then 28 elseif self.Description then 52 else 42)
	end
end
function Section:_refreshSeparators()
	local groups = {}
	for _, control in self._controls do
		if control._separator and control._root and control._root.Visible then
			local parent = control._root.Parent
			groups[parent] = groups[parent] or {}
			table.insert(groups[parent], control)
		end
	end
	for _, visible in groups do
		for i, control in visible do
			control._separator.Visible = i < #visible
		end
	end
end
function Section:_registerControl(c)
	table.insert(self._controls, c)
	if c._setContainerEnabled then
		c:_setContainerEnabled(self:IsEnabled())
	end
	if self._mounted then
		task.defer(function()
			if not self._destroyed then
				self:_reparentControls()
				self:_updateAdaptiveControls()
			end
		end)
	end
end
function Section:_removeControl(c)
	local p = table.find(self._controls, c)
	if p then
		table.remove(self._controls, p)
	end
	if self._mounted then
		self:_reparentControls()
	else
		self:_refreshSeparators()
	end
end
function Section:_createControl(factory, options)
	options = options or {}
	if options.Id then
		self._window.Registry:AssertAvailable(options.Id, 3)
	end
	return factory.new(self, options)
end
function Section:AddCustom(name, o)
	o = o or {}
	if o.Id then
		self._window.Registry:AssertAvailable(o.Id, 3)
	end
	local factory = self._window.CustomControls and self._window.CustomControls[name]
	if not factory then
		error(`[BobloUI] unknown custom control "{tostring(name)}".`, 2)
	end
	return factory(self, o)
end
function Section:AddButton(o)
	return self:_createControl(Button, o)
end
function Section:AddToggle(o)
	return self:_createControl(Toggle, o)
end
function Section:AddSlider(o)
	return self:_createControl(Slider, o)
end
function Section:AddDropdown(o)
	return self:_createControl(Dropdown, o)
end
function Section:AddInput(o)
	return self:_createControl(TextField, o)
end
function Section:AddKeybind(o)
	return self:_createControl(Keybind, o)
end
function Section:AddColorPicker(o)
	return self:_createControl(ColorPicker, o)
end
function Section:AddParagraph(o)
	return self:_createControl(Paragraph, o)
end
function Section:AddDivider(o)
	return self:_createControl(Divider, o)
end
function Section:AddStatus(o)
	return self:_createControl(Status, o)
end
function Section:AddProgress(o)
	return self:_createControl(Progress, o)
end
function Section:AddCode(o)
	return self:_createControl(Code, o)
end
function Section:AddImage(o)
	return self:_createControl(Image, o)
end
function Section:AddPassthrough(o)
	return self:_createControl(Passthrough, o)
end
function Section:AddViewport(o)
	return self:_createControl(Viewport, o)
end
function Section:AddVideo(o)
	return self:_createControl(Video, o)
end
function Section:AddRow(o)
	return self:_createControl(Row, o)
end
function Section:AddTabBox(o)
	return self:_createControl(TabBox, o)
end
function Section:_refreshLocale()
	if self._title then
		self._title.Text = self._window.Locale:Resolve(self.Title or "")
	end
	if self._desc then
		self._desc.Text = self._window.Locale:Resolve(self.Description or "")
	end
	if self.Id then
		self._window.Registry:Update(self, {
			Title = self._window.Locale:Resolve(self.Title or "Section"),
			Path = self._window.Locale:Resolve(self._tab.Title),
		})
	end
	for _, control in self._controls do
		if control._refreshText then
			control:_refreshText()
		end
	end
end
function Section:SetTitle(t)
	self.Title = t
	if self._title then
		self._title.Text = self._window.Locale:Resolve(t or "")
	end
	if self.Id then
		self._window.Registry:Update(self, { Title = self._window.Locale:Resolve(t or "Section") })
	end
	return self
end
function Section:SetIcon(icon)
	self.Icon = icon or "layers"
	if self._sectionIcon then
		self._sectionIcon:Destroy()
		self._sectionIcon = nil
	end
	if self._sectionIconHost then
		self._sectionIcon = Icon.new(self._window, self.Icon, {
			Size = UDim2.fromOffset(15, 15),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Parent = self._sectionIconHost,
		})
		Icon.setColor(self._sectionIcon, self._window.Theme:Get("Accent"))
	end
	return self
end
function Section:SetSpan(span)
	if span ~= "Auto" and span ~= 1 and span ~= 2 then
		error("[BobloUI] Section:SetSpan expects 'Auto', 1, or 2.", 2)
	end
	self.Span = span
	self._tab:_scheduleSectionLayout()
	return self
end
function Section:SetLayout(layout)
	if layout ~= "Stack" and layout ~= "Grid" and layout ~= "Auto" then
		error("[BobloUI] Section:SetLayout expects 'Stack', 'Grid', or 'Auto'.", 2)
	end
	self.Layout = layout
	self:_updateContentLayout(true)
	return self
end
function Section:Reset()
	for _, control in self._controls do
		if control.Reset then
			control:Reset()
		end
	end
	return self
end
function Section:SetVisible(v)
	self._manualVisible = v == true
	self:_applyContainerState()
	return self
end
function Section:IsVisible()
	return self._manualVisible and self._dependencyVisible
end
function Section:SetEnabled(enabled)
	self._manualEnabled = enabled ~= false
	self:_applyContainerState()
	return self
end
function Section:IsEnabled()
	return self._parentEnabled and self._manualEnabled and self._dependencyEnabled
end
function Section:_setContainerEnabled(enabled)
	self._parentEnabled = enabled ~= false
	self:_applyContainerState()
	return self
end
function Section:_applyContainerState()
	local visible = self._manualVisible and self._dependencyVisible
	local enabled = self._parentEnabled and self._manualEnabled and self._dependencyEnabled
	if self._root then
		self._root.Visible = visible
	end
	for _, control in self._controls do
		if control._setContainerEnabled then
			control:_setContainerEnabled(enabled)
		end
	end
	if self.Id then
		self._window.Registry:Update(self, { Hidden = not visible, Disabled = not enabled })
	end
	self._tab:_scheduleSectionLayout()
end
function Section:SetCollapsed(v)
	self.Collapsed = v == true
	if self._content then
		self._content.Visible = not self.Collapsed
	end
	if self._chevron then
		self._chevron.Rotation = if self.Collapsed then -90 else 0
	end
	self._tab:_scheduleSectionLayout()
	return self
end
function Section:GetInstance()
	return self._root
end
function Section:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._tab._janitor:Release(self)
	if self.Id then
		self._window.Registry:Remove(self)
	end
	local p = table.find(self._tab._sections, self)
	if p then
		table.remove(self._tab._sections, p)
	end
	for _, control in table.clone(self._controls) do
		control:Destroy()
	end
	self._janitor:Destroy()
	if not self._tab._destroyed then
		self._tab:_scheduleSectionLayout()
	end
end
return Section
