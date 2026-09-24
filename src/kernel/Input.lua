--!nonstrict
local UserInputService = game:GetService("UserInputService")
local Signal = require("@runtime/Signal")
local Janitor = require("@runtime/Janitor")
local Input = {}
Input.__index = Input
local function isPointerStart(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end
local function isPointerMove(i)
	return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end
local function matchesCapturedPointer(capture, input, moving)
	local captured = capture and capture.Input
	if not captured then
		return false
	end
	if captured.UserInputType == Enum.UserInputType.Touch then
		-- Every finger has its own InputObject. Accepting any Touch event here can
		-- teleport a drag to the position of a second finger.
		return input == captured
	end
	if captured.UserInputType == Enum.UserInputType.MouseButton1 then
		return input.UserInputType
			== (if moving then Enum.UserInputType.MouseMovement else Enum.UserInputType.MouseButton1)
	end
	return false
end
local function eventKey(i)
	return if i.KeyCode ~= Enum.KeyCode.Unknown then i.KeyCode else i.UserInputType
end
local MODIFIER_KEYS = {
	Ctrl = { Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl },
	Shift = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift },
	Alt = { Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt },
	Meta = { Enum.KeyCode.LeftMeta, Enum.KeyCode.RightMeta },
}
function Input.new()
	local self = setmetatable({
		Began = Signal.new("Input.Began"),
		Changed = Signal.new("Input.Changed"),
		Ended = Signal.new("Input.Ended"),
		_janitor = Janitor.new("Input"),
		_capture = nil,
		_keybinds = {},
		_nextCapture = nil,
	}, Input)
	self._janitor:Add(UserInputService.InputBegan:Connect(function(i, p)
		self:_began(i, p)
	end))
	self._janitor:Add(UserInputService.InputChanged:Connect(function(i, p)
		self:_changed(i, p)
	end))
	self._janitor:Add(UserInputService.InputEnded:Connect(function(i, p)
		self:_ended(i, p)
	end))
	return self
end
function Input:_began(i, processed)
	-- Capture is an explicit user action. Roblox often marks keys as processed
	-- when the game has its own binding, so gameProcessedEvent must not make
	-- key capture randomly fail. The capture path owns this input and returns.
	if self._nextCapture then
		local capture = self._nextCapture
		local key = if i.KeyCode ~= Enum.KeyCode.Unknown
			then i.KeyCode
			elseif i.UserInputType ~= Enum.UserInputType.MouseMovement then i.UserInputType
			else nil
		if key then
			self._nextCapture = nil
			capture.Callback(key)
			return
		end
	end

	-- Script-hub keybinds should still fire when the game consumes the same
	-- key. The one important exception is typing: never trigger a hub action
	-- while a TextBox/chat field has keyboard focus.
	local typing = UserInputService:GetFocusedTextBox() ~= nil
	local keyboard = i.KeyCode ~= Enum.KeyCode.Unknown
	if not typing and (not processed or keyboard) then
		local key = eventKey(i)
		local list = self._keybinds[key]
		if list then
			for _, h in table.clone(list) do
				if h.Enabled then
					h:_press()
				end
			end
		end
	end
	self.Began:Fire(i, processed)
end
function Input:_changed(i, processed)
	if self._capture and isPointerMove(i) and matchesCapturedPointer(self._capture, i, true) then
		local c = self._capture
		if c.Changed then
			c.Changed(i)
		end
	end
	self.Changed:Fire(i, processed)
end
function Input:_ended(i, processed)
	if self._capture and matchesCapturedPointer(self._capture, i, false) then
		local c = self._capture
		self._capture = nil
		if c.Ended then
			c.Ended(i)
		end
	end
	local key = eventKey(i)
	local list = self._keybinds[key]
	if list then
		for _, h in table.clone(list) do
			if h.Enabled then
				h:_release()
			end
		end
	end
	self.Ended:Fire(i, processed)
end
function Input:CapturePointer(owner, input, onChanged, onEnded)
	if not isPointerStart(input) then
		return false
	end
	if self._capture and self._capture.Ended then
		pcall(self._capture.Ended, input, true)
	end
	self._capture = { Owner = owner, Input = input, Changed = onChanged, Ended = onEnded }
	return true
end
function Input:CancelCapture(owner)
	if self._capture and (not owner or self._capture.Owner == owner) then
		local c = self._capture
		self._capture = nil
		if c.Ended then
			c.Ended(nil, true)
		end
	end
end
function Input:AttachDrag(gui, onDelta, enabledFn)
	local janitor = Janitor.new("Input.Drag")
	local startPos
	janitor:Add(gui.InputBegan:Connect(function(i)
		if not isPointerStart(i) then
			return
		end
		if enabledFn and not enabledFn() then
			return
		end
		startPos = i.Position
		self:CapturePointer(gui, i, function(move)
			onDelta(move.Position - startPos, move)
		end, function()
			startPos = nil
		end)
	end))
	return janitor
end
function Input:IsKeyDown(key)
	if typeof(key) ~= "EnumItem" then
		return false
	end
	if key.EnumType == Enum.KeyCode then
		return UserInputService:IsKeyDown(key)
	end
	local ok, result = pcall(UserInputService.IsMouseButtonPressed, UserInputService, key)
	return ok and result == true
end
function Input:CaptureNextKey(callback, onCancel)
	if type(callback) ~= "function" then
		error("[BobloUI] CaptureNextKey expects a callback.", 2)
	end
	if self._nextCapture then
		local previous = self._nextCapture
		self._nextCapture = nil
		if previous.OnCancel then
			pcall(previous.OnCancel)
		end
	end
	local capture = { Callback = callback, OnCancel = onCancel }
	self._nextCapture = capture
	local alive = true
	return function()
		if not alive then
			return
		end
		alive = false
		if self._nextCapture == capture then
			self._nextCapture = nil
			if capture.OnCancel then
				pcall(capture.OnCancel)
			end
		end
	end
end
function Input:_modifierDown(name)
	local keys = MODIFIER_KEYS[name]
	if not keys then
		return false
	end
	for _, key in keys do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end
function Input:_modifiersMatch(required, exact)
	local wanted = {}
	for _, name in required or {} do
		wanted[name] = true
		if not self:_modifierDown(name) then
			return false
		end
	end
	if exact then
		for name in MODIFIER_KEYS do
			if not wanted[name] and self:_modifierDown(name) then
				return false
			end
		end
	end
	return true
end
function Input:BindKey(id, key, mode, callback, options)
	mode = mode or "Toggle"
	options = options or {}
	local handle = {
		Id = id,
		Key = key,
		Mode = mode,
		Callback = callback,
		Enabled = true,
		Active = mode == "Always",
		_toggle = false,
		_input = self,
		Modifiers = options.Modifiers or {},
		ExactModifiers = options.ExactModifiers == true,
		ModeHandler = options.ModeHandler,
	}
	function handle:_press(force)
		if not force and not self._input:_modifiersMatch(self.Modifiers, self.ExactModifiers) then
			return
		end
		if self.Mode == "Hold" then
			self.Active = true
			self.Callback(true)
		elseif self.Mode == "Toggle" then
			self._toggle = not self._toggle
			self.Active = self._toggle
			self.Callback(self.Active)
		elseif self.Mode == "Always" then
			self.Active = true
			self.Callback(true)
		elseif self.ModeHandler then
			local handler = self.ModeHandler
			local result
			if type(handler) == "function" then
				result = handler("Press", self.Active, self)
			elseif type(handler) == "table" and type(handler.Press) == "function" then
				result = handler.Press(self.Active, self)
			end
			if result ~= nil then
				self.Active = result == true
			end
			self.Callback(self.Active)
		end
	end
	function handle:_release()
		if self.Mode == "Hold" and self.Active then
			self.Active = false
			self.Callback(false)
		elseif self.ModeHandler then
			local handler = self.ModeHandler
			local result
			if type(handler) == "function" then
				result = handler("Release", self.Active, self)
			elseif type(handler) == "table" and type(handler.Release) == "function" then
				result = handler.Release(self.Active, self)
			end
			if result ~= nil then
				self.Active = result == true
				self.Callback(self.Active)
			end
		end
	end
	function handle:SetActive(active, fire)
		self.Active = active == true
		self._toggle = self.Active
		if fire ~= false then
			self.Callback(self.Active)
		end
		return self
	end
	function handle:Trigger()
		self:_press(true)
		if self.Mode == "Hold" then
			self:_release()
		end
		return self
	end
	function handle:Destroy()
		local list = self._input._keybinds[self.Key]
		if list then
			local p = table.find(list, self)
			if p then
				table.remove(list, p)
			end
		end
	end
	local list = self._keybinds[key] or {}
	self._keybinds[key] = list
	table.insert(list, handle)
	return handle
end
function Input:Destroy()
	self:CancelCapture()
	if self._nextCapture then
		local capture = self._nextCapture
		self._nextCapture = nil
		if capture.OnCancel then
			pcall(capture.OnCancel)
		end
	end
	for _, list in self._keybinds do
		for _, h in list do
			h.Enabled = false
		end
	end
	self._keybinds = {}
	self._janitor:Destroy()
	self.Began:Destroy()
	self.Changed:Destroy()
	self.Ended:Destroy()
end
return Input
