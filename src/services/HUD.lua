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
	local _, safeSize = w.Device:SafeArea()
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

	-- Make draggable
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

	-- Clamp to SafeArea on size change
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

	-- Listen for new keybinds
	self._janitor:Add(w.Registry.Added:Connect(function(entry)
		if entry.Type == "Keybind" and entry.Handle and not entry.Handle._destroyed then
			self:_trackKeybind(entry.Handle, entry.Id)
		end
	end))

	-- Listen for removed keybinds
	self._janitor:Add(w.Registry.Removed:Connect(function(entry)
		if entry.Type == "Keybind" then
			self:_untrackKeybind(entry.Id)
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
	local w = self._window
	local janitor = Janitor.new(`HUD_keybind[{id}]`)
	self._bindings[id] = { Handle = handle, Janitor = janitor }

	-- Subscribe to value changes
	janitor:Add(handle.Changed:Connect(function()
		if self._keybindEnabled then
			self:_updateRow(id)
		end
	end))

	-- Build or update row
	if self._keybindEnabled then
		self:_ensureRow(handle, id)
		self:_updateRow(id)
		self:_updateContainerVisibility()
	end
end

function HUD:_untrackKeybind(id)
	local binding = self._bindings[id]
	if binding then
		binding.Janitor:Destroy()
		self._bindings[id] = nil
	end
	local row = self._rows[id]
	if row then
		row:Destroy()
		self._rows[id] = nil
	end
	self:_updateContainerVisibility()
end

function HUD:_shouldShowKeybind(handle)
	if not handle or handle._destroyed then
		return false
	end
	if handle.NoUI then
		return false
	end
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
	w:_bind(row, { TextColor3 = "TextSecondary", BackgroundColor3 = "ControlHover" })

	local keyLabel = Create.New("TextLabel", {
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
	w:_bind(keyLabel, { BackgroundColor3 = "SurfaceInset", TextColor3 = "TextTertiary" })
	local keyStroke = Create.New("UIStroke", { Thickness = 1, Transparency = 0.5, Parent = keyLabel })
	w:_bind(keyStroke, { Color = "BorderSubtle" })

	if isMobile then
		Create.New("UICorner", { CornerRadius = UDim.new(0, 5), Parent = row })
		Create.New("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			Parent = row,
		})
		row.MouseButton1Click:Connect(function()
			handle:Trigger()
		end)
	end

	self._rows[id] = row
	self._janitor:Add(row)

	-- Fit width to content
	local titleWidth = handle.MobileText or handle.Title or id
	local estimatedWidth = #tostring(titleWidth) * 7 + 60
	self._keybind.Size = UDim2.fromOffset(math.max(200, estimatedWidth), 0)
end

function HUD:_updateRow(id)
	local row = self._rows[id]
	local binding = self._bindings[id]
	if not row or not binding then
		return
	end
	local handle = binding.Handle
	local w = self._window

	if not self:_shouldShowKeybind(handle) then
		row.Visible = false
		return
	end
	row.Visible = true

	local v = handle:GetValue()
	local active = handle:IsActive()
	local title = handle.MobileText or handle.Title or id
	local keyStr = keyText(v)

	-- Title left, key pill right
	row.Text = `  {title}`
	local keyLabel = row:FindFirstChild("KeyPill")
	if keyLabel then
		keyLabel.Text = `[  {keyStr}  ]`
		w:_bind(keyLabel, {
			BackgroundColor3 = if active then "AccentMuted" else "SurfaceInset",
			TextColor3 = if active then "Accent" else "TextTertiary",
		})
	end

	-- Active accent on title
	w:_bind(row, {
		TextColor3 = if active then "Accent" else "TextSecondary",
	})
end

function HUD:_rebuildKeybinds()
	self:_startTracking()
	self:_updateContainerVisibility()
end

function HUD:_updateContainerVisibility()
	if not self._keybindEnabled then
		return
	end
	local w = self._window

	-- Count visible keybinds
	local visibleCount = 0
	for _, entry in w.Registry:Entries() do
		if entry.Type == "Keybind" and entry.Handle and not entry.Handle._destroyed then
			if self:_shouldShowKeybind(entry.Handle) then
				visibleCount += 1
			end
		end
	end

	if visibleCount == 0 then
		self:_destroyKeybind()
		return
	end

	self:_ensureKeybind()

	-- Update existing rows and create missing ones
	for _, entry in w.Registry:Entries() do
		if entry.Type == "Keybind" and entry.Handle and not entry.Handle._destroyed then
			if not self._bindings[entry.Id] then
				self:_trackKeybind(entry.Handle, entry.Id)
			end
			if self._rows[entry.Id] then
				self:_updateRow(entry.Id)
			end
		end
	end

	-- Remove stale rows
	for id, row in self._rows do
		local binding = self._bindings[id]
		if not binding or not binding.Handle or binding.Handle._destroyed then
			row:Destroy()
			self._rows[id] = nil
		elseif not self:_shouldShowKeybind(binding.Handle) then
			row.Visible = false
		end
	end
end

-- ===== Public API ========================================================

function HUD:RefreshKeybindHUD()
	if self._keybindEnabled then
		self:_updateContainerVisibility()
	end
	return self
end

function HUD:Destroy()
	self._alive = false
	for id, binding in self._bindings do
		binding.Janitor:Destroy()
	end
	self._bindings = {}
	self._janitor:Destroy()
	if self._watermark then
		self._watermark:Destroy()
	end
	if self._keybind then
		self._keybind:Destroy()
	end
end

return HUD
