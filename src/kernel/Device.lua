--!nonstrict
--[[
	Device — viewport, layout mode, insets, on-screen keyboard.

	Two independent axes, which most libraries conflate:

	  Layout  Wide / Rail / Drawer   -- STRUCTURE, driven by viewport width
	  Class   Desktop / Tablet / Phone -- INPUT + sizing, driven by capabilities

	A desktop window dragged narrow gets Drawer layout without becoming a phone.
	A tablet in landscape gets Rail without losing touch sizing.
]]

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Signal = require("@runtime/Signal")
local Janitor = require("@runtime/Janitor")

local Device = {}
Device.__index = Device

Device.Breakpoints = {
	Drawer = 700,
	Rail = 1100,
}

--- Viewport can change several times during a device rotation.
local DEBOUNCE = 0.1

local function layoutFor(width: number): string
	if width < Device.Breakpoints.Drawer then
		return "Drawer"
	elseif width < Device.Breakpoints.Rail then
		return "Rail"
	end
	return "Wide"
end

local function classFor(width: number): string
	local touch = UserInputService.TouchEnabled
	local keyboard = UserInputService.KeyboardEnabled
	-- A device with a keyboard is treated as a desktop even when it also has a
	-- touchscreen: the sizing that matters is the one the user actually uses.
	if touch and not keyboard then
		return if width < Device.Breakpoints.Drawer then "Phone" else "Tablet"
	end
	return "Desktop"
end

function Device.new()
	local self = setmetatable({
		Changed = Signal.new("Device.Changed"),

		Viewport = Vector2.new(1280, 720),
		Layout = "Wide",
		Class = "Desktop",
		Orientation = "Landscape",
		IsTouch = UserInputService.TouchEnabled,
		Insets = { Top = 0, Right = 0, Bottom = 0, Left = 0 },
		KeyboardHeight = 0,

		_janitor = Janitor.new("Device"),
		_pending = nil,
	}, Device)

	self:_recompute(true)
	self:_connect()

	return self
end

function Device:_camera(): Camera?
	return workspace.CurrentCamera
end

function Device:_readInsets()
	local top, bottom = 0, 0
	local left, right = 0, 0

	local ok, topLeft, bottomRight = pcall(function()
		return GuiService:GetGuiInset()
	end)
	if ok and topLeft then
		top = topLeft.Y
		left = topLeft.X
		if bottomRight then
			bottom = bottomRight.Y
			right = bottomRight.X
		end
	end

	-- TopbarInset covers notches / safe areas on newer clients.
	local okTopbar, topbar = pcall(function()
		return GuiService.TopbarInset
	end)
	if okTopbar and typeof(topbar) == "Rect" then
		top = math.max(top, topbar.Min.Y)
	end

	return { Top = top, Right = right, Bottom = bottom, Left = left }
end

function Device:_recompute(silent: boolean?)
	local camera = self:_camera()
	local viewport = camera and camera.ViewportSize or self.Viewport
	if viewport.X <= 0 or viewport.Y <= 0 then
		return
	end

	local changed = {}

	local function set(key, value)
		if self[key] ~= value then
			self[key] = value
			changed[key] = true
		end
	end

	set("Viewport", viewport)
	set("Layout", layoutFor(viewport.X))
	set("Class", classFor(viewport.X))
	set("Orientation", if viewport.Y > viewport.X then "Portrait" else "Landscape")
	set("IsTouch", UserInputService.TouchEnabled)

	local insets = self:_readInsets()
	local current = self.Insets
	if
		insets.Top ~= current.Top
		or insets.Bottom ~= current.Bottom
		or insets.Left ~= current.Left
		or insets.Right ~= current.Right
	then
		self.Insets = insets
		changed.Insets = true
	end

	local keyboardHeight = 0
	if UserInputService.OnScreenKeyboardVisible then
		keyboardHeight = UserInputService.OnScreenKeyboardSize.Y
	end
	set("KeyboardHeight", keyboardHeight)

	if silent then
		return
	end
	if next(changed) then
		self.Changed:Fire(self, changed)
	end
end

function Device:_schedule()
	if self._pending then
		return
	end
	self._pending = task.delay(DEBOUNCE, function()
		self._pending = nil
		self:_recompute()
	end)
	self._janitor:Add(self._pending, nil, "pendingRecompute")
end

function Device:_connect()
	local janitor = self._janitor

	local function watchCamera(camera: Camera?)
		janitor:Remove("cameraViewport")
		if not camera then
			return
		end
		janitor:Add(
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				self:_schedule()
			end),
			nil,
			"cameraViewport"
		)
	end

	watchCamera(self:_camera())

	janitor:Add(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		watchCamera(self:_camera())
		self:_schedule()
	end))

	janitor:Add(GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
		self:_schedule()
	end))

	janitor:Add(UserInputService:GetPropertyChangedSignal("OnScreenKeyboardVisible"):Connect(function()
		-- Keyboard transitions must not wait out the rotation debounce.
		self:_recompute()
	end))

	janitor:Add(UserInputService:GetPropertyChangedSignal("OnScreenKeyboardSize"):Connect(function()
		self:_recompute()
	end))
end

--- Usable rectangle after topbar / notch insets.
function Device:SafeArea(): (Vector2, Vector2)
	local insets = self.Insets
	local position = Vector2.new(insets.Left, insets.Top)
	local size = Vector2.new(
		math.max(0, self.Viewport.X - insets.Left - insets.Right),
		math.max(0, self.Viewport.Y - insets.Top - insets.Bottom)
	)
	return position, size
end

function Device:Destroy()
	self._janitor:Destroy()
	self.Changed:Destroy()
end

return Device
