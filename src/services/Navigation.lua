--!nonstrict
-- Keyboard/gamepad focus navigation for controls in the active tab.
local UserInputService = game:GetService("UserInputService")
local Create = require("@runtime/Create")
local Navigation = {}
Navigation.__index = Navigation

local NAV_TYPES =
	{ Button = true, Toggle = true, Slider = true, Dropdown = true, Input = true, Keybind = true, ColorPicker = true }
local function isNavKey(k)
	return k == Enum.KeyCode.Tab
		or k == Enum.KeyCode.DPadDown
		or k == Enum.KeyCode.DPadUp
		or k == Enum.KeyCode.DPadLeft
		or k == Enum.KeyCode.DPadRight
end
function Navigation.new(window, enabled)
	local self =
		setmetatable({ _window = window, _enabled = enabled ~= false, _focused = nil, _stroke = nil }, Navigation)
	self._conn = window.Input.Began:Connect(function(input, processed)
		self:_input(input, processed)
	end)
	self._removed = window.Registry.Removed:Connect(function(entry)
		if self._focused and entry.Handle == self._focused then
			self:Clear()
		end
	end)
	return self
end
function Navigation:SetEnabled(enabled)
	self._enabled = enabled ~= false
	if not self._enabled then
		self:Clear()
	end
	return self
end
function Navigation:IsEnabled()
	return self._enabled
end
function Navigation:_entries()
	local w = self._window
	local active = w._active
	if not active then
		return {}
	end
	local list = {}
	for _, entry in w.Registry:Entries() do
		local h = entry.Handle
		if
			NAV_TYPES[entry.Type]
			and h
			and not h._destroyed
			and entry.Tab == active.Id
			and (not h.IsVisible or h:IsVisible())
			and (not h.IsDisabled or not h:IsDisabled())
		then
			table.insert(list, entry)
		end
	end
	table.sort(list, function(a, b)
		local ha, hb = a.Handle, b.Handle
		local sa, sb = ha._section, hb._section
		local ao = (sa and sa._order or 0) * 10000 + (ha._order or 0)
		local bo = (sb and sb._order or 0) * 10000 + (hb._order or 0)
		if ao == bo then
			return tostring(a.Title) < tostring(b.Title)
		end
		return ao < bo
	end)
	return list
end
function Navigation:_drawFocus(handle)
	if self._stroke then
		self._stroke:Destroy()
		self._stroke = nil
	end
	local root = handle and handle:GetInstance()
	if not root then
		return
	end
	self._stroke = Create.New("UIStroke", {
		Name = "BobloUIKeyboardFocus",
		Thickness = 1.5,
		Transparency = 0.04,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = root,
	})
	self._window:_bind(self._stroke, { Color = "Accent" })
end
function Navigation:Focus(handle)
	if not handle or handle._destroyed then
		return self
	end
	self._focused = handle
	if handle.Reveal then
		handle:Reveal()
	end
	task.defer(function()
		if self._focused == handle and not handle._destroyed then
			self:_drawFocus(handle)
		end
	end)
	return self
end
function Navigation:GetFocused()
	return self._focused
end
function Navigation:Clear()
	self._focused = nil
	if self._stroke then
		self._stroke:Destroy()
		self._stroke = nil
	end
	return self
end
function Navigation:Move(delta)
	local entries = self:_entries()
	if #entries == 0 then
		return self
	end
	local index = 0
	for i, e in entries do
		if e.Handle == self._focused then
			index = i
			break
		end
	end
	if index == 0 then
		index = delta < 0 and (#entries + 1) or 0
	end
	index = ((index - 1 + delta) % #entries) + 1
	return self:Focus(entries[index].Handle)
end
function Navigation:Activate()
	local h = self._focused
	if not h or h._destroyed or (h.IsDisabled and h:IsDisabled()) then
		return self
	end
	if h.Type == "Button" and h.Click then
		h:Click()
	elseif h.Type == "Toggle" and h.Flip then
		h:Flip()
	elseif h.Type == "Dropdown" and h.Open then
		h:Open()
	elseif h.Type == "Input" and h.Focus then
		h:Focus()
	elseif h.Type == "Keybind" and h.Capture then
		h:Capture()
	elseif h.Type == "ColorPicker" and h.Open then
		h:Open()
	end
	return self
end
function Navigation:_stepSlider(dir)
	local h = self._focused
	if not h or h.Type ~= "Slider" then
		return false
	end
	local step = tonumber(h.Step) or 1
	h:SetValue((tonumber(h:GetValue()) or 0) + step * dir)
	return true
end
function Navigation:_input(input, processed)
	if not self._enabled or not self._window:IsVisible() then
		return
	end
	if UserInputService:GetFocusedTextBox() then
		return
	end
	local k = input.KeyCode
	-- Tab is commonly marked processed by Roblox; allow it when no TextBox owns focus.
	if k == Enum.KeyCode.Tab then
		local backwards = self._window.Input:IsKeyDown(Enum.KeyCode.LeftShift)
			or self._window.Input:IsKeyDown(Enum.KeyCode.RightShift)
		self:Move(backwards and -1 or 1)
		return
	end
	if processed then
		return
	end
	if k == Enum.KeyCode.DPadDown then
		self:Move(1)
		return
	end
	if k == Enum.KeyCode.DPadUp then
		self:Move(-1)
		return
	end
	if k == Enum.KeyCode.Left or k == Enum.KeyCode.DPadLeft then
		if self:_stepSlider(-1) then
			return
		end
	end
	if k == Enum.KeyCode.Right or k == Enum.KeyCode.DPadRight then
		if self:_stepSlider(1) then
			return
		end
	end
	if
		k == Enum.KeyCode.Return
		or k == Enum.KeyCode.KeypadEnter
		or k == Enum.KeyCode.Space
		or k == Enum.KeyCode.ButtonA
	then
		self:Activate()
		return
	end
	if k == Enum.KeyCode.Escape or k == Enum.KeyCode.ButtonB then
		self:Clear()
	end
end
function Navigation:Destroy()
	self:Clear()
	if self._conn then
		self._conn:Disconnect()
	end
	if self._removed then
		self._removed:Disconnect()
	end
end
return Navigation
