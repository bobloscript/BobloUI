--!nonstrict
local Create = require("@runtime/Create")
local Janitor = require("@runtime/Janitor")
local Icon = require("@primitives/Icon")
local Overlays = {}
Overlays.__index = Overlays

function Overlays.new(window)
	return setmetatable({ _window = window, _janitor = Janitor.new("Overlays"), _items = {} }, Overlays)
end

function Overlays:_handle(root, janitor)
	local service = self
	local handle = { Root = root, _janitor = janitor, _service = service, _destroyed = false }
	function handle:SetVisible(visible)
		self.Root.Visible = visible ~= false
		return self
	end
	function handle:SetPosition(position)
		if typeof(position) ~= "UDim2" then
			error("[BobloUI] overlay:SetPosition expects UDim2.", 2)
		end
		self.Root.Position = position
		return self
	end
	function handle:GetInstance()
		return self.Root
	end
	function handle:Destroy()
		if self._destroyed then
			return
		end
		self._destroyed = true
		local position = table.find(self._service._items, self)
		if position then
			table.remove(self._service._items, position)
		end
		self._service._janitor:Release(self)
		self._janitor:Destroy()
	end
	table.insert(self._items, handle)
	self._janitor:Add(handle, "Destroy", handle)
	return handle
end

function Overlays:_drag(handle, gui)
	local start
	handle._janitor:Add(self._window.Input:AttachDrag(gui, function(delta)
		if start then
			handle.Root.Position =
				UDim2.new(start.X.Scale, start.X.Offset + delta.X, start.Y.Scale, start.Y.Offset + delta.Y)
		end
	end, function()
		start = handle.Root.Position
		return true
	end))
end

function Overlays:_surface(options)
	options = options or {}
	local w = self._window
	local root = Create.New("Frame", {
		AutomaticSize = Enum.AutomaticSize.XY,
		Active = true,
		Position = options.Position or UDim2.fromOffset(14, w.Device.Insets.Top + 14),
		BackgroundTransparency = tonumber(options.Transparency) or 0.08,
		BorderSizePixel = 0,
		Visible = options.Visible ~= false,
		ZIndex = tonumber(options.ZIndex) or 20,
		Parent = w.Layers.Toast,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, tonumber(options.CornerRadius) or 8), Parent = root })
	local stroke = Create.New("UIStroke", {
		Thickness = 1,
		Transparency = 0.42,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = root,
	})
	w:_bind(root, { BackgroundColor3 = options.BackgroundToken or "SurfaceRaised" })
	w:_bind(stroke, { Color = options.BorderToken or "Border" })
	local janitor = Janitor.new("Overlay")
	janitor:Add(root)
	return root, janitor
end

function Overlays:AddLabel(text, icon, iconPosition)
	local options = if type(text) == "table" then text else { Text = text, Icon = icon, IconPosition = iconPosition }
	local root, janitor = self:_surface(options)
	local hasIcon = options.Icon ~= nil
	local label = Create.New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Font = self._window.Fonts.Medium,
		TextSize = self._window.Tokens:Get("FontSmall"),
		Text = tostring(options.Text or ""),
		Parent = root,
	})
	Create.New("UIPadding", {
		PaddingTop = UDim.new(0, 7),
		PaddingBottom = UDim.new(0, 7),
		PaddingLeft = UDim.new(0, hasIcon and 30 or 10),
		PaddingRight = UDim.new(0, hasIcon and 30 or 10),
		Parent = label,
	})
	self._window:_bind(label, { TextColor3 = "TextSecondary" })
	if hasIcon then
		local right = options.IconPosition == "Right"
		local glyph = Icon.new(self._window, options.Icon, {
			Size = UDim2.fromOffset(14, 14),
			Position = if right then UDim2.new(1, -9, 0.5, 0) else UDim2.new(0, 9, 0.5, 0),
			AnchorPoint = if right then Vector2.new(1, 0.5) else Vector2.new(0, 0.5),
			Parent = root,
		})
		Icon.setColor(glyph, self._window.Theme:Get("Accent"))
	end
	local handle = self:_handle(root, janitor)
	handle.Label = label
	function handle:SetText(value)
		self.Label.Text = tostring(value or "")
		return self
	end
	self:_drag(handle, root)
	return handle
end

function Overlays:AddButton(text, callback, options)
	if type(text) == "table" then
		options = text
		callback = options.Callback
		text = options.Text or options.Title
	end
	options = options or {}
	local root, janitor = self:_surface(options)
	local button = Create.New("TextButton", {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = self._window.Fonts.Medium,
		TextSize = self._window.Tokens:Get("FontSmall"),
		Text = tostring(text or "Action"),
		Parent = root,
	})
	Create.New("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, options.Icon and 32 or 11),
		PaddingRight = UDim.new(0, 11),
		Parent = button,
	})
	self._window:_bind(button, { TextColor3 = "Text" })
	if options.Icon then
		local glyph = Icon.new(self._window, options.Icon, {
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.new(0, 10, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Parent = root,
		})
		Icon.setColor(glyph, self._window.Theme:Get("Accent"))
	end
	local handle = self:_handle(root, janitor)
	handle.Button = button
	function handle:SetText(value)
		self.Button.Text = tostring(value or "")
		return self
	end
	janitor:Add(button.MouseButton1Click:Connect(function()
		if callback then
			local ok, err = xpcall(callback, debug.traceback, handle)
			if not ok then
				warn(err)
			end
		end
	end))
	self:_drag(handle, root)
	return handle
end

function Overlays:AddMenu(title, options)
	options = options or {}
	local root, janitor = self:_surface(options)
	root.AutomaticSize = Enum.AutomaticSize.None
	root.Size = options.Size or UDim2.fromOffset(260, 180)
	local header = Create.New("TextButton", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = tostring(title or options.Title or "Menu"),
		Font = self._window.Fonts.Medium,
		TextSize = self._window.Tokens:Get("FontBody"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = root,
	})
	Create.New("UIPadding", { PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 11), Parent = header })
	self._window:_bind(header, { BackgroundColor3 = "SurfaceInset", TextColor3 = "Text" })
	local content = Create.New("Frame", {
		Size = UDim2.new(1, -16, 1, -50),
		Position = UDim2.fromOffset(8, 42),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Create.List(6).Parent = content
	local handle = self:_handle(root, janitor)
	handle.Header = header
	handle.Content = content
	function handle:SetTitle(value)
		self.Header.Text = tostring(value or "")
		return self
	end
	self:_drag(handle, header)
	return handle
end

function Overlays:Destroy()
	for _, handle in table.clone(self._items) do
		handle:Destroy()
	end
	self._janitor:Destroy()
end

return Overlays
