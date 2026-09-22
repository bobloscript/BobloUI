--!nonstrict
local Create = require("@runtime/Create")
local Janitor = require("@runtime/Janitor")
local HUD = {}
HUD.__index = HUD

local function keyText(value)
	if type(value) ~= "table" then
		return tostring(value or "None")
	end
	local parts = {}
	for _, modifier in value.Modifiers or {} do
		table.insert(parts, tostring(modifier))
	end
	table.insert(parts, tostring(value.Key or "None"))
	return table.concat(parts, " + ")
end

function HUD.new(window)
	local self = setmetatable({
		_window = window,
		_janitor = Janitor.new("HUD"),
		_watermark = nil,
		_keybind = nil,
		_watermarkSpec = nil,
		_keybindEnabled = false,
		_keybindSide = "Right",
		_alive = true,
		_rows = {},
		_bindings = {},
		_trackJanitor = nil,
		_activePollThread = nil,
	}, HUD)
	return self
end

-- ===== Watermark =========================================================

function HUD:_ensureWatermark()
	if self._watermark then
		return
	end
	local w = self._window
	self._watermark = Create.New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.XY,
		Position = UDim2.fromOffset(12, w.Device.Insets.Top + 12),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Font = w.Fonts.Medium,
		TextSize = w.Tokens:Get("FontSmall"),
		Text = "",
		Parent = w.Layers.Toast,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, 6), Parent = self._watermark })
	Create.New("UIPadding", {
		PaddingTop = UDim.new(0, 5),
		PaddingBottom = UDim.new(0, 5),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = self._watermark,
	})
	local s = Create.New("UIStroke", { Thickness = 1, Transparency = 0.5, Parent = self._watermark })
	w:_bind(self._watermark, { BackgroundColor3 = "SurfaceRaised", TextColor3 = "TextSecondary" })
	w:_bind(s, { Color = "Border" })
end

function HUD:SetWatermark(spec)
	if spec == false or spec == nil then
		if self._watermark then
			self._watermark:Destroy()
			self._watermark = nil
		end
		self._watermarkSpec = nil
		return self
	end
	self._watermarkSpec = spec
	self:_ensureWatermark()
	self:_refreshWatermark()
	return self
end

function HUD:_refreshWatermark()
	if self._watermark and self._watermarkSpec then
		local text = if type(self._watermarkSpec) == "function"
			then select(2, pcall(self._watermarkSpec))
			else self._watermarkSpec
		self._watermark.Text = tostring(text or "")
	end
end

-- ===== Keybind HUD =======================================================

function HUD:_ensureKeybind()
	if self._keybind then
		return
	end
	local w = self._window
	local side = self._keybindSide

	self._keybind = Create.New("Frame", {
		Name = "KeybindHUD",
		Size = UDim2.fromOffset(200, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = if side == "Left"
			then UDim2.new(0, 12, 0.5, 0)
			else UDim2.new(1, -212, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Parent = w.Layers.Toast,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, 6), Parent = self._keybind })
	Create.New("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = self._keybind,
	})
	self._keyLayout = Create.List(2)
	self._keyLayout.Parent = self._keybind
	local s = Create.New("UIStroke", { Thickness = 1, Transparency = 0.5, Parent = self._keybind })
	w:_bind(self._keybind, { BackgroundColor3 = "SurfaceRaised" })
	w:_bind(s, { Color = "Border" })

	-- Draggable
	local dragJanitor = w.Input:AttachDrag(self._keybind, function(delta)
		self._keybind.Position = UDim2.new(
			self._keybind.Position.X.Scale,
			self._keybind.Position.X.Offset + delta.X,
			self._keybind.Position.Y.Scale,
			self._keybind.Position.Y.Offset + delta.Y
		)
	end, function()
		return self._keybind ~= nil and self._keybind.Parent ~= nil
	end)
	self._janitor:Add(dragJanitor)

	-- Clamp to SafeArea
	self._janitor:Add(self._keybind:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_clampToSafeArea()
	end))
	self._janitor:Add(self._keybind:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
		self:_clampToSafeArea()
	end))
end

function HUD:_clampToSafeArea()
	if not self._keybind or not self._keybind.Parent then
		return
	end
	local w = self._window
	local pos, safeSize = w.Device:SafeArea()
	local absPos = self._keybind.AbsolutePosition
	local absSize = self._keybind.AbsoluteSize
	local clampedX = math.clamp(absPos.X, pos.X, pos.X + safeSize.X - absSize.X)
	local clampedY = math.clamp(absPos.Y, pos.Y, pos.Y + safeSize.Y - absSize.Y)
	if clampedX ~= absPos.X or clampedY ~= absPos.Y then
		self._keybind.Position = UDim2.fromOffset(clampedX, clampedY)
		self._keybind.AnchorPoint = Vector2.new(0, 0)
	end
end

function HUD:_destroyKeybind()
	if self._keybind then
		-- Unbind all theme bindings for rows before destroying
		for id, data in self._rows do
			if data._themeHandles then
				self._window.Theme:Unbind(data._themeHandles)
			end
			if data._keyHandles then
				self._window.Theme:Unbind(data._keyHandles)
			end
		end
		self._keybind:Destroy()
		self._keybind = nil
	end
	self._rows = {}
end

function HUD:SetKeybindHUD(enabled)
	if enabled == true or enabled == "Auto" then
		self._keybindEnabled = true
	elseif enabled == false or enabled == nil then
		self._keybindEnabled = false
		self:_stopActivePoll()
		self:_destroyKeybind()
	end
	if self._keybindEnabled then
		self:_rebuildKeybinds()
	end
	return self
end

function HUD:SetKeybindHUDSide(side)
	if side ~= "Left" and side ~= "Right" then
		error("[BobloUI] KeybindHUDSide must be 'Left' or 'Right'.", 2)
	end
	self._keybindSide = side
	if self._keybind then
		self._keybind.AnchorPoint = Vector2.new(0, 0.5)
		self._keybind.Position = if side == "Left"
			then UDim2.new(0, 12, 0.5, 0)
			else UDim2.new(1, -212, 0.5, 0)
	end
	return self
end

-- ===== Event-driven keybind tracking =====================================

function HUD:_startTracking()
	if self._trackingStarted then
		return
	end
	self._trackingStarted = true
	local w = self._window

	-- Track new keybinds
	self._janitor:Add(w.Registry.Added:Connect(function(entry)
		if entry.Type == "Keybind" and entry.Handle and not entry.Handle._destroyed then
			self:_trackKeybind(entry.Handle, entry.Id)
			self:_updateContainerVisibility()
		end
	end))

	-- Untrack removed keybinds
	self._janitor:Add(w.Registry.Removed:Connect(function(entry)
		if entry.Type == "Keybind" then
			self:_untrackKeybind(entry.Id)
			self:_updateContainerVisibility()
		end
	end))

	-- Track existing keybinds
	for _, entry in w.Registry:Entries() do
		if entry.Type == "Keybind" and entry.Handle and not entry.Handle._destroyed then
			self:_trackKeybind(entry.Handle, entry.Id)
		end
	end
end

function HUD:_trackKeybind(handle, id)
	if self._bindings[id] then
		return
	end
	local janitor = Janitor.new(`HUD_keybind[{id}]`)
	self._bindings[id] = { Handle = handle, Janitor = janitor }

	-- Subscribe to value changes (key/mode/modifiers changed)
	janitor:Add(handle.Changed:Connect(function()
		if self._keybindEnabled then
			self:_updateRow(id)
		end
	end))

	-- Build row if HUD is active and keybind should be shown
	if self._keybindEnabled and self:_shouldShowKeybind(handle) then
		self:_ensureRow(handle, id)
		self:_updateRow(id)
	end
end

function HUD:_untrackKeybind(id)
	local binding = self._bindings[id]
	if binding then
		binding.Janitor:Destroy()
		self._bindings[id] = nil
	end
	local data = self._rows[id]
	if data then
		if data._themeHandles then
			self._window.Theme:Unbind(data._themeHandles)
		end
		if data._keyHandles then
			self._window.Theme:Unbind(data._keyHandles)
		end
		if data.Instance and data.Instance.Parent then
			data.Instance:Destroy()
		end
		self._rows[id] = nil
	end
end

function HUD:_shouldShowKeybind(handle)
	if not handle or handle._destroyed then
		return false
	end
	-- NoUI only hides from palette/search, NOT from HUD
	if handle.ShowInHUD == false then
		return false
	end
	local v = handle:GetValue()
	if type(v) == "table" and v.Key == "None" then
		return false
	end
	if type(v) == "string" and v == "None" then
		return false
	end
	return true
end

function HUD:_ensureRow(handle, id)
	if self._rows[id] then
		return
	end
	self:_ensureKeybind()
	local w = self._window
	local isMobile = w.Device.Class == "Phone" and handle.Mobile ~= false

	local row = Create.New(if isMobile then "TextButton" else "TextLabel", {
		Name = `Row_{id}`,
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = if isMobile then 0.88 else 1,
		BorderSizePixel = 0,
		AutoButtonColor = if isMobile then false else nil,
		Font = w.Fonts.Regular,
		TextSize = w.Tokens:Get("FontSmall"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self._keybind,
	})

	-- Title label (left side)
	local titleLabel = Create.New("TextLabel", {
		Name = "TitleLabel",
		Size = UDim2.new(1, -50, 1, 0),
		BackgroundTransparency = 1,
		Font = w.Fonts.Regular,
		TextSize = w.Tokens:Get("FontSmall"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = handle.MobileText or handle.Title or id,
		Parent = row,
	})
	local titleHandles = w:_bind(titleLabel, { TextColor3 = "TextSecondary" })

	-- Key pill (right side) — only on desktop
	local keyLabel = nil
	local keyHandles = {}
	if not isMobile then
		keyLabel = Create.New("TextLabel", {
			Name = "KeyPill",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, 18),
			Position = UDim2.new(1, 0, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Font = w.Fonts.Medium,
			TextSize = w.Tokens:Get("FontCaption"),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = row,
		})
		Create.New("UICorner", { CornerRadius = UDim.new(0, 3), Parent = keyLabel })
		Create.New("UIPadding", {
			PaddingLeft = UDim.new(0, 5),
			PaddingRight = UDim.new(0, 5),
			Parent = keyLabel,
		})
		keyHandles = w:_bind(keyLabel, { BackgroundColor3 = "SurfaceInset", TextColor3 = "TextTertiary" })
		local keyStroke = Create.New("UIStroke", { Thickness = 1, Transparency = 0.5, Parent = keyLabel })
		w:_bind(keyStroke, { Color = "BorderSubtle" })
	end

	if isMobile then
		Create.New("UICorner", { CornerRadius = UDim.new(0, 5), Parent = row })
		Create.New("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			Parent = row,
		})
		local bgHandles = w:_bind(row, { BackgroundColor3 = "ControlHover" })
		row.MouseButton1Click:Connect(function()
			handle:Trigger()
		end)
		self._rows[id] = {
			Instance = row,
			TitleLabel = titleLabel,
			KeyLabel = keyLabel,
			_themeHandles = titleHandles,
			_keyHandles = keyHandles,
			_bgHandles = bgHandles,
		}
	else
		local rowHandles = w:_bind(row, { BackgroundColor3 = "ControlHover" })
		self._rows[id] = {
			Instance = row,
			TitleLabel = titleLabel,
			KeyLabel = keyLabel,
			_themeHandles = titleHandles,
			_keyHandles = keyHandles,
			_rowHandles = rowHandles,
		}
	end
	self._janitor:Add(row)
end

function HUD:_updateRow(id)
	local data = self._rows[id]
	local binding = self._bindings[id]
	if not data or not binding then
		return
	end
	local handle = binding.Handle
	local w = self._window

	-- Handle device change: destroy and recreate row if needed
	local isMobile = w.Device.Class == "Phone" and handle.Mobile ~= false
	local wasMobile = data.Instance:IsA("TextButton")
	if isMobile ~= wasMobile then
		-- Device changed, rebuild this row
		if data._themeHandles then
			w.Theme:Unbind(data._themeHandles)
		end
		if data._keyHandles then
			w.Theme:Unbind(data._keyHandles)
		end
		if data._bgHandles then
			w.Theme:Unbind(data._bgHandles)
		end
		if data._rowHandles then
			w.Theme:Unbind(data._rowHandles)
		end
		data.Instance:Destroy()
		self._rows[id] = nil
		if self:_shouldShowKeybind(handle) then
			self:_ensureRow(handle, id)
			data = self._rows[id]
			if not data then
				return
			end
		else
			return
		end
	end

	-- Handle value change: if key changed from None, row might not exist
	if not data then
		if self:_shouldShowKeybind(handle) then
			self:_ensureRow(handle, id)
			data = self._rows[id]
		end
		if not data then
			return
		end
	end

	-- Hide row if keybind should not be shown
	if not self:_shouldShowKeybind(handle) then
		data.Instance.Visible = false
		return
	end
	data.Instance.Visible = true

	-- Update content
	local v = handle:GetValue()
	local active = handle.IsActive and handle:IsActive() or false
	local title = handle.MobileText or handle.Title or id
	local keyStr = keyText(v)

	-- Update title text
	if data.TitleLabel then
		data.TitleLabel.Text = title
		-- Apply active color directly to avoid rebinding
		data.TitleLabel.TextColor3 = w.Theme:Get(if active then "Accent" else "TextSecondary")
	end

	-- Update key pill (desktop only)
	if data.KeyLabel then
		data.KeyLabel.Text = `[  {keyStr}  ]`
		-- Apply active colors directly
		data.KeyLabel.BackgroundColor3 = w.Theme:Get(if active then "AccentMuted" else "SurfaceInset")
		data.KeyLabel.TextColor3 = w.Theme:Get(if active then "Accent" else "TextTertiary")
	end

	-- Update mobile row background
	if data.Instance:IsA("TextButton") then
		data.Instance.BackgroundColor3 = w.Theme:Get("ControlHover")
	end
end

function HUD:_startActivePoll()
	if self._activePollThread then
		return
	end
	self._activePollThread = task.spawn(function()
		while self._alive and self._keybindEnabled do
			task.wait(0.5)
			if not self._alive or not self._keybindEnabled then
				break
			end
			for id, _ in self._rows do
				self:_updateRow(id)
			end
		end
		self._activePollThread = nil
	end)
	self._janitor:Add(self._activePollThread, nil, "activePoll")
end

function HUD:_stopActivePoll()
	if self._activePollThread then
		pcall(task.cancel, self._activePollThread)
		self._activePollThread = nil
	end
end

function HUD:_rebuildKeybinds()
	self:_startTracking()
	-- Rebuild all rows (handles device change, new keybinds, etc.)
	for id, data in self._rows do
		if data._themeHandles then
			self._window.Theme:Unbind(data._themeHandles)
		end
		if data._keyHandles then
			self._window.Theme:Unbind(data._keyHandles)
		end
		if data._bgHandles then
			self._window.Theme:Unbind(data._bgHandles)
		end
		if data._rowHandles then
			self._window.Theme:Unbind(data._rowHandles)
		end
		if data.Instance then
			data.Instance:Destroy()
		end
	end
	self._rows = {}

	-- Create rows for all visible keybinds
	for _, entry in self._window.Registry:Entries() do
		if entry.Type == "Keybind" and entry.Handle and not entry.Handle._destroyed then
			if self:_shouldShowKeybind(entry.Handle) then
				self:_ensureRow(entry.Handle, entry.Id)
				self:_updateRow(entry.Id)
			end
		end
	end

	self:_updateContainerVisibility()
	self:_startActivePoll()
end

function HUD:_updateContainerVisibility()
	if not self._keybindEnabled then
		return
	end

	-- Count visible keybinds
	local visibleCount = 0
	for _, entry in self._window.Registry:Entries() do
		if entry.Type == "Keybind" and entry.Handle and not entry.Handle._destroyed then
			if self:_shouldShowKeybind(entry.Handle) then
				visibleCount += 1
			end
		end
	end

	if visibleCount == 0 then
		-- Hide container but don't destroy — allow recovery
		if self._keybind then
			self._keybind.Visible = false
		end
		return
	end

	-- Show container and ensure rows exist
	self:_ensureKeybind()
	self._keybind.Visible = true

	for _, entry in self._window.Registry:Entries() do
		if entry.Type == "Keybind" and entry.Handle and not entry.Handle._destroyed then
			local id = entry.Id
			if self:_shouldShowKeybind(entry.Handle) then
				if not self._rows[id] then
					self:_ensureRow(entry.Handle, id)
				end
				self:_updateRow(id)
			elseif self._rows[id] then
				-- Keybind set to None, hide row
				self._rows[id].Instance.Visible = false
			end
		end
	end
end

-- ===== Public API ========================================================

function HUD:RefreshKeybindHUD()
	if self._keybindEnabled then
		-- Full rebuild to handle device changes
		self:_rebuildKeybinds()
	end
	return self
end

function HUD:Destroy()
	self._alive = false
	self:_stopActivePoll()
	for id, binding in self._bindings do
		binding.Janitor:Destroy()
	end
	self._bindings = {}
	for id, data in self._rows do
		if data._themeHandles then
			pcall(function() self._window.Theme:Unbind(data._themeHandles) end)
		end
		if data._keyHandles then
			pcall(function() self._window.Theme:Unbind(data._keyHandles) end)
		end
	end
	self._rows = {}
	self._janitor:Destroy()
	if self._watermark then
		self._watermark:Destroy()
	end
	if self._keybind then
		self._keybind:Destroy()
	end
end

return HUD
