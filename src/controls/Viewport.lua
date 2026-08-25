--!nonstrict
local Create = require("@runtime/Create")
local Base = require("@controls/Base")
local Viewport = setmetatable({}, { __index = Base })
Viewport.__index = Viewport

local function bounds(object)
	if object:IsA("Model") then
		local ok, cf, size = pcall(object.GetBoundingBox, object)
		if ok then
			return cf, size
		end
	end
	if object:IsA("BasePart") then
		return object.CFrame, object.Size
	end
	return CFrame.new(), Vector3.new(4, 4, 4)
end

function Viewport.new(section, options)
	options = options or {}
	if typeof(options.Object) ~= "Instance" then
		error("[BobloUI] AddViewport requires Object = Instance.", 3)
	end
	if options.Camera ~= nil and (typeof(options.Camera) ~= "Instance" or not options.Camera:IsA("Camera")) then
		error("[BobloUI] AddViewport Camera must be a Camera instance.", 3)
	end
	local self = setmetatable({}, Viewport)
	self.Object = options.Object
	self.Clone = options.Clone ~= false
	self.DestroyObject = options.DestroyObject == true
	self.Camera = options.Camera
	self.Interactive = options.Interactive == true
	self.AutoFocus = options.AutoFocus ~= false
	self.Height = math.max(80, tonumber(options.Height) or 200)
	self._yaw = 35
	self._pitch = -18
	self._distance = 8
	Base.init(self, section, "Viewport", options, { Stateful = false, Persist = false, Layout = "Stacked" })
	return Base.finish(self)
end

function Viewport:_measure()
	local t = self._window.Tokens
	return t:Get("ControlHeight") + self.Height + (self.Description and 12 or 0) + 10
end

function Viewport:_mountValue(host)
	local w = self._window
	local t = w.Tokens
	self._viewport = Create.New("ViewportFrame", {
		Size = UDim2.new(1, 0, 0, self.Height),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(160, 160, 160),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
		Parent = host,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, t:Get("FieldRadius")), Parent = self._viewport })
	local stroke = Create.New("UIStroke", {
		Thickness = 1,
		Transparency = 0.5,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = self._viewport,
	})
	w:_bind(self._viewport, { BackgroundColor3 = "ControlInset" })
	w:_bind(stroke, { Color = "BorderSubtle" })
	self._world = Create.New("WorldModel", { Parent = self._viewport })
	self._cameraOwned = self.Camera == nil
	self._cameraOriginalParent = self.Camera and self.Camera.Parent or nil
	self._camera = self.Camera or Instance.new("Camera")
	self._camera.Parent = self._viewport
	self._viewport.CurrentCamera = self._camera
	self:_setWorldObject(self.Object)
	if self.AutoFocus then
		self:Focus()
	end
	self._janitor:Add(self._viewport.InputBegan:Connect(function(input)
		if not self.Interactive or self:IsDisabled() then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		local start = input.Position
		local yaw, pitch = self._yaw, self._pitch
		w.Input:CapturePointer(self, input, function(move)
			local delta = move.Position - start
			self._yaw = yaw - delta.X * 0.35
			self._pitch = math.clamp(pitch - delta.Y * 0.25, -80, 80)
			self:_updateCamera()
		end, function()
			if self.Callback then
				pcall(self.Callback, self)
			end
		end)
	end))
	self._janitor:Add(self._viewport.InputChanged:Connect(function(input)
		if self.Interactive and input.UserInputType == Enum.UserInputType.MouseWheel then
			self._distance = math.clamp(self._distance - input.Position.Z, 1.5, 80)
			self:_updateCamera()
		end
	end))
end

function Viewport:_releaseRenderObject()
	if self._renderObject then
		if self.Clone or self.DestroyObject then
			self._renderObject:Destroy()
		else
			self._renderObject.Parent = self._objectOriginalParent
		end
		self._renderObject = nil
	end
	self._objectOriginalParent = nil
end

function Viewport:_setWorldObject(object, clone)
	self:_releaseRenderObject()
	if clone ~= nil then
		self.Clone = clone == true
	end
	self.Object = object
	self._objectOriginalParent = if self.Clone then nil else object.Parent
	self._renderObject = if self.Clone then object:Clone() else object
	self._renderObject.Parent = self._world
end

function Viewport:_updateCamera()
	if not self._camera then
		return
	end
	local focus = self._focus or Vector3.new()
	local rotation = CFrame.Angles(math.rad(self._pitch), math.rad(self._yaw), 0)
	local offset = rotation:VectorToWorldSpace(Vector3.new(0, 0, self._distance))
	self._camera.CFrame = CFrame.lookAt(focus + offset, focus)
end

function Viewport:Focus()
	if not self._renderObject then
		return self
	end
	local cf, size = bounds(self._renderObject)
	self._focus = cf.Position
	local radius = math.max(size.X, size.Y, size.Z) * 0.5
	local fov = math.rad((self._camera and self._camera.FieldOfView or 40) * 0.5)
	self._distance = math.max(1.5, radius / math.max(0.1, math.tan(fov)) * 1.25)
	self:_updateCamera()
	return self
end

function Viewport:SetObject(object, clone)
	if typeof(object) ~= "Instance" then
		error("[BobloUI] Viewport:SetObject expects Instance.", 2)
	end
	if self._world then
		self:_setWorldObject(object, clone)
		if self.AutoFocus then
			self:Focus()
		end
	else
		self.Object = object
		if clone ~= nil then
			self.Clone = clone == true
		end
	end
	return self
end

function Viewport:SetCamera(camera)
	if typeof(camera) ~= "Instance" or not camera:IsA("Camera") then
		error("[BobloUI] Viewport:SetCamera expects Camera.", 2)
	end
	if self._camera then
		if self._cameraOwned then
			self._camera:Destroy()
		else
			self._camera.Parent = self._cameraOriginalParent
		end
	end
	self.Camera = camera
	self._cameraOwned = false
	self._cameraOriginalParent = camera.Parent
	self._camera = camera
	if self._viewport then
		camera.Parent = self._viewport
		self._viewport.CurrentCamera = camera
	end
	return self
end

function Viewport:SetInteractive(interactive)
	self.Interactive = interactive == true
	return self
end

function Viewport:SetHeight(height)
	self.Height = math.max(80, tonumber(height) or self.Height)
	if self._mounted then
		self:_applyTokens()
	end
	return self
end

function Viewport:_applyValueTokens()
	if self._valueHost then
		self._valueHost.Size = UDim2.new(1, -self._window.Tokens:Get("ControlPadding") * 2, 0, self.Height)
	end
	if self._viewport then
		self._viewport.Size = UDim2.new(1, 0, 0, self.Height)
	end
end

function Viewport:Destroy()
	self:_releaseRenderObject()
	if self._camera then
		if self._cameraOwned then
			self._camera:Destroy()
		else
			self._camera.Parent = self._cameraOriginalParent
		end
		self._camera = nil
	end
	Base.Destroy(self)
end

return Viewport
