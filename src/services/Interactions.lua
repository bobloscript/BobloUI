--!nonstrict
local Create = require("@runtime/Create")
local Janitor = require("@runtime/Janitor")
local Popover = require("@primitives/Popover")
local Sheet = require("@primitives/Sheet")
local Icon = require("@primitives/Icon")
local Env = require("@runtime/Env")
local Interactions = {}
Interactions.__index = Interactions

local function longestLine(text)
	local longest = 0
	for _, line in string.split(tostring(text), "\n") do
		longest = math.max(longest, #line)
	end
	return longest
end

function Interactions.new(window)
	return setmetatable({ _window = window, _tooltip = nil, _menu = nil, _touchInfo = nil }, Interactions)
end
function Interactions:_hideTooltip()
	if self._tooltip then
		self._tooltip:Destroy()
		self._tooltip = nil
	end
end
function Interactions:_showTooltip(root, text)
	self:_hideTooltip()
	if not root or not root.Parent then
		return
	end
	local w = self._window
	local raw = tostring(text)
	local width = math.clamp(longestLine(raw) * 6 + 16, 88, 260)
	local label = Create.New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(width, 0),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Text = w.Locale:Resolve(raw),
		TextWrapped = true,
		Font = w.Fonts.Regular,
		TextSize = w.Tokens:Get("FontSmall"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = w.Layers.Overlay,
		ZIndex = 999,
	})
	Create.New("UIPadding", {
		PaddingTop = UDim.new(0, 5),
		PaddingBottom = UDim.new(0, 5),
		PaddingLeft = UDim.new(0, 7),
		PaddingRight = UDim.new(0, 7),
		Parent = label,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, 6), Parent = label })
	local stroke = Create.New("UIStroke", { Thickness = 1, Transparency = 0.46, Parent = label })
	w:_bind(stroke, { Color = "Border" })
	w:_bind(label, { BackgroundColor3 = "SurfaceRaised", TextColor3 = "TextSecondary" })
	task.defer(function()
		if not label.Parent then
			return
		end
		local p = root.AbsolutePosition
		local a = root.AbsoluteSize
		local safePos, safeSize = w.Device:SafeArea()
		local x =
			math.clamp(p.X, safePos.X + 8, math.max(safePos.X + 8, safePos.X + safeSize.X - label.AbsoluteSize.X - 8))
		local below = p.Y + a.Y + 5
		local y = below
		if below + label.AbsoluteSize.Y > safePos.Y + safeSize.Y - 8 then
			y = math.max(safePos.Y + 8, p.Y - label.AbsoluteSize.Y - 5)
		end
		label.Position = UDim2.fromOffset(x, y)
	end)
	self._tooltip = label
end
function Interactions:_showTouchInfo(text)
	if self._touchInfo then
		self._touchInfo:Dismiss()
		self._touchInfo = nil
	end
	local w = self._window
	local height = math.min(220, 106 + math.ceil(#tostring(text) / 48) * 18)
	local h = Sheet.open(w, height, {
		OnDismiss = function()
			self._touchInfo = nil
		end,
	})
	self._touchInfo = h
	local label = Create.New("TextLabel", {
		Size = UDim2.new(1, -32, 1, -40),
		Position = UDim2.fromOffset(16, 24),
		BackgroundTransparency = 1,
		Text = tostring(text),
		TextWrapped = true,
		Font = w.Fonts.Regular,
		TextSize = w.Tokens:Get("FontBody"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = h.Frame,
	})
	w:_bind(label, { TextColor3 = "TextSecondary" })
end
function Interactions:OpenMenu(anchor, items)
	if self._menu then
		self._menu:Dismiss()
		self._menu = nil
	end
	if #items == 0 then
		return
	end
	local w = self._window
	local maxLen = 0
	for _, item in items do
		maxLen = math.max(maxLen, #tostring(item.Text or item.Title or "Action"))
	end
	local width = math.clamp(maxLen * 7 + 52, 176, 250)
	local rowH = 31
	local height = 12 + #items * rowH + math.max(0, #items - 1) * 2
	local h = if w.Device.Layout == "Drawer"
		then Sheet.open(w, math.min(360, 24 + #items * 38), {
			OnDismiss = function()
				self._menu = nil
			end,
		})
		else Popover.open(w, anchor, Vector2.new(width, height), {
			OnDismiss = function()
				self._menu = nil
			end,
			Corner = 8,
		})
	self._menu = h
	local top = if w.Device.Layout == "Drawer" then 20 else 6
	local list = Create.New("Frame", {
		Size = UDim2.new(1, -12, 1, -top - 6),
		Position = UDim2.fromOffset(6, top),
		BackgroundTransparency = 1,
		Parent = h.Frame,
	})
	Create.List(2).Parent = list
	for _, item in items do
		local b = Create.New("TextButton", {
			Size = UDim2.new(1, 0, 0, rowH),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			Parent = list,
		})
		Create.New("UICorner", { CornerRadius = UDim.new(0, 7), Parent = b })
		w:_bind(b, { BackgroundColor3 = "ControlHover" })
		local offset = 10
		if item.Icon then
			local icon = Icon.new(
				w,
				item.Icon,
				{ Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(9, 8), Parent = b }
			)
			Icon.setColor(icon, w.Theme:Get(item.Danger and "Error" or "TextTertiary"))
			offset = 30
		end
		local label = Create.New("TextLabel", {
			Size = UDim2.new(1, -offset - 8, 1, 0),
			Position = UDim2.fromOffset(offset, 0),
			BackgroundTransparency = 1,
			Font = w.Fonts.Regular,
			TextSize = w.Tokens:Get("FontBody"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = w.Locale:Resolve(item.Text or item.Title or "Action"),
			Parent = b,
		})
		w:_bind(label, { TextColor3 = item.Danger and "Error" or "TextSecondary" })
		b.MouseEnter:Connect(function()
			b.BackgroundTransparency = 0
			label.TextColor3 = w.Theme:Get(item.Danger and "Error" or "Text")
		end)
		b.MouseLeave:Connect(function()
			b.BackgroundTransparency = 1
			label.TextColor3 = w.Theme:Get(item.Danger and "Error" or "TextSecondary")
		end)
		b.MouseButton1Click:Connect(function()
			h:Dismiss()
			local ok, err = xpcall(item.Callback or function() end, debug.traceback)
			if not ok then
				warn(`[BobloUI] context action failed:\n{err}`)
			end
		end)
	end
end
function Interactions:Attach(control, root, tooltip, userMenu)
	local j = Janitor.new("Control.Interactions")
	local hoverToken = 0
	local w = self._window
	local function tooltipText()
		local v = type(tooltip) == "function" and tooltip() or tooltip
		if v == nil then
			return nil
		end
		local kind = type(v)
		if kind == "function" or kind == "table" or kind == "userdata" or kind == "thread" then
			return nil
		end
		return w.Locale:Resolve(tostring(v))
	end
	if tooltip and w.Device.Class ~= "Phone" then
		j:Add(root.MouseEnter:Connect(function()
			hoverToken += 1
			local token = hoverToken
			j:Add(task.delay(0.4, function()
				local tip = tooltipText()
				if tip and token == hoverToken and root.Parent then
					self:_showTooltip(root, tip)
				end
			end))
		end))
		j:Add(root.MouseLeave:Connect(function()
			hoverToken += 1
			self:_hideTooltip()
		end))
	elseif tooltip then
		local info = Create.New("TextButton", {
			Size = UDim2.fromOffset(20, 20),
			Position = UDim2.new(0.6, -24, 0, 9),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 3,
			Parent = root,
		})
		local icon = Icon.new(w, "info", {
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Parent = info,
		})
		Icon.setColor(icon, w.Theme:Get("TextSecondary"))
		j:Add(info.MouseButton1Click:Connect(function()
			local tip = tooltipText()
			if tip then
				self:_showTouchInfo(tip)
			end
		end))
	end
	local function items()
		local out = {}
		for _, x in userMenu or {} do
			table.insert(out, x)
		end
		if control.Reset and control._stateful then
			table.insert(out, {
				Text = "Reset to default",
				Icon = "reset",
				Callback = function()
					control:Reset()
				end,
			})
		end
		if control.CopyValue and control._stateful then
			table.insert(out, {
				Text = "Copy value",
				Icon = "copy",
				Callback = function()
					control:CopyValue()
				end,
			})
		end
		if control.PasteValue and control._stateful and Env.Capabilities.ClipboardRead then
			table.insert(out, {
				Text = "Paste value",
				Icon = "copy",
				Callback = function()
					local ok, err = control:PasteValue()
					if not ok and w.Notify then
						w.Notify:Push({ Title = "Paste failed", Content = tostring(err), Variant = "Warning" })
					end
				end,
			})
		end
		if control.Id and w.Favorites then
			table.insert(out, {
				Text = w.Favorites:Has(control.Id) and "Remove from Favorites" or "Add to Favorites",
				Icon = "star",
				Callback = function()
					w.Favorites:Toggle(control.Id)
				end,
			})
		end
		return out
	end
	j:Add(root.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:OpenMenu(root, items())
		elseif input.UserInputType == Enum.UserInputType.Touch then
			local active = true
			local start = input.Position
			local token = task.delay(0.6, function()
				if active and root.Parent then
					self:OpenMenu(root, items())
				end
			end)
			j:Add(token)
			local conn
			conn = input.Changed:Connect(function()
				if (input.Position - start).Magnitude > 12 then
					active = false
				end
				if
					input.UserInputState == Enum.UserInputState.End
					or input.UserInputState == Enum.UserInputState.Cancel
				then
					active = false
					if conn then
						conn:Disconnect()
					end
				end
			end)
			j:Add(conn)
		end
	end))
	return j
end
function Interactions:Destroy()
	self:_hideTooltip()
	if self._menu then
		self._menu:Dismiss()
	end
	if self._touchInfo then
		self._touchInfo:Dismiss()
	end
end
return Interactions
