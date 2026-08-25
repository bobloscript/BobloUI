--!nonstrict
local Create = require("@runtime/Create")
local Surface = require("@primitives/Surface")
local Icon = require("@primitives/Icon")
local Palette = {}
Palette.__index = Palette

local MAX_ROWS = 7
local ROW_HEIGHT = 44
local SEARCH_HEIGHT = 42
local TOP_PAD = 10
local LIST_TOP = 60
local FOOTER_HEIGHT = 24

local function paletteWidth(window)
	local configured = window._searchbarSize
	if type(configured) == "number" then
		return math.min(math.max(280, configured), window.Device.Viewport.X - 32)
	end
	if typeof(configured) == "UDim2" then
		return math.min(
			math.max(280, window.Device.Viewport.X * configured.X.Scale + configured.X.Offset),
			window.Device.Viewport.X - 32
		)
	end
	return math.min(520, window.Device.Viewport.X - 32)
end

function Palette.new(window, search, commands)
	local self = setmetatable({
		_window = window,
		_search = search,
		_commands = commands,
		_handle = nil,
		_mode = "search",
		_results = {},
		_rows = {},
		_selected = 0,
	}, Palette)
	self._inputConn = window.Input.Began:Connect(function(i, processed)
		if self._handle then
			if i.KeyCode == Enum.KeyCode.Escape then
				self:Close()
				return
			end
			if i.KeyCode == Enum.KeyCode.Up then
				self:_move(-1)
				return
			end
			if i.KeyCode == Enum.KeyCode.Down then
				self:_move(1)
				return
			end
			if i.KeyCode == Enum.KeyCode.Return or i.KeyCode == Enum.KeyCode.KeypadEnter then
				self:_activateSelected()
				return
			end
		end
		if processed then
			return
		end
		if
			i.KeyCode == Enum.KeyCode.K
			and (window.Input:IsKeyDown(Enum.KeyCode.LeftControl) or window.Input:IsKeyDown(Enum.KeyCode.RightControl))
		then
			self:Open("")
		end
	end)
	return self
end

function Palette:_desktopHeight(rowCount, empty)
	if empty then
		return 112
	end
	return LIST_TOP + rowCount * ROW_HEIGHT + FOOTER_HEIGHT + 8
end

function Palette:_applySize(rowCount, empty)
	if not self._frame then
		return
	end
	local w = self._window
	if w.Device.Layout == "Drawer" then
		self._frame.Size = UDim2.new(1, -12, 1, -72)
		self._frame.Position = UDim2.fromOffset(6, 60)
		return
	end
	local width = paletteWidth(w)
	local height = math.min(404, self:_desktopHeight(rowCount, empty))
	self._frame.Size = UDim2.fromOffset(width, height)
	self._frame.Position = UDim2.fromScale(0.5, 0.18)
end

function Palette:Open(query, mode)
	if self._window._disableSearch and mode ~= "commands" then
		return self
	end
	if self._handle then
		self:Close()
	end
	self._mode = mode or "search"
	local w = self._window
	local handle = w.Layers:Push({
		Scrim = true,
		Modal = false,
		OnDismiss = function()
			self._search:CancelPending()
			self._handle = nil
			self._box = nil
			self._list = nil
			self._frame = nil
			self._results = {}
			self._rows = {}
			self._selected = 0
		end,
	})
	self._handle = handle
	local drawer = w.Device.Layout == "Drawer"
	local frame = Surface.new(w, {
		Size = if drawer then UDim2.new(1, -12, 1, -72) else UDim2.fromOffset(paletteWidth(w), 112),
		Position = if drawer then UDim2.fromOffset(6, 60) else UDim2.fromScale(0.5, 0.18),
		AnchorPoint = if drawer then Vector2.new(0, 0) else Vector2.new(0.5, 0),
		BorderSizePixel = 0,
		Parent = handle.Container,
	}, {
		Token = "SurfaceRaised",
		StrokeToken = "Border",
		StrokeTransparency = 0.40,
		Corner = w.Tokens:Get("CornerLg"),
	})
	frame.ZIndex = handle.Depth * 10 + 3
	self._frame = frame

	local field = Create.New("Frame", {
		Size = UDim2.new(1, -20, 0, SEARCH_HEIGHT),
		Position = UDim2.fromOffset(10, TOP_PAD),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Parent = frame,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, w.Tokens:Get("FieldRadius")), Parent = field })
	local fieldStroke = Create.New("UIStroke", { Thickness = 1, Transparency = 0.48, Parent = field })
	w:_bind(field, { BackgroundColor3 = "ControlInset" })
	w:_bind(fieldStroke, { Color = "BorderSubtle" })
	local searchIcon =
		Icon.new(w, "search", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(12, 13), Parent = field })
	Icon.setColor(searchIcon, w.Theme:Get("TextTertiary"))
	local esc = Create.New("TextLabel", {
		Size = UDim2.fromOffset(34, 22),
		Position = UDim2.new(1, -9, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Text = "ESC",
		Font = w.Fonts.Medium,
		TextSize = w.Tokens:Get("FontCaption"),
		Parent = field,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, 6), Parent = esc })
	w:_bind(esc, { BackgroundColor3 = "SurfaceSecondary", TextColor3 = "TextTertiary" })
	self._box = Create.New("TextBox", {
		Size = UDim2.new(1, -82, 1, 0),
		Position = UDim2.fromOffset(36, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		PlaceholderText = w.Locale:T("search.placeholder"),
		Text = query or "",
		Font = w.Fonts.Regular,
		TextSize = w.Tokens:Get("FontBody"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = field,
	})
	w:_bind(self._box, { TextColor3 = "Text", PlaceholderColor3 = "TextTertiary" })
	self._box.Focused:Connect(function()
		fieldStroke.Transparency = 0.08
		fieldStroke.Color = w.Theme:Get("AccentBorder")
	end)
	self._box.FocusLost:Connect(function()
		fieldStroke.Transparency = 0.48
		fieldStroke.Color = w.Theme:Get("BorderSubtle")
	end)

	self._list = Create.New("Frame", {
		Size = UDim2.new(1, -20, 1, -LIST_TOP - FOOTER_HEIGHT),
		Position = UDim2.fromOffset(10, LIST_TOP),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	Create.List(0).Parent = self._list
	self._footer = Create.New("TextLabel", {
		Size = UDim2.new(1, -24, 0, FOOTER_HEIGHT),
		Position = UDim2.new(0, 12, 1, -FOOTER_HEIGHT - 2),
		BackgroundTransparency = 1,
		Font = w.Fonts.Regular,
		TextSize = w.Tokens:Get("FontCaption"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "UP/DOWN  Navigate     ENTER  Open     ESC  Close",
		Parent = frame,
	})
	w:_bind(self._footer, { TextColor3 = "TextTertiary" })

	self._box:GetPropertyChangedSignal("Text"):Connect(function()
		self:_scheduleRefresh()
	end)
	self._box:CaptureFocus()
	self:_refresh()
	return self
end

function Palette:_collect()
	local w = self._window
	local text = self._box.Text
	if string.sub(text, 1, 1) == ">" or self._mode == "commands" then
		return self._commands:Query(string.gsub(text, "^>%s*", ""))
	end
	if string.sub(text, 1, 1) == "@" then
		local q = string.lower(string.gsub(text, "^@%s*", ""))
		local results = {}
		for _, tab in w._tabs do
			local shown = w.Locale:Resolve(tab.Title)
			if q == "" or string.find(string.lower(shown), q, 1, true) then
				table.insert(results, { Kind = "Tab", Title = shown, Handle = tab, Path = "Tab" })
			end
		end
		return results
	end
	if string.sub(text, 1, 1) == "#" then
		local q = string.lower(string.gsub(text, "^#%s*", ""))
		local results = {}
		if w.Config then
			for _, name in w.Config:List() do
				if q == "" or string.find(string.lower(name), q, 1, true) then
					table.insert(results, { Kind = "Config", Title = name, Id = name, Path = "Config profile" })
				end
			end
		end
		return results
	end
	if string.sub(text, 1, 1) == "*" then
		local q = string.lower(string.gsub(text, "^%*%s*", ""))
		local results = {}
		for _, id in w.Favorites:List() do
			local h = w:Get(id)
			if h then
				local title = w.Locale:Resolve(h.Title or id)
				if q == "" or string.find(string.lower(title), q, 1, true) then
					table.insert(results, { Kind = "Favorite", Title = title, Handle = h, Path = "Favorite" })
				end
			end
		end
		return results
	end
	return self._search:Query(text)
end

function Palette:_scheduleRefresh()
	if not self._box then
		return
	end
	local text = self._box.Text
	local prefix = string.sub(text, 1, 1)
	if self._mode == "commands" or prefix == ">" or prefix == "@" or prefix == "#" or prefix == "*" then
		self._search:CancelPending()
		self:_refresh()
		return
	end
	self._search:QueryDebounced(text, function(results)
		if self._box and self._box.Text == text then
			self:_refresh(results)
		end
	end)
end

function Palette:_emptyState(text)
	local w = self._window
	local title = Create.New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Font = w.Fonts.Medium,
		TextSize = w.Tokens:Get("FontBody"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = if text == "" then "Search controls" else "No results",
		Parent = self._list,
	})
	w:_bind(title, { TextColor3 = if text == "" then "TextSecondary" else "Text" })
	local hint = Create.New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Font = w.Fonts.Regular,
		TextSize = w.Tokens:Get("FontSmall"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = if text == ""
			then "Type a control, > command, @ tab, # config, or * favorite"
			else "Try another name or use > @ # *",
		Parent = self._list,
	})
	w:_bind(hint, { TextColor3 = "TextTertiary" })
end

function Palette:_refresh(precomputed)
	if not self._list then
		return
	end
	for _, c in self._list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local w = self._window
	local raw = precomputed or self:_collect()
	self._results = {}
	self._rows = {}
	self._selected = 0
	for i = 1, math.min(MAX_ROWS, #raw) do
		self._results[i] = raw[i]
	end
	local empty = #self._results == 0
	self._footer.Visible = not empty
	self:_applySize(#self._results, empty)
	if empty then
		self:_emptyState(self._box.Text)
		return
	end

	for index, r in self._results do
		local b = Create.New("TextButton", {
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			Parent = self._list,
		})
		Create.New("UICorner", { CornerRadius = UDim.new(0, w.Tokens:Get("FieldRadius")), Parent = b })
		w:_bind(b, { BackgroundColor3 = "AccentSoft" })
		local title = Create.New("TextLabel", {
			Size = UDim2.new(1, -82, 0, 21),
			Position = UDim2.fromOffset(10, 4),
			BackgroundTransparency = 1,
			Font = w.Fonts.Medium,
			TextSize = w.Tokens:Get("FontBody"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = r.Title,
			Parent = b,
		})
		w:_bind(title, { TextColor3 = "Text" })
		local path = Create.New("TextLabel", {
			Size = UDim2.new(1, -82, 0, 15),
			Position = UDim2.fromOffset(10, 24),
			BackgroundTransparency = 1,
			Font = w.Fonts.Regular,
			TextSize = w.Tokens:Get("FontCaption"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = (r.Hidden and r.Requirement and ((r.Path or "") .. " · requires: " .. r.Requirement))
				or r.Path
				or (r.Kind == "Command" and "Command" or ""),
			Parent = b,
		})
		w:_bind(path, { TextColor3 = "TextTertiary" })
		local kind = Create.New("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, 20),
			Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			Font = w.Fonts.Medium,
			TextSize = w.Tokens:Get("FontCaption"),
			Text = string.upper(r.Kind or "CONTROL"),
			Parent = b,
		})
		w:_bind(kind, { TextColor3 = "TextTertiary" })
		self._rows[index] = b
		b.MouseEnter:Connect(function()
			self:_select(index)
		end)
		b.MouseButton1Click:Connect(function()
			self:_activate(r)
		end)
	end
	self:_select(1)
end

function Palette:_select(index)
	if #self._rows == 0 then
		self._selected = 0
		return
	end
	index = ((index - 1) % #self._rows) + 1
	self._selected = index
	for i, row in self._rows do
		if row.Parent then
			row.BackgroundTransparency = if i == index then 0 else 1
		end
	end
end
function Palette:_move(delta)
	if #self._rows == 0 then
		return
	end
	self:_select((self._selected > 0 and self._selected or 1) + delta)
end
function Palette:_activate(r)
	if not r then
		return
	end
	local w = self._window
	if r.Kind == "Command" then
		self._commands:Run(r.Id)
	elseif r.Kind == "Config" and w.Config then
		w.Config:Load(r.Id)
	elseif r.Kind == "Tab" then
		r.Handle:Select()
	elseif r.Kind == "Favorite" and r.Handle then
		r.Handle:Reveal()
	elseif r.Hidden and r.DependencyIds and r.DependencyIds[1] then
		local dep = w.Registry:Get(r.DependencyIds[1])
		if dep and dep.Reveal then
			dep:Reveal()
		end
	elseif r.Handle and r.Handle.Reveal then
		r.Handle:Reveal()
	end
	self:Close()
end
function Palette:_activateSelected()
	if self._selected > 0 then
		self:_activate(self._results[self._selected])
	end
end
function Palette:Close()
	self._search:CancelPending()
	if self._handle then
		local h = self._handle
		self._handle = nil
		h:Dismiss()
	end
	self._box = nil
	self._list = nil
	self._frame = nil
	self._footer = nil
	self._results = {}
	self._rows = {}
	self._selected = 0
end
function Palette:Destroy()
	self:Close()
	if self._inputConn then
		self._inputConn:Disconnect()
	end
end
return Palette
