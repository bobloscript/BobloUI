--!nonstrict
local Base = require("@controls/Base")
local Passthrough = setmetatable({}, { __index = Base })
Passthrough.__index = Passthrough

function Passthrough.new(section, options)
	options = options or {}
	if typeof(options.Instance) ~= "Instance" or not options.Instance:IsA("GuiObject") then
		error("[BobloUI] AddPassthrough requires Instance = GuiObject.", 3)
	end
	local self = setmetatable({}, Passthrough)
	self.Height = math.max(1, tonumber(options.Height) or options.Instance.Size.Y.Offset or 40)
	self.Fill = options.Fill ~= false
	self.Clone = options.Clone == true
	self.DestroyInstance = options.DestroyInstance ~= false
	self._sourceInstance = options.Instance
	self._contentInstance = if self.Clone then options.Instance:Clone() else options.Instance
	self._originalParent = options.Instance.Parent
	Base.init(self, section, "Passthrough", options, { Stateful = false, Persist = false, Layout = "Stacked" })
	return Base.finish(self)
end

function Passthrough:_measure()
	local t = self._window.Tokens
	return t:Get("ControlHeight") + self.Height + (self.Description and 12 or 0) + 10
end

function Passthrough:_mountValue(host)
	self._contentInstance.Parent = host
	if self.Fill then
		self._contentInstance.Size = UDim2.new(1, 0, 0, self.Height)
	end
end

function Passthrough:_releaseContent()
	local content = self._contentInstance
	if not content then
		return
	end
	if self.Clone or self.DestroyInstance then
		content:Destroy()
	else
		content.Parent = self._originalParent
	end
	self._contentInstance = nil
end

function Passthrough:_applyValueTokens()
	if self._valueHost then
		self._valueHost.Size = UDim2.new(1, -self._window.Tokens:Get("ControlPadding") * 2, 0, self.Height)
	end
	if self.Fill and self._contentInstance then
		self._contentInstance.Size = UDim2.new(1, 0, 0, self.Height)
	end
end

function Passthrough:SetHeight(height)
	self.Height = math.max(1, tonumber(height) or self.Height)
	if self._mounted then
		self:_applyTokens()
	end
	return self
end

function Passthrough:SetInstance(instance, clone)
	if typeof(instance) ~= "Instance" or not instance:IsA("GuiObject") then
		error("[BobloUI] Passthrough:SetInstance expects GuiObject.", 2)
	end
	self:_releaseContent()
	if clone ~= nil then
		self.Clone = clone == true
	end
	self._sourceInstance = instance
	self._originalParent = instance.Parent
	self._contentInstance = if self.Clone then instance:Clone() else instance
	if self._valueHost then
		self:_mountValue(self._valueHost)
	end
	return self
end

function Passthrough:GetContentInstance()
	return self._contentInstance
end

function Passthrough:Destroy()
	self:_releaseContent()
	Base.Destroy(self)
end

return Passthrough
