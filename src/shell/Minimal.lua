--!nonstrict
-- The small window shares Tab, Section, controls, State and Config with the normal shell.
local Create = require("@runtime/Create")
local Icon = require("@primitives/Icon")
local Popover = require("@primitives/Popover")

local Minimal = {}

function Minimal:_buildMinimal()
	self._minimalMenuButton = Create.New("TextButton", {
		Name = "MinimalTabs",
		Size = UDim2.fromOffset(36, 40),
		Position = UDim2.new(1, -50, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		Parent = self._header,
	})
	self._minimalChevron = Icon.new(self, "chevron_down", {
		Size = UDim2.fromOffset(17, 17),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = self._minimalMenuButton,
	})
	Icon.setColor(self._minimalChevron, self.Theme:Get("TextSecondary"))
	self._janitor:Add(self.Theme.Changed:Connect(function()
		Icon.setColor(self._minimalChevron, self.Theme:Get("TextSecondary"))
	end))
	self._janitor:Add(self._minimalMenuButton.MouseButton1Click:Connect(function()
		self:_openMinimalMenu()
	end))
	self._janitor:Add(function()
		if self._minimalMenuHandle then
			self._minimalMenuHandle:Dismiss()
		end
	end)
end

function Minimal:_refreshMinimalMenu()
	if not self._minimalMenuButton then
		return
	end
	local count = 0
	for _, tab in self._tabs do
		if tab._button.Visible then
			count += 1
		end
	end
	self._minimalMenuButton.Visible = count > 1
	if self._minimalMenuHandle then
		self._minimalMenuHandle:Dismiss()
		self._minimalMenuHandle = nil
	end
end

function Minimal:_openMinimalMenu()
	if self._minimalMenuHandle then
		self._minimalMenuHandle:Dismiss()
		self._minimalMenuHandle = nil
		return
	end
	local tabs = {}
	for _, tab in self._tabs do
		if tab._button.Visible then
			table.insert(tabs, tab)
		end
	end
	if #tabs < 2 then
		return
	end
	local height = math.min(#tabs * 44 + 8, 264)
	local handle = Popover.open(self, self._minimalMenuButton, Vector2.new(220, height), {
		OnDismiss = function()
			self._minimalMenuHandle = nil
		end,
	})
	self._minimalMenuHandle = handle
	local list = Create.New("ScrollingFrame", {
		Name = "MinimalTabList",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = handle.Frame,
	})
	Create.New("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
		Parent = list,
	})
	Create.List(0).Parent = list
	for index, tab in tabs do
		local label = self.Locale:Resolve(tab.Title)
		if tab.Locked then
			label = label .. "  · locked"
		end
		local item = Create.New("TextButton", {
			Name = `Tab_{tab.Id}`,
			Size = UDim2.new(1, 0, 0, 44),
			LayoutOrder = index,
			BackgroundTransparency = if tab == self._active then 0.7 else 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "  " .. label,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = self.Tokens:Get("FontBody"),
			Font = self.Fonts.Medium,
			Parent = list,
		})
		Create.New("UICorner", { CornerRadius = UDim.new(0, 7), Parent = item })
		self:_bind(item, {
			BackgroundColor3 = "AccentSoft",
			TextColor3 = if tab.Locked then "TextTertiary" else "Text",
		})
		item.MouseButton1Click:Connect(function()
			handle:Dismiss()
			tab:Select()
		end)
	end
end

function Minimal:_applyMinimalLayout()
	self._navToggle.Visible = false
	self._navPanel.Visible = false
	self._sidebarButton.Visible = false
	self._searchButton.Visible = false
	self._themeButton.Visible = false
	self._minimizeButton.Visible = false
	self._subtitleLabel.Visible = false
	self._topbarExtras.Visible = false
	self._footer.Visible = false
	self._grip.Visible = false
	self._content.Size = UDim2.fromScale(1, 1)
	self._content.Position = UDim2.new()
	self:_applyMinimalTokens()
	self:_applyGeometry()
	self:_refreshMinimalMenu()
end

function Minimal:_applyMinimalTokens()
	local headerHeight = self.Tokens:Get("HeaderHeight")
	self._header.Size = UDim2.new(1, 0, 0, headerHeight)
	self._body.Size = UDim2.new(1, 0, 1, -headerHeight)
	self._body.Position = UDim2.fromOffset(0, headerHeight)
	self._rootStroke.Thickness = self.Tokens:Get("Stroke")
	self._titleLabel.TextSize = self.Tokens:Get("FontTitle")
	self._titleLabel.Position = UDim2.fromOffset(52, 0)
	self._titleLabel.Size = UDim2.new(1, -148, 1, 0)
	self:_applyCornerRadius()
	for _, tab in self._tabs do
		tab:_applyTokens()
	end
	self:_scheduleSectionLayouts()
end

function Minimal:_syncMinimalHeight()
	if not self._minimal or self._destroying then
		return
	end
	local _, safeSize = self.Device:SafeArea()
	local scale = math.max(0.01, self._scale or 1)
	local maxHeight = math.max(88, safeSize.Y / scale - 16)
	if self._size.Y.Offset > 0 then
		maxHeight = math.min(maxHeight, math.max(88, self._size.Y.Offset))
	else
		maxHeight = math.min(maxHeight, math.max(220, safeSize.Y / scale * 0.72))
	end
	local contentHeight = 54
	if self._active and self._active._sectionHost then
		contentHeight = math.max(contentHeight, self._active._sectionHost.Size.Y.Offset + 16)
	end
	local height = math.clamp(self.Tokens:Get("HeaderHeight") + contentHeight, 88, maxHeight)
	if math.abs(self._root.Size.Y.Offset - height) >= 1 then
		self._root.Size = UDim2.fromOffset(self._root.Size.X.Offset, height)
	end
end

return Minimal
