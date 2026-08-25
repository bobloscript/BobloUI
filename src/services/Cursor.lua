--!nonstrict
local UserInputService = game:GetService("UserInputService")
local Create = require("@runtime/Create")
local Cursor = {}
Cursor.__index = Cursor
function Cursor.new(window)
	return setmetatable({ _window = window, _enabled = false, _root = nil, _conn = nil, _oldMouseIcon = nil }, Cursor)
end
function Cursor:SetEnabled(enabled, options)
	enabled = enabled == true
	if enabled == self._enabled then
		return self
	end
	self._enabled = enabled
	if not enabled then
		if self._conn then
			self._conn:Disconnect()
			self._conn = nil
		end
		if self._root then
			self._root:Destroy()
			self._root = nil
		end
		if self._oldMouseIcon ~= nil then
			UserInputService.MouseIconEnabled = self._oldMouseIcon
			self._oldMouseIcon = nil
		end
		return self
	end
	if self._window.Device.Class == "Phone" then
		self._enabled = false
		return self
	end
	options = options or {}
	self._oldMouseIcon = UserInputService.MouseIconEnabled
	UserInputService.MouseIconEnabled = false
	local w = self._window
	self._root = Create.New("Frame", {
		Size = UDim2.fromOffset(options.Size or 10, options.Size or 10),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 9999,
		Parent = w.Layers.Overlay,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self._root })
	w:_bind(self._root, { BackgroundColor3 = options.Token or "Accent" })
	local pos = UserInputService:GetMouseLocation()
	self._root.Position = UDim2.fromOffset(pos.X, pos.Y)
	self._conn = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement and self._root then
			self._root.Position = UDim2.fromOffset(input.Position.X, input.Position.Y)
		end
	end)
	return self
end
function Cursor:IsEnabled()
	return self._enabled
end
function Cursor:Destroy()
	self:SetEnabled(false)
end
return Cursor
