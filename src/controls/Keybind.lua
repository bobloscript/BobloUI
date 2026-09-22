--!nonstrict
local Create = require("@runtime/Create")
local Base = require("@controls/Base")
local Keybind = setmetatable({}, { __index = Base })
Keybind.__index = Keybind

local MODIFIERS = {
	Ctrl = { Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl },
	Shift = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift },
	Alt = { Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt },
	Meta = { Enum.KeyCode.LeftMeta, Enum.KeyCode.RightMeta },
}
local MODIFIER_ORDER = { "Ctrl", "Shift", "Alt", "Meta" }
local MODIFIER_ALIAS = {
	Control = "Ctrl",
	LeftControl = "Ctrl",
	RightControl = "Ctrl",
	LeftShift = "Shift",
	RightShift = "Shift",
	LeftAlt = "Alt",
	RightAlt = "Alt",
	LeftMeta = "Meta",
	RightMeta = "Meta",
}

local function keyName(key)
	if typeof(key) == "EnumItem" then
		return key.Name
	end
	if type(key) == "table" then
		return key.Key
	end
	return tostring(key or "None")
end
local function enumKey(name)
	if typeof(name) == "EnumItem" then
		return name
	end
	if type(name) == "string" then
		return Enum.KeyCode[name] or Enum.UserInputType[name]
	end
	return nil
end
local function normalizeModifiers(modifiers)
	local present = {}
	for _, modifier in modifiers or {} do
		local name = if typeof(modifier) == "EnumItem" then modifier.Name else tostring(modifier)
		name = MODIFIER_ALIAS[name] or name
		if MODIFIERS[name] then
			present[name] = true
		end
	end
	local out = {}
	for _, name in MODIFIER_ORDER do
		if present[name] then
			table.insert(out, name)
		end
	end
	return out
end
local function chordText(value)
	local parts = {}
	for _, modifier in normalizeModifiers(type(value) == "table" and value.Modifiers or {}) do
		table.insert(parts, modifier)
	end
	table.insert(parts, keyName(value))
	return table.concat(parts, " + ")
end
local function containsKey(list, key)
	for _, candidate in list or {} do
		if candidate == key or keyName(candidate) == keyName(key) then
			return true
		end
	end
	return false
end

function Keybind.new(section, options)
	options = options or {}
	local self = setmetatable({}, Keybind)
	self.Mode = options.Mode or (type(options.Default) == "table" and options.Default.Mode) or "Toggle"
	self._actionCallback = options.Callback or options.Clicked
	self.CustomModes = options.CustomModes or options.Modes or {}
	self.AllowedModes = table.clone(options.AllowedModes or { "Toggle", "Hold", "Always" })
	for mode in self.CustomModes do
		if not table.find(self.AllowedModes, mode) then
			table.insert(self.AllowedModes, mode)
		end
	end
	if not table.find(self.AllowedModes, self.Mode) then
		error(`[BobloUI] keybind mode "{self.Mode}" is not allowed.`, 3)
	end
	self.Blacklist = options.Blacklist or options.Blacklisted or {}
	self.Whitelist = options.Whitelist or options.Whitelisted
	self.ModifierBlacklist = options.ModifierBlacklist or options.BlacklistModifiers or options.BlacklistedModifiers
	self.ModifierWhitelist = options.ModifierWhitelist or options.WhitelistedModifiers
	self.ExactModifiers = options.ExactModifiers == true
	self.WaitForCallback = options.WaitForCallback == true
	self._callbackBusy = false
	self.Mobile = options.Mobile ~= false
	self.MobileText = options.MobileText or options.Title
	self.NoUI = options.NoUI == true
	self.ShowInHUD = options.ShowInHUD
	self._attached = options.AttachTo
	local syncToggle = if options.SyncToggle ~= nil then options.SyncToggle else options.SyncToggleState
	self.SyncToggle = if syncToggle == nil
		then self._attached and self._attached.Type == "Toggle"
		else syncToggle == true
	self._binding = nil
	self._capturing = false

	local default = options.Default
	local stored
	if type(default) == "table" then
		stored = {
			Key = keyName(default.Key or Enum.KeyCode.E),
			Mode = default.Mode or self.Mode,
			Modifiers = normalizeModifiers(default.Modifiers or options.Modifiers or options.DefaultModifiers),
		}
	else
		stored = {
			Key = keyName(default or Enum.KeyCode.E),
			Mode = self.Mode,
			Modifiers = normalizeModifiers(options.Modifiers or options.DefaultModifiers),
		}
	end
	local baseOptions = table.clone(options)
	baseOptions.Callback = nil
	if self.NoUI or (section._window.Device.Class == "Phone" and baseOptions.Visible == nil) then
		baseOptions.Visible = false
	end
	Base.init(self, section, "Keybind", baseOptions, { Stateful = true, Default = stored, Adaptive = true })
	local handle = Base.finish(self)
	if options.ChangedCallback then
		handle:OnChanged(options.ChangedCallback)
	end
	return handle
end

function Keybind:_mountValue(host)
	local w = self._window
	local t = w.Tokens
	self._button = Create.New("TextButton", {
		Size = UDim2.new(1, 0, 0, t:Get("FieldHeight")),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Font = w.Fonts.Medium,
		TextSize = t:Get("FontSmall"),
		Parent = host,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, t:Get("FieldRadius")), Parent = self._button })
	self._stroke = Create.New("UIStroke", {
		Thickness = 1,
		Transparency = 0.45,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = self._button,
	})
	w:_bind(self._stroke, { Color = "BorderSubtle" })
	w:_bind(self._button, { BackgroundColor3 = "ControlInset", TextColor3 = "TextSecondary" })
	self._janitor:Add(self._button.MouseEnter:Connect(function()
		self._button.BackgroundColor3 = w.Theme:Get("SurfaceHover")
	end))
	self._janitor:Add(self._button.MouseLeave:Connect(function()
		if not self._capturing then
			self._button.BackgroundColor3 = w.Theme:Get("ControlInset")
		end
	end))
	self._janitor:Add(self._button.MouseButton1Click:Connect(function()
		if not self:IsDisabled() then
			self:Capture()
		end
	end))
	self:_rebind()
end

function Keybind:_render(value)
	if type(value) == "table" then
		self.Mode = value.Mode or self.Mode
	end
	if self._button then
		self._button.Text = if self._capturing then "Press a key…" else `{chordText(value)}  ·  {self.Mode}`
		self._button.BackgroundColor3 = self._window.Theme:Get(self._capturing and "AccentSoft" or "ControlInset")
		self._stroke.Color = self._window.Theme:Get(self._capturing and "AccentBorder" or "BorderSubtle")
		self:_rebind()
	end
end

function Keybind:_dispatch(active)
	if self.WaitForCallback and self._callbackBusy then
		return
	end
	local function dispatch()
		local attached = self._attached
		if attached and not attached._destroyed then
			if self.SyncToggle and attached.SetValue then
				attached:SetValue(active)
			elseif active and attached.Click then
				attached:Click()
			end
		end
		if self._actionCallback then
			self._actionCallback(active, self)
		end
	end
	if self.WaitForCallback then
		self._callbackBusy = true
	end
	local ok, err = xpcall(dispatch, debug.traceback)
	self._callbackBusy = false
	if not ok then
		warn(err)
	end
end

function Keybind:_rebind()
	if self._binding then
		self._janitor:Release("keybinding")
		self._binding:Destroy()
		self._binding = nil
	end
	local value = self:GetValue()
	if not self._mounted or type(value) ~= "table" then
		return
	end
	local key = enumKey(value.Key)
	local modifiers = normalizeModifiers(value.Modifiers)
	if not key or not self:_keyAllowed(key) or not self:_modifiersAllowed(modifiers) then
		return
	end
	self._binding = self._window.Input:BindKey(self.Id or tostring(self), key, value.Mode or self.Mode, function(active)
		self:_dispatch(active)
	end, {
		Modifiers = modifiers,
		ExactModifiers = self.ExactModifiers,
		ModeHandler = self.CustomModes[value.Mode or self.Mode],
	})
	self._janitor:Add(self._binding, "Destroy", "keybinding")
end

function Keybind:_capturedModifiers(primary)
	local out = {}
	for _, name in MODIFIER_ORDER do
		for _, key in MODIFIERS[name] do
			if key ~= primary and self._window.Input:IsKeyDown(key) then
				table.insert(out, name)
				break
			end
		end
	end
	return out
end

function Keybind:_keyAllowed(key)
	if self.Whitelist and not containsKey(self.Whitelist, key) then
		return false
	end
	return not containsKey(self.Blacklist, key)
end

function Keybind:_modifiersAllowed(modifiers)
	local normalized = normalizeModifiers(modifiers)
	local allowed = if self.ModifierWhitelist ~= nil then normalizeModifiers(self.ModifierWhitelist) else nil
	local denied = normalizeModifiers(self.ModifierBlacklist)
	for _, modifier in normalized do
		if allowed and not table.find(allowed, modifier) then
			return false
		end
		if table.find(denied, modifier) then
			return false
		end
	end
	return true
end

function Keybind:Capture()
	if self._capturing then
		return self
	end
	self._capturing = true
	self:_render(self:GetValue())
	local arm
	arm = function()
		local cancel = self._window.Input:CaptureNextKey(function(key)
			self._janitor:Release("capture")
			if self._destroyed then
				return
			end
			if key == Enum.KeyCode.Escape then
				self._capturing = false
				self:_render(self:GetValue())
				return
			end
			if MODIFIER_ALIAS[key.Name] then
				arm()
				return
			end
			if not self:_keyAllowed(key) then
				arm()
				return
			end
			local modifiers = self:_capturedModifiers(key)
			if not self:_modifiersAllowed(modifiers) then
				arm()
				return
			end
			self._capturing = false
			local value = table.clone(self:GetValue() or {})
			value.Key = key.Name
			value.Mode = self.Mode
			value.Modifiers = modifiers
			self:SetValue(value)
		end, function()
			if self._destroyed then
				return
			end
			self._capturing = false
			self:_render(self:GetValue())
		end)
		self._janitor:Add(cancel, nil, "capture")
	end
	arm()
	return self
end

function Keybind:Cancel()
	if self._capturing then
		self._janitor:Remove("capture")
		self._capturing = false
		self:_render(self:GetValue())
	end
	return self
end

function Keybind:SetMode(mode)
	if not table.find(self.AllowedModes, mode) then
		error(`[BobloUI] keybind mode "{mode}" is not allowed.`, 2)
	end
	self.Mode = mode
	local value = table.clone(self:GetValue() or {})
	value.Mode = mode
	return self:SetValue(value)
end

function Keybind:SetKey(key, modifiers)
	local resolved = enumKey(key)
	if not resolved or not self:_keyAllowed(resolved) then
		return false
	end
	local value = table.clone(self:GetValue() or {})
	value.Key = resolved.Name
	if modifiers ~= nil then
		local normalized = normalizeModifiers(modifiers)
		if not self:_modifiersAllowed(normalized) then
			return false
		end
		value.Modifiers = normalized
	end
	self:SetValue(value)
	return self
end

function Keybind:SetModifiers(modifiers)
	local normalized = normalizeModifiers(modifiers)
	if not self:_modifiersAllowed(normalized) then
		return false
	end
	local value = table.clone(self:GetValue() or {})
	value.Modifiers = normalized
	return self:SetValue(value)
end

function Keybind:GetModifiers()
	return normalizeModifiers((self:GetValue() or {}).Modifiers)
end

function Keybind:Attach(control, syncToggle)
	self._attached = control
	self.SyncToggle = if syncToggle == nil then control and control.Type == "Toggle" else syncToggle == true
	return self
end

function Keybind:Trigger()
	if self._binding and not self:IsDisabled() then
		self._binding:Trigger()
	end
	return self
end

function Keybind:IsActive()
	return self._binding and self._binding.Active or false
end

function Keybind:Focus()
	return self:Capture()
end

function Keybind:_applyValueTokens()
	if self._button then
		self._button.Size = UDim2.new(1, 0, 0, self._window.Tokens:Get("FieldHeight"))
		self._button.TextSize = self._window.Tokens:Get("FontSmall")
	end
end

return Keybind
