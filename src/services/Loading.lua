--!nonstrict
local Create = require("@runtime/Create")
local Janitor = require("@runtime/Janitor")
local Icon = require("@primitives/Icon")
local DialogSection = require("@services/DialogSection")
local Loading = {}
Loading.__index = Loading
function Loading.new(window)
	return setmetatable({ _window = window, _handle = nil }, Loading)
end
function Loading:Show(options)
	options = options or {}
	if self._handle then
		self._handle:Dismiss()
		self._handle = nil
	end
	local w = self._window
	local j = Janitor.new("Loading.Handle")
	local hasContent = options.Build ~= nil or options.Sidebar == true or options.ShowSidebar ~= nil
	local availableWidth = math.max(240, w.Device.Viewport.X - 32)
	local panelWidth =
		math.max(240, math.min(tonumber(options.WindowWidth) or (if hasContent then 620 else 420), availableWidth))
	local sideBySide = hasContent and panelWidth >= 500
	local desiredHeight = if not hasContent then 180 elseif sideBySide then 300 else 460
	local panelHeight = math.min(
		math.max(180, tonumber(options.WindowHeight) or desiredHeight),
		math.max(180, w.Device.Viewport.Y - 32)
	)
	local mainWidth = if sideBySide
		then math.clamp(
			tonumber(options.ContentWidth)
				or (tonumber(options.SidebarWidth) and panelWidth - tonumber(options.SidebarWidth) - 10)
				or math.floor(panelWidth * 0.58),
			240,
			panelWidth - 150
		)
		else panelWidth
	local initialIcon = options.LoadingIcon or options.Icon
	local layer = w.Layers:Push({
		Scrim = true,
		ScrimTransparency = options.ScrimTransparency,
		Modal = true,
		OnDismiss = function()
			self._handle = nil
			j:Destroy()
		end,
	})
	local panel = Create.New("Frame", {
		Size = UDim2.fromOffset(panelWidth, panelHeight),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0,
		Parent = layer.Container,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, w.Tokens:Get("CornerLg")), Parent = panel })
	local stroke = Create.New("UIStroke", { Thickness = 1, Transparency = 0.35, Parent = panel })
	w:_bind(panel, { BackgroundColor3 = "SurfaceRaised" })
	w:_bind(stroke, { Color = "Border" })
	local title = Create.New("TextLabel", {
		Size = UDim2.fromOffset(mainWidth - (initialIcon and 64 or 32), 24),
		Position = UDim2.fromOffset(initialIcon and 48 or 16, 16),
		BackgroundTransparency = 1,
		Font = w.Fonts.Bold,
		TextSize = w.Tokens:Get("FontHeading"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = options.Title or "Loading",
		Parent = panel,
	})
	w:_bind(title, { TextColor3 = "Text" })
	local loadingIcon = nil
	if initialIcon then
		loadingIcon = Icon.new(w, initialIcon, {
			Size = UDim2.fromOffset(20, 20),
			Position = UDim2.fromOffset(16, 18),
			Parent = panel,
		})
		Icon.setColor(loadingIcon, w.Theme:Get("Accent"))
	end
	local status = Create.New("TextLabel", {
		Size = UDim2.fromOffset(mainWidth - 32, 20),
		Position = UDim2.fromOffset(16, 48),
		BackgroundTransparency = 1,
		Font = w.Fonts.Regular,
		TextSize = w.Tokens:Get("FontBody"),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = options.Message or options.Status or "Preparing…",
		Parent = panel,
	})
	w:_bind(status, { TextColor3 = "TextSecondary" })
	local description = Create.New("TextLabel", {
		Size = UDim2.fromOffset(mainWidth - 32, 30),
		Position = UDim2.fromOffset(16, 70),
		BackgroundTransparency = 1,
		Font = w.Fonts.Regular,
		TextSize = w.Tokens:Get("FontSmall"),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = options.Description or "",
		Visible = options.Description ~= nil and options.Description ~= "",
		Parent = panel,
	})
	w:_bind(description, { TextColor3 = "TextTertiary" })
	local track = Create.New("Frame", {
		Size = UDim2.fromOffset(mainWidth - 32, 6),
		Position = UDim2.fromOffset(16, 108),
		BorderSizePixel = 0,
		Parent = panel,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
	w:_bind(track, { BackgroundColor3 = "ControlInset" })
	local fill = Create.New(
		"Frame",
		{ Size = UDim2.fromScale(math.clamp(options.Progress or 0, 0, 1), 1), BorderSizePixel = 0, Parent = track }
	)
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
	w:_bind(fill, { BackgroundColor3 = "Accent" })
	local step = Create.New("TextLabel", {
		Size = UDim2.fromOffset(mainWidth - 32, 18),
		Position = UDim2.fromOffset(16, 122),
		BackgroundTransparency = 1,
		Font = w.Fonts.Regular,
		TextSize = w.Tokens:Get("FontSmall"),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		Parent = panel,
	})
	w:_bind(step, { TextColor3 = "TextTertiary" })
	local actions = Create.New("Frame", {
		Size = UDim2.fromOffset(mainWidth - 32, 30),
		Position = UDim2.fromOffset(16, 144),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	local list = Create.List(6, Enum.FillDirection.Horizontal, { HorizontalAlignment = Enum.HorizontalAlignment.Right })
	list.Parent = actions
	local h = {
		_layer = layer,
		_service = self,
		Frame = panel,
		_title = title,
		_status = status,
		_description = description,
		_fill = fill,
		_step = step,
		_actions = actions,
		_icon = loadingIcon,
		_janitor = j,
		_steps = options.Steps or {},
		_currentStep = tonumber(options.CurrentStep) or 0,
		_totalSteps = math.max(1, tonumber(options.TotalSteps) or math.max(1, #(options.Steps or {}))),
		_dismissed = false,
		_iconSpinToken = 0,
		_loadingIconTweenTime = math.max(0, tonumber(options.LoadingIconTweenTime) or 0),
		_loadingIconColor = options.LoadingIconColor,
		_sideBySide = sideBySide,
		_mainWidth = mainWidth,
		_panelWidth = panelWidth,
	}
	local function restartIconSpin(handle)
		handle._iconSpinToken += 1
		local token = handle._iconSpinToken
		if not handle._icon then
			return
		end
		handle._icon.Rotation = 0
		local seconds = handle._loadingIconTweenTime
		if seconds <= 0 then
			return
		end
		task.spawn(function()
			while not handle._dismissed and handle._iconSpinToken == token and handle._icon and handle._icon.Parent do
				handle._icon.Rotation = 0
				w.Motion:Tween(
					handle._icon,
					TweenInfo.new(seconds, Enum.EasingStyle.Linear),
					{ Rotation = 360 },
					"Controls"
				)
				task.wait(seconds)
			end
		end)
	end
	if hasContent then
		local divider = Create.New("Frame", {
			Size = if sideBySide then UDim2.new(0, 1, 1, -24) else UDim2.new(1, -24, 0, 1),
			Position = if sideBySide then UDim2.fromOffset(mainWidth, 12) else UDim2.fromOffset(12, 184),
			BorderSizePixel = 0,
			Parent = panel,
		})
		w:_bind(divider, { BackgroundColor3 = "BorderSubtle" })
		local sidebar = Create.New("ScrollingFrame", {
			Size = if sideBySide
				then UDim2.new(1, -(mainWidth + 18), 1, -24)
				else UDim2.new(1, -24, 0, math.max(48, panelHeight - 204)),
			Position = if sideBySide then UDim2.fromOffset(mainWidth + 10, 12) else UDim2.fromOffset(12, 196),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollBarThickness = 2,
			Parent = panel,
		})
		Create.List(w.Tokens:Get("RowGap")).Parent = sidebar
		h._divider = divider
		h._sidebarHost = sidebar
		h.Sidebar = DialogSection.new(w, sidebar, j)
		h.Section = h.Sidebar
		if options.Build then
			options.Build(h.Sidebar, h)
		end
	end
	function h:SetTitle(text)
		self._title.Text = tostring(text or "")
		return self
	end
	function h:SetStatus(text)
		self._status.Text = tostring(text or "")
		return self
	end
	function h:SetMessage(text)
		return self:SetStatus(text)
	end
	function h:SetDescription(text)
		local value = tostring(text or "")
		self._description.Text = value
		self._description.Visible = value ~= ""
		return self
	end
	function h:SetProgress(value)
		self._fill.Size = UDim2.fromScale(math.clamp(tonumber(value) or 0, 0, 1), 1)
		return self
	end
	function h:SetStep(current, total, text)
		if text then
			self:SetStatus(text)
		end
		local c = tonumber(current) or 0
		local t = math.max(1, tonumber(total) or 1)
		self._currentStep = c
		self._totalSteps = t
		self._step.Text = `{c} / {t}`
		if not text and self._steps[c] then
			self:SetStatus(self._steps[c])
		end
		self:SetProgress(c / t)
		return self
	end
	function h:SetSteps(steps)
		self._steps = steps or {}
		return self
	end
	function h:SetCurrentStep(current, text)
		return self:SetStep(current, self._totalSteps, text)
	end
	function h:SetTotalSteps(total)
		return self:SetStep(self._currentStep, total)
	end
	function h:SetIcon(icon)
		if self._icon then
			self._icon:Destroy()
			self._icon = nil
		end
		if icon then
			self._icon = Icon.new(w, icon, {
				Size = UDim2.fromOffset(20, 20),
				Position = UDim2.fromOffset(16, 18),
				Parent = self.Frame,
			})
			Icon.setColor(
				self._icon,
				if typeof(self._loadingIconColor) == "Color3" then self._loadingIconColor else w.Theme:Get("Accent")
			)
		end
		local width = if self._sideBySide
				and self._sidebarHost
				and not self._sidebarVisible
			then self._panelWidth
			else self._mainWidth
		self._title.Position = UDim2.fromOffset(self._icon and 48 or 16, 16)
		self._title.Size = UDim2.fromOffset(width - (self._icon and 64 or 32), 24)
		restartIconSpin(self)
		return self
	end
	function h:SetLoadingIcon(icon)
		return self:SetIcon(icon)
	end
	function h:SetLoadingIconTweenTime(seconds)
		self._loadingIconTweenTime = math.max(0, tonumber(seconds) or 0)
		restartIconSpin(self)
		return self
	end
	function h:SetLoadingIconColor(color)
		self._loadingIconColor = color
		if self._icon then
			Icon.setColor(self._icon, if typeof(color) == "Color3" then color else w.Theme:Get("Accent"))
		end
		return self
	end
	function h:ShowSidebarPage(visible)
		if not self._sidebarHost then
			return false
		end
		visible = visible ~= false
		self._sidebarVisible = visible
		self._sidebarHost.Visible = visible
		self._divider.Visible = visible
		local width = if self._sideBySide and not visible then self._panelWidth else self._mainWidth
		self._title.Size = UDim2.fromOffset(width - (self._icon and 64 or 32), 24)
		self._status.Size = UDim2.fromOffset(width - 32, 20)
		self._description.Size = UDim2.fromOffset(width - 32, 30)
		self._fill.Parent.Size = UDim2.fromOffset(width - 32, 6)
		self._step.Size = UDim2.fromOffset(width - 32, 18)
		self._actions.Size = UDim2.fromOffset(width - 32, 30)
		return self
	end
	function h:ShowErrorPage(visible)
		self._errorVisible = visible ~= false
		self._fill.BackgroundColor3 = w.Theme:Get(self._errorVisible and "Error" or "Accent")
		self._actions.Visible = self._errorVisible
		return self
	end
	function h:SetErrorMessage(message)
		self:SetStatus(message)
		self:ShowErrorPage(true)
		return self
	end
	function h:SetErrorButtons(buttons)
		for _, child in self._actions:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for _, spec in buttons or {} do
			local b = Create.New("TextButton", {
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				Text = "  " .. tostring(spec.Text or "Retry") .. "  ",
				Font = w.Fonts.Medium,
				TextSize = w.Tokens:Get("FontSmall"),
				Parent = self._actions,
			})
			Create.New("UICorner", { CornerRadius = UDim.new(0, 7), Parent = b })
			w:_bind(b, {
				BackgroundColor3 = spec.Danger and "Error" or "ControlInset",
				TextColor3 = spec.Danger and "TextOnError" or "Text",
			})
			b.MouseButton1Click:Connect(function()
				if spec.Callback then
					pcall(spec.Callback)
				end
			end)
		end
		return self
	end
	function h:SetError(message, buttons)
		self:SetErrorMessage(message)
		self:SetErrorButtons(buttons)
		return self
	end
	function h:Dismiss()
		if self._dismissed then
			return
		end
		self._dismissed = true
		self._iconSpinToken += 1
		self._layer:Dismiss()
	end
	function h:Destroy()
		self:Dismiss()
	end
	function h:Continue()
		self:Dismiss()
	end
	if hasContent then
		h:ShowSidebarPage(options.ShowSidebar ~= false)
	end
	if options.LoadingIconColor ~= nil then
		h:SetLoadingIconColor(options.LoadingIconColor)
	end
	if options.LoadingIconTweenTime ~= nil then
		h:SetLoadingIconTweenTime(options.LoadingIconTweenTime)
	end
	if options.CurrentStep ~= nil or options.TotalSteps ~= nil then
		h:SetStep(h._currentStep, h._totalSteps)
	end
	self._handle = h
	return h
end
function Loading:Hide()
	if self._handle then
		self._handle:Dismiss()
		self._handle = nil
	end
end
function Loading:Destroy()
	self:Hide()
end
return Loading
