--!nonstrict
-- Window assembles the shell from focused Tab, Chrome, and Layout modules.

local Create = require("@runtime/Create")
local Signal = require("@runtime/Signal")
local Util = require("@runtime/Util")
local Tab = require("@shell/Tab")
local WindowChrome = require("@shell/WindowChrome")
local WindowLayout = require("@shell/WindowLayout")
local Minimal = require("@shell/Minimal")

local New = Create.New

local Window = {}
Window.__index = Window

for name, method in pairs(WindowChrome) do
	Window[name] = method
end
for name, method in pairs(WindowLayout) do
	Window[name] = method
end
for name, method in pairs(Minimal) do
	Window[name] = method
end

function Window.new(context, options)
	local self = setmetatable({
		Id = context.Id,
		Title = options.Title,
		Subtitle = options.Subtitle,
		Icon = options.Icon,

		Theme = context.Theme,
		Tokens = context.Tokens,
		Device = context.Device,
		Layers = context.Layers,
		Fonts = context.Fonts,
		State = context.State,
		Registry = context.Registry,
		Input = context.Input,
		Motion = context.Motion,
		Locale = context.Locale,

		Unloading = Signal.new("Window.Unloading"),

		_janitor = context.Janitor,
		_tabs = {},
		_active = nil,
		_layout = nil,
		_minimal = options.Presentation == "Minimal",
		_drawer = nil,
		_visible = true,
		_size = options.Size
			or (if options.Presentation == "Minimal" then UDim2.fromOffset(340, 0) else UDim2.fromOffset(720, 480)),
		_minSize = options.MinSize
			or (if options.Presentation == "Minimal" then Vector2.new(280, 88) else Vector2.new(500, 340)),
		_themeHandles = {},
		_groups = {},
		_groupSeq = 0,
		_locked = false,
		_scale = options.Scale or 1,
		_rememberGeometry = options.RememberGeometry ~= false,
		_sidebarHidden = options.SidebarHidden == true,
		_minContainerWidth = math.max(
			if options.Presentation == "Minimal" then 280 else 320,
			tonumber(options.MinContainerWidth) or (if options.Presentation == "Minimal" then 280 else 500)
		),
		_minSidebarWidth = math.max(96, tonumber(options.MinSidebarWidth) or 120),
		_sidebarCompactWidth = math.max(48, tonumber(options.SidebarCompactWidth) or context.Tokens:Get("RailWidth")),
		_sidebarCollapseThreshold = math.max(320, tonumber(options.SidebarCollapseThreshold) or 700),
		_compactWidthActivation = math.max(360, tonumber(options.CompactWidthActivation) or 1100),
		_enableCompacting = options.EnableCompacting ~= false,
		_disableCompactingSnap = options.DisableCompactingSnap == true,
		_sidebarCompacted = options.SidebarCompacted == true,
		_sidebarWidth = math.max(
			math.max(96, tonumber(options.MinSidebarWidth) or 120),
			tonumber(options.SidebarWidth) or context.Tokens:Get("SidebarWidth")
		),
		_sidebarResizeEnabled = options.EnableSidebarResize ~= false,
		_disableSearch = options.DisableSearch == true,
		_searchbarSize = options.SearchbarSize,
		_globalSearch = options.GlobalSearch ~= false,
		_showMobileButtons = options.ShowMobileButtons ~= false,
		_mobileButtonsSide = options.MobileButtonsSide or "Center",
		_cornerRadius = options.CornerRadius or context.Tokens:Get("CornerLg"),
		_footerHeight = math.max(26, math.floor(tonumber(options.FooterHeight) or 28)),
		_footerTextValue = options.FooterText,
		_windowOpacity = math.clamp(tonumber(options.Opacity) or 1, 0.25, 1),
		_tabTransition = options.TabTransition or {
			Style = "Slide",
			Duration = tonumber(options.TabTransitionTime) or 0.12,
			Offset = tonumber(options.TabSwipeOffset) or 10,
			Direction = options.TabSwipeFrom or "Right",
		},
		_windowAnimation = options.WindowAnimation or { Style = "Slide", Duration = 0.12, Offset = 8 },
		_animationFlags = { Window = true, Tabs = true, Controls = true },
		_visibilityToken = 0,
		_topbarItems = {},
		_restoreSpec = options.RestoreButton,
		_showText = options.ShowText or "Show BobloUI",
		_showTextExplicit = options.ShowText ~= nil,
		_restoreMode = if options.ShowMobileButtons == false and options.RestoreButton == nil
			then "Never"
			elseif options.RestoreButton == false then "Never"
			elseif type(options.RestoreButton) == "table" and options.RestoreButton.Enabled == false then "Never"
			elseif options.RestoreButton ~= nil then (
				(type(options.RestoreButton) == "table" and options.RestoreButton.Mode) or "Always"
			)
			else "Always",
		_backgroundImageSource = options.BackgroundImage,
		_backgroundImageTransparency = options.BackgroundImageTransparency,
	}, Window)

	self:_build()
	self:_applyLayout(self:_responsiveLayout(), true)

	self._janitor:Add(self.Device.Changed:Connect(function(device, changed)
		if changed.Layout then
			self:_applyLayout(self:_responsiveLayout())
		end
		if changed.Class then
			self.Tokens:SetDeviceClass(device.Class)
		end
		if changed.Viewport or changed.Insets then
			self:_applyGeometry()
			self:_refreshRestoreButton()
		end
		if changed.Class then
			self:_refreshRestoreButton()
		end
	end))

	self._janitor:Add(self.Tokens.Changed:Connect(function()
		self:_applyTokens()
	end))

	self._janitor:Add(self.Theme.Changed:Connect(function()
		self:_flashThemeSwap()
		self:_refreshChromeIcons()
		for _, tab in self._tabs do
			tab:_setSelected(tab._selected)
		end
	end))

	-- Edge swipe opens the mobile drawer; TabSwipeOffset/TabSwipeFrom configure
	-- tab transition motion rather than touch navigation.
	self._janitor:Add(self.Input.Began:Connect(function(input, processed)
		if processed or self._layout ~= "Drawer" or input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local start = input.Position
		local dx = 0
		if not self._drawer and start.X <= 24 then
			self.Input:CapturePointer(self, input, function(move)
				dx = move.Position.X - start.X
			end, function()
				if dx > 60 then
					self:OpenDrawer()
				end
			end)
		elseif self._drawer then
			self.Input:CapturePointer(self, input, function(move)
				dx = move.Position.X - start.X
			end, function()
				if dx < -60 then
					self:CloseDrawer()
				end
			end)
		end
	end))

	return self
end

function Window:_responsiveLayout()
	if self._minimal then
		return "Minimal"
	end
	local width = self.Device.Viewport.X
	if width < self._sidebarCollapseThreshold then
		return "Drawer"
	end
	if self._sidebarCompacted then
		return "Rail"
	end
	if self._enableCompacting and not self._disableCompactingSnap and width < self._compactWidthActivation then
		return "Rail"
	end
	return "Wide"
end

function Window:_bind(instance: Instance, map: { [string]: any })
	local handles = self.Theme:BindMany(instance, map)
	local released = false
	local destroying
	local function release()
		if released then
			return
		end
		released = true
		self.Theme:Unbind(handles)
		if destroying then
			destroying:Disconnect()
		end
		self._janitor:Release(release)
	end
	destroying = instance.Destroying:Connect(release)
	self._janitor:Add(release, nil, release)
	return handles
end

function Window:_build()
	local tokens = self.Tokens

	self._root = New("Frame", {
		Name = "Window",
		Size = self._size,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = self.Layers.Root,
	})
	self._janitor:Add(self._root)
	self._rootCorner = New("UICorner", { CornerRadius = UDim.new(0, self._cornerRadius), Parent = self._root })
	self._rootStroke = New("UIStroke", {
		Thickness = tokens:Get("Stroke"),
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = self._root,
	})
	self:_bind(self._root, { BackgroundColor3 = "Canvas" })
	self._backgroundImage = New("ImageLabel", {
		Name = "BackgroundImage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = "",
		ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Crop,
		Visible = false,
		ZIndex = 1,
		Parent = self._root,
	})
	self._backgroundImageCorner = New("UICorner", {
		CornerRadius = UDim.new(0, self._cornerRadius),
		Parent = self._backgroundImage,
	})
	self._rootStroke.Transparency = 0.25
	self:_bind(self._rootStroke, { Color = "BorderStrong" })

	self:_buildHeader()
	self:_buildBody()
	self:_buildFooter()
	self:_buildResizeGrip()
	if self._minimal then
		self:_buildMinimal()
	end
	self:SetWindowOpacity(self._windowOpacity)
	if self._backgroundImageSource then
		self:SetBackgroundImage(self._backgroundImageSource, self._backgroundImageTransparency)
	end

	-- Covers a theme swap so 2000 instant assignments read as one transition
	-- instead of a flicker. Cheaper than tweening every binding.
	self._flash = New("Frame", {
		Name = "ThemeFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 50,
		Visible = false,
		Parent = self._root,
	})
	self._flashCorner = New("UICorner", {
		CornerRadius = UDim.new(0, self._cornerRadius),
		Parent = self._flash,
	})
	self._janitor:Add(self._flash)

	self._restoreButton = New("TextButton", {
		Name = "Restore",
		Size = UDim2.fromOffset(132, 32),
		Position = UDim2.new(0.5, 0, 0, math.max(12, self.Device.Insets.Top + 10)),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = self._showText,
		Font = self.Fonts.Medium,
		TextSize = self.Tokens:Get("FontSmall"),
		Visible = false,
		ZIndex = 1000,
		Parent = self.Layers.Toast,
	})
	self._restoreCorner =
		New("UICorner", { CornerRadius = UDim.new(0, self.Tokens:Get("CornerMd")), Parent = self._restoreButton })
	local restoreStroke = New("UIStroke", { Thickness = 1, Transparency = 0.55, Parent = self._restoreButton })
	self:_bind(self._restoreButton, { BackgroundColor3 = "SurfaceRaised", TextColor3 = "Text" })
	self:_bind(restoreStroke, { Color = "Border" })
	self._janitor:Add(self._restoreButton.MouseButton1Click:Connect(function()
		self:Show()
	end))
	self:SetRestoreButton(self._restoreSpec)
end

function Window:_ensureGroupHeader(group)
	if not group or group == "" then
		return nil
	end
	local existing = self._groups[group]
	if existing then
		return existing
	end
	self._groupSeq += 1
	local index = self._groupSeq
	local t = self.Tokens
	local root = New("Frame", {
		Name = "Group_" .. tostring(index),
		Size = UDim2.new(1, -12, 0, 24),
		BackgroundTransparency = 1,
		LayoutOrder = index * 1000,
		Parent = self._navList,
	})
	local accent = New("Frame", {
		Name = "Accent",
		Size = UDim2.fromOffset(3, 3),
		Position = UDim2.new(0, 4, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BorderSizePixel = 0,
		Parent = root,
	})
	New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = accent })
	self:_bind(accent, { BackgroundColor3 = "AccentMuted" })
	local label = New("TextLabel", {
		Name = "Label",
		Size = UDim2.new(1, -14, 1, 0),
		Position = UDim2.fromOffset(14, 0),
		BackgroundTransparency = 1,
		Font = self.Fonts.Bold,
		TextSize = t:Get("FontCaption"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.upper(self.Locale:Resolve(group)),
		Parent = root,
	})
	self:_bind(label, { TextColor3 = "TextTertiary" })
	existing = { Index = index, Root = root, Label = label, Title = group }
	self._groups[group] = existing
	return existing
end
function Window:_navLayoutOrder(group, order)
	local g = self:_ensureGroupHeader(group)
	return (g and g.Index * 1000 or 0) + (order or 1)
end
function Window:_refreshGroups()
	for _, g in self._groups do
		if g.Label then
			g.Label.Text = string.upper(self.Locale:Resolve(g.Title))
			g.Label.Visible = true
			if g.Root then
				g.Root.Visible = self._layout ~= "Rail"
			end
		end
	end
end

function Window:AddTab(options)
	if type(options) ~= "table" or type(options.Title) ~= "string" then
		error("[BobloUI] AddTab requires a table with a Title string.", 2)
	end

	-- Validate BEFORE constructing: a rejected tab must not leave Instances behind.
	local id = options.Id or Util.slug(options.Title)
	if self.Registry then
		self.Registry:AssertAvailable(id, 2)
	end
	for _, existing in self._tabs do
		if existing.Id == id then
			error(`[BobloUI] duplicate tab Id "{id}". Tab ids must be unique per window.`, 2)
		end
	end

	local tab = Tab.new(self, options)
	table.insert(self._tabs, tab)
	if self.Registry then
		self.Registry:Add(tab, { Id = id, Type = "Tab", Title = options.Title, Path = options.Title, Persist = false })
	end
	if not self._active and tab._button.Visible then
		self:_selectTab(tab)
	else
		tab:_setSelected(false)
	end

	self:_applyLayout(self._layout, true)
	if self._minimal then
		self:_refreshMinimalMenu()
	end
	if not options._system and self._settingsService and not self._settingsService._mounted then
		self._settingsService:_ensureMounted()
	end
	return tab
end

function Window:Get(id: string)
	return self.Registry and self.Registry:Get(id) or nil
end

function Window:GetTab(id: string)
	for _, tab in self._tabs do
		if tab.Id == id then
			return tab
		end
	end
	return nil
end

function Window:_selectTab(tab)
	if tab.Locked then
		if self.Notify then
			self.Notify:Push({
				Title = tab.Title,
				Content = tab.LockedReason or "This tab is locked",
				Variant = "Warning",
				Duration = 3,
			})
		end
		return
	end
	if self._active == tab then
		return
	end
	if self._active then
		self._active:_setSelected(false)
	end
	self._active = tab
	tab:_setSelected(true)
	local tr = self._tabTransition or {}
	if tab._page and self._animationFlags.Tabs ~= false and tr.Style ~= "None" then
		local offset = tonumber(tr.Offset) or 10
		local dir = string.lower(tostring(tr.Direction or "Right"))
		local x, y = 0, 0
		if dir == "left" then
			x = -offset
		elseif dir == "up" or dir == "top" then
			y = -offset
		elseif dir == "down" or dir == "bottom" then
			y = offset
		else
			x = offset
		end
		tab._page.Position = UDim2.fromOffset(x, y)
		self.Motion:Tween(
			tab._page,
			TweenInfo.new(tonumber(tr.Duration) or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.new() },
			"Tabs"
		)
	end
	self:_refreshHeaderTitle()
	if self._minimal then
		self:_refreshMinimalMenu()
		self:_scheduleSectionLayouts()
	end
	self:CloseDrawer()
end

function Window:_selectFirstVisible()
	self._active = nil
	for _, tab in self._tabs do
		if tab._button.Visible and not tab.Locked then
			self:_selectTab(tab)
			return
		end
	end
	if self._minimal then
		self:_syncMinimalHeight()
	end
end

function Window:GetInstance(): Instance
	return self._root
end

function Window:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._destroying = true
	self:CloseDrawer()
	for _, tab in table.clone(self._tabs) do
		tab:Destroy()
	end
	self._tabs = {}
	self._active = nil
	self.Unloading:Destroy()
end

return Window
