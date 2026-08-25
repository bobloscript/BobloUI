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
		_alive = true,
	}, HUD)
	self._janitor:Add(task.spawn(function()
		while self._alive do
			self:_refresh()
			task.wait(0.25)
		end
	end))
	return self
end
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
	Create.New("UICorner", { CornerRadius = UDim.new(0, 7), Parent = self._watermark })
	Create.New("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 9),
		PaddingRight = UDim.new(0, 9),
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
	self:_refresh()
	return self
end
function HUD:_ensureKeybind()
	if self._keybind then
		return
	end
	local w = self._window
	self._keybind = Create.New("Frame", {
		Size = UDim2.fromOffset(230, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 12, 1, -12),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Parent = w.Layers.Toast,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, 8), Parent = self._keybind })
	Create.New("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = self._keybind,
	})
	self._keyLayout = Create.List(4)
	self._keyLayout.Parent = self._keybind
	local s = Create.New("UIStroke", { Thickness = 1, Transparency = 0.5, Parent = self._keybind })
	w:_bind(self._keybind, { BackgroundColor3 = "SurfaceRaised" })
	w:_bind(s, { Color = "Border" })
end
function HUD:SetKeybindHUD(enabled)
	self._keybindEnabled = enabled == true
	if self._keybindEnabled then
		self:_ensureKeybind()
	elseif self._keybind then
		self._keybind:Destroy()
		self._keybind = nil
	end
	return self
end
function HUD:_refresh()
	local w = self._window
	if self._watermark and self._watermarkSpec then
		local text = if type(self._watermarkSpec) == "function"
			then select(2, pcall(self._watermarkSpec))
			else self._watermarkSpec
		self._watermark.Text = tostring(text or "")
	end
	if self._keybindEnabled then
		self:_ensureKeybind()
		for _, child in self._keybind:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for _, entry in w.Registry:Entries() do
			local h = entry.Handle
			if entry.Type == "Keybind" and h and not h._destroyed then
				local v = h:GetValue()
				local mobileAction = w.Device.Class == "Phone" and h.Mobile ~= false
				local row = Create.New(if mobileAction then "TextButton" else "TextLabel", {
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundTransparency = if mobileAction then 0.82 else 1,
					BorderSizePixel = 0,
					AutoButtonColor = if mobileAction then false else nil,
					Font = w.Fonts.Regular,
					TextSize = w.Tokens:Get("FontSmall"),
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = `{h.MobileText or h.Title or entry.Id}   [{keyText(v)}]`,
					Parent = self._keybind,
				})
				w:_bind(row, {
					TextColor3 = h:IsActive() and "Accent" or "TextSecondary",
					BackgroundColor3 = "ControlHover",
				})
				if mobileAction then
					Create.New("UICorner", { CornerRadius = UDim.new(0, 6), Parent = row })
					Create.New("UIPadding", {
						PaddingLeft = UDim.new(0, 6),
						PaddingRight = UDim.new(0, 6),
						Parent = row,
					})
					row.MouseButton1Click:Connect(function()
						h:Trigger()
					end)
				end
			end
		end
	end
end
function HUD:Destroy()
	self._alive = false
	self._janitor:Destroy()
	if self._watermark then
		self._watermark:Destroy()
	end
	if self._keybind then
		self._keybind:Destroy()
	end
end
return HUD
