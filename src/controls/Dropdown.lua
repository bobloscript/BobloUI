--!nonstrict
local Create = require("@runtime/Create")
local Base = require("@controls/Base")
local Popover = require("@primitives/Popover")
local Sheet = require("@primitives/Sheet")
local Scroller = require("@primitives/Scroller")
local Icon = require("@primitives/Icon")
local Dropdown = setmetatable({}, { __index = Base })
Dropdown.__index = Dropdown

local ROW_HEIGHT = 32
local RICH_ROW_HEIGHT = 48
local ROW_GAP = 2
local MAX_VISIBLE_ROWS = 7

local function normalizeOption(option, forcedValue)
	if type(option) == "table" then
		local value = if forcedValue ~= nil then forcedValue else option.Value
		if value ~= nil then
			return {
				Value = value,
				Label = tostring(option.Title or option.Label or option.Text or value),
				Description = option.Description or option.Desc,
				Icon = option.Icon,
				Image = option.Image,
				Locked = option.Locked == true,
				LockedReason = option.LockedReason,
				Callback = option.Callback,
			}
		end
	end
	local value = if forcedValue ~= nil then forcedValue else option
	return { Value = value, Label = tostring(option) }
end
local function normalize(options)
	local out = {}
	if type(options) ~= "table" then
		return out
	end
	if #options > 0 then
		for _, option in options do
			table.insert(out, normalizeOption(option))
		end
		return out
	end
	local keys = {}
	for key in options do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	for _, key in keys do
		table.insert(out, normalizeOption(options[key], key))
	end
	return out
end
local function contains(list, value)
	for _, v in list do
		if v == value then
			return true
		end
	end
	return false
end
local function isDictionary(value)
	return type(value) == "table" and #value == 0 and next(value) ~= nil
end
local function findOption(options, value)
	for _, o in options do
		if o.Value == value then
			return o
		end
	end
end
local function rowHeight(o)
	return o and (o.Description or o.Icon or o.Image or o.Locked) and RICH_ROW_HEIGHT or ROW_HEIGHT
end

function Dropdown.new(section, options)
	local self = setmetatable({}, Dropdown)
	local initialOptions = options.Options or options.Values or {}
	self._options = normalize(initialOptions)
	self.Multi = options.Multi == true
	self.MultiValueMode = options.MultiValueMode
		or if options.Map == true
				or options.ReturnMap == true
				or (self.Multi and isDictionary(options.Values))
			then "Map"
			else "Array"
	if self.MultiValueMode ~= "Array" and self.MultiValueMode ~= "Map" then
		error('[BobloUI] Dropdown MultiValueMode must be "Array" or "Map".', 3)
	end
	self.Style = options.Style or "Dropdown"
	if self.Style == "Segmented" and self.Multi then
		error("[BobloUI] segmented Dropdown does not support Multi=true.", 3)
	end
	self.Source = options.Source
	self.Searchable = if options.Searchable == nil then #self._options > 8 or self.Source ~= nil else options.Searchable
	self.AllowNone = options.AllowNone == true or options.AllowNull == true
	self.Max = options.Max
	self.MaxVisibleRows =
		math.max(1, math.floor(tonumber(options.MaxVisibleRows or options.MaxVisibleDropdownItems) or MAX_VISIBLE_ROWS))
	self.DragSelect = options.DragSelect == true
	self.FormatDisplayValue = options.FormatDisplayValue or options.FormatValue
	self.FormatListValue = options.FormatListValue or options.FormatOption
	self.DisabledValues = options.DisabledValues or {}
	self.ValueImages = options.ValueImages or options.Images or {}
	self.Placeholder = options.Placeholder or "Select..."
	self:_applyOptionMetadata()
	self._popup = nil
	local default = options.Default
	if self.Multi and default == nil then
		default = {}
	elseif self.Multi and self.MultiValueMode == "Map" and type(default) == "table" and #default > 0 then
		local mapped = {}
		for _, value in default do
			mapped[value] = true
		end
		default = mapped
	end
	Base.init(self, section, "Dropdown", options, { Stateful = true, Default = default, Adaptive = true })
	self:_bindSource()
	return Base.finish(self)
end
function Dropdown:_isSelected(selected, value)
	if type(selected) ~= "table" then
		return false
	end
	if self.MultiValueMode == "Map" then
		return selected[value] == true
	end
	return contains(selected, value)
end
function Dropdown:_selectedList(selected)
	if type(selected) ~= "table" then
		return {}
	end
	if self.MultiValueMode == "Array" then
		return table.clone(selected)
	end
	local out = {}
	for _, option in self._options do
		if selected[option.Value] == true then
			table.insert(out, option.Value)
		end
	end
	return out
end
function Dropdown:_selectionCount(selected)
	return #self:_selectedList(selected)
end
function Dropdown:SetValue(value, silent)
	if self.Multi and type(value) == "table" then
		if self.MultiValueMode == "Map" and #value > 0 then
			local mapped = {}
			for _, selected in value do
				mapped[selected] = true
			end
			value = mapped
		elseif self.MultiValueMode == "Array" and isDictionary(value) then
			local ordered = {}
			for _, option in self._options do
				if value[option.Value] == true then
					table.insert(ordered, option.Value)
				end
			end
			value = ordered
		end
	end
	return Base.SetValue(self, value, silent)
end
function Dropdown:_applyOptionMetadata()
	for _, option in self._options do
		if contains(self.DisabledValues, option.Value) then
			option.Locked = true
		end
		if self.ValueImages[option.Value] ~= nil then
			option.Image = self.ValueImages[option.Value]
		end
	end
end
function Dropdown:_bindSource()
	if self.Source == nil then
		return
	end
	local source = self.Source
	local signals = {}
	if type(source) == "table" then
		signals = source.Signals or source.RefreshOn or {}
	end
	for _, signal in signals do
		if typeof(signal) == "RBXScriptSignal" then
			self._janitor:Add(signal:Connect(function()
				task.defer(function()
					if not self._destroyed then
						self:RefreshSource()
					end
				end)
			end))
		end
	end
	task.defer(function()
		if not self._destroyed then
			self:RefreshSource(true)
		end
	end)
end
function Dropdown:_sourceValues()
	local source = self.Source
	if type(source) == "function" then
		local ok, result = pcall(source)
		if ok then
			return result
		else
			warn(`[BobloUI] Dropdown source failed: {result}`)
			return {}
		end
	end
	if type(source) == "table" then
		local getter = source.Get or source.Fetch
		if type(getter) == "function" then
			local ok, result = pcall(getter, source)
			if not ok then
				ok, result = pcall(getter)
			end
			if ok then
				return result
			else
				warn(`[BobloUI] Dropdown source failed: {result}`)
			end
		end
	end
	return {}
end
function Dropdown:RefreshSource(silent)
	if self.Source == nil then
		return self
	end
	local values = self:_sourceValues()
	if type(values) ~= "table" then
		values = {}
	end
	self:SetOptions(values, silent == true)
	return self
end
function Dropdown:_mountValue(host)
	if self.Style == "Segmented" then
		return self:_mountSegmented(host)
	end
	local w = self._window
	local t = w.Tokens
	self._button = Create.New("TextButton", {
		Size = UDim2.new(1, 0, 0, t:Get("FieldHeight")),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Parent = host,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, t:Get("FieldRadius")), Parent = self._button })
	self._stroke = Create.New("UIStroke", { Thickness = 1, Transparency = 0.45, Parent = self._button })
	w:_bind(self._stroke, { Color = "BorderSubtle" })
	w:_bind(self._button, { BackgroundColor3 = "ControlInset" })
	self._valueLabel = Create.New("TextLabel", {
		Size = UDim2.new(1, -32, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		Font = w.Fonts.Regular,
		TextSize = t:Get("FontBody"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = self._button,
	})
	w:_bind(self._valueLabel, { TextColor3 = "Text" })
	self._arrow = Icon.new(w, "chevron_down", {
		Size = UDim2.fromOffset(15, 15),
		Position = UDim2.new(1, -9, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = self._button,
	})
	self._janitor:Add(self._button.MouseEnter:Connect(function()
		if not self._popup then
			self._button.BackgroundColor3 = w.Theme:Get("ControlHover")
		end
	end))
	self._janitor:Add(self._button.MouseLeave:Connect(function()
		if not self._popup then
			self._button.BackgroundColor3 = w.Theme:Get("ControlInset")
		end
	end))
	self._janitor:Add(self._button.MouseButton1Click:Connect(function()
		if not self:IsDisabled() then
			if self._popup then
				self:Close()
			else
				self:Open()
			end
		end
	end))
end
function Dropdown:_mountSegmented(host)
	local w = self._window
	local t = w.Tokens
	self._segmentHost = Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, t:Get("FieldHeight")),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Parent = host,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, t:Get("FieldRadius")), Parent = self._segmentHost })
	local stroke = Create.New("UIStroke", { Thickness = 1, Transparency = 0.45, Parent = self._segmentHost })
	w:_bind(stroke, { Color = "BorderSubtle" })
	w:_bind(self._segmentHost, { BackgroundColor3 = "ControlInset" })
	Create.List(2, Enum.FillDirection.Horizontal).Parent = self._segmentHost
	self._segments = {}
	for _, o in self._options do
		local b = Create.New("TextButton", {
			Size = UDim2.new(1 / math.max(1, #self._options), -2, 1, -4),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = o.Label,
			Font = w.Fonts.Medium,
			TextSize = t:Get("FontSmall"),
			Parent = self._segmentHost,
		})
		Create.New("UICorner", { CornerRadius = UDim.new(0, math.max(4, t:Get("FieldRadius") - 2)), Parent = b })
		w:_bind(b, { BackgroundColor3 = "AccentSoft", TextColor3 = "TextSecondary" })
		self._segments[o.Value] = b
		self._janitor:Add(b.MouseButton1Click:Connect(function()
			if not self:IsDisabled() and not o.Locked then
				self:SetValue(o.Value)
				if o.Callback then
					pcall(o.Callback, o.Value)
				end
			end
		end))
	end
end
function Dropdown:_renderSegments(v)
	if not self._segments then
		return
	end
	local w = self._window
	for value, b in self._segments do
		local on = value == v
		b.BackgroundTransparency = if on then 0 else 1
		b.TextColor3 = w.Theme:Get(if on then "Text" else "TextSecondary")
	end
end
function Dropdown:_labelFor(value)
	local o = findOption(self._options, value)
	local label = o and o.Label or tostring(value)
	if self.FormatDisplayValue then
		local ok, formatted = pcall(self.FormatDisplayValue, value, label, o)
		if ok and formatted ~= nil then
			return tostring(formatted)
		end
	end
	return label
end
function Dropdown:_listLabel(option)
	if self.FormatListValue then
		local ok, formatted = pcall(self.FormatListValue, option.Value, option.Label, option)
		if ok and formatted ~= nil then
			return tostring(formatted)
		end
	end
	return option.Label
end
function Dropdown:_display(value)
	if self.Multi then
		local selected = self:_selectedList(value)
		if #selected == 0 then
			return self.Placeholder
		end
		local labels = {}
		for _, v in selected do
			table.insert(labels, self:_labelFor(v))
		end
		if #labels > 3 then
			return `{#labels} selected`
		end
		return table.concat(labels, ", ")
	end
	if value == nil then
		return self.Placeholder
	end
	return self:_labelFor(value)
end
function Dropdown:_render(v)
	if self.Style == "Segmented" then
		self:_renderSegments(v)
		return
	end
	if self._valueLabel then
		local empty = v == nil or (self.Multi and self:_selectionCount(v) == 0)
		self._valueLabel.Text = self:_display(v)
		self._valueLabel.TextColor3 = self._window.Theme:Get(empty and "TextTertiary" or "Text")
	end
end
function Dropdown:_select(option)
	local o = type(option) == "table" and option or findOption(self._options, option)
	if not o then
		return
	end
	if o.Locked then
		if self._window.Notify then
			self._window.Notify:Push({
				Title = o.Label,
				Content = o.LockedReason or "This option is locked",
				Variant = "Warning",
				Duration = 3,
			})
		end
		return
	end
	local value = o.Value
	if self._window.Sound then
		self._window.Sound:Play("Select")
	end
	if self.Multi then
		local current = table.clone(self:GetValue() or {})
		local enabled
		if self:_isSelected(current, value) then
			if self.MultiValueMode == "Map" then
				current[value] = nil
			else
				table.remove(current, table.find(current, value))
			end
			enabled = false
		else
			if self.Max and self:_selectionCount(current) >= self.Max then
				return
			end
			if self.MultiValueMode == "Map" then
				current[value] = true
			else
				table.insert(current, value)
			end
			enabled = true
		end
		self:SetValue(current)
		if o.Callback then
			pcall(o.Callback, value, enabled)
		end
		self:_rebuildPopup()
	else
		self:SetValue(value)
		if o.Callback then
			pcall(o.Callback, value, true)
		end
		self:Close()
	end
end
function Dropdown:_matches(o, query)
	if query == "" then
		return true
	end
	local hay = string.lower(o.Label .. " " .. tostring(o.Description or ""))
	return string.find(hay, query, 1, true) ~= nil
end
function Dropdown:_filteredOptions()
	local query = (self._search and string.lower(self._search.Text)) or ""
	local out = {}
	for _, o in self._options do
		if self:_matches(o, query) then
			table.insert(out, o)
		end
	end
	return out
end
function Dropdown:_popupMetrics(filtered)
	filtered = filtered or self:_filteredOptions()
	local drawer = self._window.Device.Layout == "Drawer"
	local top = if drawer then 20 else 8
	local searchBlock = if self.Searchable then 42 else 0
	local listTop = top + searchBlock
	local listHeight = 0
	for i = 1, math.max(1, math.min(self.MaxVisibleRows, #filtered)) do
		listHeight += rowHeight(filtered[i]) + ((i > 1) and ROW_GAP or 0)
	end
	local height = listTop + listHeight + 8
	local triggerWidth = self._button and self._button.AbsoluteSize.X or 180
	local minWidth = if self.Searchable then 240 else 176
	local rich = false
	for _, o in filtered do
		if o.Description or o.Icon or o.Image then
			rich = true
			break
		end
	end
	local width = math.min(math.max(triggerWidth, minWidth, rich and 280 or 0), 360)
	return Vector2.new(width, height), listTop
end
function Dropdown:_resizePopup(filtered)
	if not self._popup then
		return
	end
	local size = self:_popupMetrics(filtered)
	if self._window.Device.Layout == "Drawer" then
		if self._popup.SetHeight then
			self._popup:SetHeight(math.min(440, size.Y))
		end
	elseif self._popup.SetSize then
		self._popup:SetSize(size)
	end
end
function Dropdown:_buildPopup(frame)
	local w = self._window
	local t = w.Tokens
	frame.ClipsDescendants = true
	local filtered = self:_filteredOptions()
	local size, listTop = self:_popupMetrics(filtered)
	local top = if w.Device.Layout == "Drawer" then 20 else 8
	if self.Searchable then
		local field = Create.New("Frame", {
			Size = UDim2.new(1, -16, 0, 34),
			Position = UDim2.fromOffset(8, top),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Parent = frame,
		})
		Create.New("UICorner", { CornerRadius = UDim.new(0, t:Get("FieldRadius")), Parent = field })
		local s = Create.New("UIStroke", { Thickness = 1, Transparency = 0.46, Parent = field })
		w:_bind(s, { Color = "BorderSubtle" })
		w:_bind(field, { BackgroundColor3 = "ControlInset" })
		local icon = Icon.new(
			w,
			"search",
			{ Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(10, 10), Parent = field }
		)
		Icon.setColor(icon, w.Theme:Get("TextTertiary"))
		self._search = Create.New("TextBox", {
			Size = UDim2.new(1, -34, 1, 0),
			Position = UDim2.fromOffset(30, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			PlaceholderText = "Search...",
			Text = "",
			Font = w.Fonts.Regular,
			TextSize = t:Get("FontBody"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = field,
		})
		w:_bind(self._search, { TextColor3 = "Text", PlaceholderColor3 = "TextTertiary" })
		self._popupSearchConn = self._search:GetPropertyChangedSignal("Text"):Connect(function()
			self:_rebuildPopup()
		end)
	end
	self._list = Scroller.new(
		w,
		{ Size = UDim2.new(1, -12, 1, -listTop - 6), Position = UDim2.fromOffset(6, listTop), Parent = frame }
	)
	Create.New("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2), Parent = self._list })
	Create.List(ROW_GAP).Parent = self._list
	self:_rebuildPopup()
end
function Dropdown:_rebuildPopup()
	if not self._list then
		return
	end
	for _, child in self._list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local filtered = self:_filteredOptions()
	local selected = self:GetValue()
	local w = self._window
	for _, o in filtered do
		local isSelected = if self.Multi then self:_isSelected(selected, o.Value) else selected == o.Value
		local h = rowHeight(o)
		local b = Create.New("TextButton", {
			Size = UDim2.new(1, 0, 0, h),
			BackgroundTransparency = if isSelected then 0 else 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			Parent = self._list,
		})
		Create.New("UICorner", { CornerRadius = UDim.new(0, 7), Parent = b })
		w:_bind(b, { BackgroundColor3 = "AccentSoft" })
		local left = 8
		if o.Image then
			local image = Create.New("ImageLabel", {
				Size = UDim2.fromOffset(18, 18),
				Position = UDim2.fromOffset(8, math.floor(h / 2)),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Image = tostring(o.Image),
				Parent = b,
			})
			image.ImageTransparency = if o.Locked then 0.55 else 0
			left = 34
		elseif o.Icon then
			local ic = Icon.new(w, o.Icon, {
				Size = UDim2.fromOffset(15, 15),
				Position = UDim2.fromOffset(9, math.floor(h / 2)),
				AnchorPoint = Vector2.new(0, 0.5),
				Parent = b,
			})
			Icon.setColor(ic, w.Theme:Get(o.Locked and "TextDisabled" or (isSelected and "Accent" or "TextSecondary")))
			left = 32
		end
		local right = if isSelected or o.Locked then 24 else 8
		local label = Create.New("TextLabel", {
			Size = UDim2.new(1, -left - right, 0, if o.Description then 20 else h),
			Position = UDim2.fromOffset(left, if o.Description then 5 else 0),
			BackgroundTransparency = 1,
			Font = w.Fonts.Regular,
			TextSize = w.Tokens:Get("FontBody"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = self:_listLabel(o),
			Parent = b,
		})
		w:_bind(
			label,
			{ TextColor3 = if o.Locked then "TextDisabled" elseif isSelected then "Text" else "TextSecondary" }
		)
		if o.Description then
			local desc = Create.New("TextLabel", {
				Size = UDim2.new(1, -left - right, 0, 17),
				Position = UDim2.fromOffset(left, 24),
				BackgroundTransparency = 1,
				Font = w.Fonts.Regular,
				TextSize = w.Tokens:Get("FontSmall"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = tostring(o.Description),
				Parent = b,
			})
			w:_bind(desc, { TextColor3 = o.Locked and "TextDisabled" or "TextTertiary" })
		end
		if isSelected then
			local check = Icon.new(w, "check", {
				Size = UDim2.fromOffset(12, 12),
				Position = UDim2.new(1, -8, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				Parent = b,
			})
			Icon.setColor(check, w.Theme:Get("Accent"))
		elseif o.Locked then
			local lock = Icon.new(w, "lock", {
				Size = UDim2.fromOffset(13, 13),
				Position = UDim2.new(1, -8, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				Parent = b,
			})
			Icon.setColor(lock, w.Theme:Get("TextDisabled"))
		end
		b.MouseEnter:Connect(function()
			if not isSelected then
				b.BackgroundTransparency = 0
				b.BackgroundColor3 = w.Theme:Get("ControlHover")
			end
		end)
		b.MouseLeave:Connect(function()
			b.BackgroundTransparency = if isSelected then 0 else 1
		end)
		b.MouseEnter:Connect(function()
			if self._dragSelecting and self.Multi and not self._dragVisited[o.Value] then
				self._dragVisited[o.Value] = true
				self:_select(o)
			end
		end)
		b.InputBegan:Connect(function(input)
			if
				self.DragSelect
				and self.Multi
				and (
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				self._dragSelecting = true
				self._dragVisited = { [o.Value] = true }
				self._skipClickOption = o
				self:_select(o)
			end
		end)
		b.MouseButton1Click:Connect(function()
			if self._skipClickOption == o then
				self._skipClickOption = nil
				return
			end
			self:_select(o)
		end)
	end
	if #filtered == 0 then
		local empty = Create.New("TextLabel", {
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			BackgroundTransparency = 1,
			Font = w.Fonts.Regular,
			TextSize = w.Tokens:Get("FontSmall"),
			Text = "No matches",
			Parent = self._list,
		})
		w:_bind(empty, { TextColor3 = "TextTertiary" })
	end
	self:_resizePopup(filtered)
end
function Dropdown:_clearPopupRefs()
	if self._popupSearchConn then
		self._popupSearchConn:Disconnect()
		self._popupSearchConn = nil
	end
	if self._popupInputEnded then
		self._popupInputEnded:Disconnect()
		self._popupInputEnded = nil
	end
	self._dragSelecting = false
	self._dragVisited = nil
	self._skipClickOption = nil
	self._search = nil
	self._list = nil
end
function Dropdown:Open()
	if self._window.Sound then
		self._window.Sound:Play("Open")
	end
	if self.Style == "Segmented" then
		return self
	end
	if self._popup then
		return self
	end
	local filtered = self:_filteredOptions()
	local size = self:_popupMetrics(filtered)
	local handle
	local function dismissed()
		self._popup = nil
		self:_clearPopupRefs()
		if self._arrow then
			self._arrow.Rotation = 0
		end
		if self._button then
			self._button.BackgroundColor3 = self._window.Theme:Get("ControlInset")
		end
		if self._stroke then
			self._stroke.Color = self._window.Theme:Get("BorderSubtle")
		end
	end
	if self._window.Device.Layout == "Drawer" then
		handle = Sheet.open(self._window, math.min(440, size.Y), { OnDismiss = dismissed })
	else
		handle = Popover.open(self._window, self._button, size, { OnDismiss = dismissed, Corner = 8 })
	end
	self._popup = handle
	self._popupInputEnded = self._window.Input.Ended:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self._dragSelecting = false
			self._dragVisited = nil
			self._skipClickOption = nil
		end
	end)
	self:_buildPopup(handle.Frame)
	self._arrow.Rotation = 180
	self._button.BackgroundColor3 = self._window.Theme:Get("ControlHover")
	self._stroke.Color = self._window.Theme:Get("AccentBorder")
	return self
end
function Dropdown:Close()
	if self._popup then
		local h = self._popup
		self._popup = nil
		self:_clearPopupRefs()
		h:Dismiss()
	end
	if self._arrow then
		self._arrow.Rotation = 0
	end
	if self._popupInputEnded then
		self._popupInputEnded:Disconnect()
		self._popupInputEnded = nil
	end
	return self
end
function Dropdown:SetOptions(list, silent)
	self._options = normalize(list or {})
	self:_applyOptionMetadata()
	local current = self:GetValue()
	if self.Multi then
		local kept = {}
		if self.MultiValueMode == "Map" then
			for value, selected in current or {} do
				if selected == true and findOption(self._options, value) then
					kept[value] = true
				end
			end
		else
			for _, value in current or {} do
				if findOption(self._options, value) then
					table.insert(kept, value)
				end
			end
		end
		self:SetValue(kept, true)
	else
		local exists = findOption(self._options, current) ~= nil
		if not exists and current ~= nil then
			self:SetValue(if self.AllowNone then nil else (self._options[1] and self._options[1].Value or nil), true)
		end
	end
	if self.Style == "Segmented" and self._segmentHost then
		local host = self._valueHost
		self._segmentHost:Destroy()
		self._segmentHost = nil
		self._segments = nil
		self:_mountSegmented(host)
	else
		self:_rebuildPopup()
	end
	self:_render(self:GetValue())
	return self
end
function Dropdown:Refresh(list)
	if list ~= nil then
		return self:SetOptions(list)
	end
	if self.Source then
		self:RefreshSource()
	else
		self:_rebuildPopup()
	end
	return self
end
function Dropdown:AddOption(o)
	local n = normalize({ o })[1]
	if n then
		table.insert(self._options, n)
		self:_applyOptionMetadata()
	end
	self:_rebuildPopup()
	return self
end
function Dropdown:SetValues(values, silent)
	return self:SetOptions(values, silent)
end
function Dropdown:AddValues(values)
	local additions
	if type(values) == "table" and values.Value ~= nil then
		additions = { normalizeOption(values) }
	elseif type(values) == "table" then
		additions = normalize(values)
	else
		additions = { normalizeOption(values) }
	end
	for _, option in additions do
		local existing = findOption(self._options, option.Value)
		if existing then
			for key, value in option do
				existing[key] = value
			end
		else
			table.insert(self._options, option)
		end
	end
	self:_applyOptionMetadata()
	self:_rebuildPopup()
	self:_render(self:GetValue())
	return self
end
function Dropdown:RemoveOption(value)
	for i = #self._options, 1, -1 do
		if self._options[i].Value == value then
			table.remove(self._options, i)
		end
	end
	return self:SetOptions(self._options)
end
function Dropdown:SetDisabledValues(values)
	self.DisabledValues = values or {}
	for _, option in self._options do
		option.Locked = contains(self.DisabledValues, option.Value)
	end
	self:_rebuildPopup()
	return self
end
function Dropdown:AddDisabledValues(values)
	local additions = if type(values) == "table" then values else { values }
	local merged = table.clone(self.DisabledValues)
	for _, value in additions do
		if value ~= nil and not contains(merged, value) then
			table.insert(merged, value)
		end
	end
	return self:SetDisabledValues(merged)
end
function Dropdown:SetValueDisabled(value, disabled, reason)
	local option = findOption(self._options, value)
	if not option then
		return false
	end
	option.Locked = disabled == true
	option.LockedReason = reason or option.LockedReason
	self:_rebuildPopup()
	return self
end
function Dropdown:SetValueImage(value, image)
	local option = findOption(self._options, value)
	if not option then
		return false
	end
	option.Image = image
	self.ValueImages[value] = image
	self:_rebuildPopup()
	return self
end
function Dropdown:SetValueImages(images)
	self.ValueImages = table.clone(images or {})
	for _, option in self._options do
		option.Image = self.ValueImages[option.Value]
	end
	self:_rebuildPopup()
	return self
end
function Dropdown:AddValueImages(images)
	for value, image in images or {} do
		self.ValueImages[value] = image
		local option = findOption(self._options, value)
		if option then
			option.Image = image
		end
	end
	self:_rebuildPopup()
	return self
end
function Dropdown:SetDragSelect(enabled)
	self.DragSelect = enabled == true
	if not self.DragSelect then
		self._dragSelecting = false
		self._dragVisited = nil
		self._skipClickOption = nil
	end
	return self
end
function Dropdown:GetActiveValues(countOnly)
	local current = self:GetValue()
	if self.Multi then
		local values = table.clone(type(current) == "table" and current or {})
		return if countOnly then self:_selectionCount(values) else values
	end
	if countOnly then
		return if current == nil then 0 else 1
	end
	return current
end
function Dropdown:SetMaxVisibleRows(count)
	self.MaxVisibleRows = math.max(1, math.floor(tonumber(count) or self.MaxVisibleRows))
	self:_resizePopup()
	return self
end
function Dropdown:SetFormatters(displayFormatter, listFormatter)
	self.FormatDisplayValue = displayFormatter
	self.FormatListValue = listFormatter
	self:_render(self:GetValue())
	self:_rebuildPopup()
	return self
end
function Dropdown:Destroy()
	self:Close()
	Base.Destroy(self)
end
function Dropdown:_applyValueTokens()
	if self._button then
		self._button.Size = UDim2.new(1, 0, 0, self._window.Tokens:Get("FieldHeight"))
		self._valueLabel.TextSize = self._window.Tokens:Get("FontBody")
	end
	if self._segmentHost then
		self._segmentHost.Size = UDim2.new(1, 0, 0, self._window.Tokens:Get("FieldHeight"))
		for _, b in self._segments or {} do
			b.TextSize = self._window.Tokens:Get("FontSmall")
		end
	end
end
return Dropdown
