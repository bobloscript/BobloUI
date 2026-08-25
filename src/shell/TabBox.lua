--!nonstrict
local Create = require("@runtime/Create")
local Janitor = require("@runtime/Janitor")
local Dependency = require("@runtime/Dependency")
local Button = require("@controls/Button")
local Toggle = require("@controls/Toggle")
local Slider = require("@controls/Slider")
local Dropdown = require("@controls/Dropdown")
local TextField = require("@controls/TextField")
local Keybind = require("@controls/Keybind")
local ColorPicker = require("@controls/ColorPicker")
local Paragraph = require("@controls/Paragraph")
local Divider = require("@controls/Divider")
local Status = require("@controls/Status")
local Progress = require("@controls/Progress")
local Code = require("@controls/Code")
local Image = require("@controls/Image")
local Passthrough = require("@controls/Passthrough")
local Viewport = require("@controls/Viewport")
local Video = require("@controls/Video")
local TabBox = {}
TabBox.__index = TabBox
local SubTab = {}
SubTab.__index = SubTab

function SubTab.new(box, options)
	local self = setmetatable({
		Id = options.Id or string.lower(string.gsub(options.Title, "%s+", "-")),
		Title = options.Title,
		_options = options,
		_box = box,
		_window = box._window,
		_tab = box._tab,
		_janitor = Janitor.new("SubTab"),
		_controls = {},
		_mounted = false,
		_destroyed = false,
	}, SubTab)
	box._janitor:Add(self, "Destroy", self)
	return self
end
function SubTab:_mount()
	if self._mounted or self._destroyed or not self._box._mounted then
		return
	end
	self._mounted = true
	local w = self._window
	self._button = Create.New("TextButton", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "  " .. self.Title .. "  ",
		Font = w.Fonts.Medium,
		TextSize = w.Tokens:Get("FontSmall"),
		Parent = self._box._bar,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, 7), Parent = self._button })
	w:_bind(self._button, { BackgroundColor3 = "AccentSoft", TextColor3 = "TextSecondary" })
	self._page = Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = self._box._content,
	})
	self._layout = Create.List(w.Tokens:Get("RowGap"))
	self._layout.Parent = self._page
	self._janitor:Add(self._button.MouseButton1Click:Connect(function()
		self._box:Select(self.Id)
	end))
	for _, c in self._controls do
		c:_mount()
	end
	self:_refreshSeparators()
end
function SubTab:_controlParent()
	return self._page
end
function SubTab:_registerControl(c)
	table.insert(self._controls, c)
	if c._setContainerEnabled then
		c:_setContainerEnabled(self._box:IsEnabled())
	end
	if self._mounted then
		c:_mount()
		self:_refreshSeparators()
	end
end
function SubTab:_removeControl(c)
	local p = table.find(self._controls, c)
	if p then
		table.remove(self._controls, p)
	end
	self:_refreshSeparators()
end
function SubTab:_refreshSeparators()
	local v = {}
	for _, c in self._controls do
		if c._root and c._root.Visible then
			table.insert(v, c)
		end
	end
	for i, c in v do
		if c._separator then
			c._separator.Visible = i < #v
		end
	end
end
function SubTab:SetCollapsed(v)
	if not v then
		self._box:Select(self.Id)
	end
	return self
end
function SubTab:AddButton(o)
	return Button.new(self, o)
end
function SubTab:AddToggle(o)
	return Toggle.new(self, o)
end
function SubTab:AddSlider(o)
	return Slider.new(self, o)
end
function SubTab:AddDropdown(o)
	return Dropdown.new(self, o)
end
function SubTab:AddInput(o)
	return TextField.new(self, o)
end
function SubTab:AddKeybind(o)
	return Keybind.new(self, o)
end
function SubTab:AddColorPicker(o)
	return ColorPicker.new(self, o)
end
function SubTab:AddParagraph(o)
	return Paragraph.new(self, o)
end
function SubTab:AddDivider(o)
	return Divider.new(self, o or {})
end
function SubTab:AddStatus(o)
	return Status.new(self, o)
end
function SubTab:AddProgress(o)
	return Progress.new(self, o)
end
function SubTab:AddCode(o)
	return Code.new(self, o)
end
function SubTab:AddImage(o)
	return Image.new(self, o)
end
function SubTab:AddPassthrough(o)
	return Passthrough.new(self, o)
end
function SubTab:AddViewport(o)
	return Viewport.new(self, o)
end
function SubTab:AddVideo(o)
	return Video.new(self, o)
end
function SubTab:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for _, c in table.clone(self._controls) do
		c:Destroy()
	end
	self._janitor:Destroy()
end

function TabBox.new(section, options)
	options = options or {}
	if options.Id then
		section._window.Registry:AssertAvailable(options.Id, 3)
	end
	local self = setmetatable({
		_section = section,
		_window = section._window,
		_tab = section._tab,
		_janitor = Janitor.new("TabBox"),
		_tabs = {},
		_active = nil,
		_mounted = false,
		_destroyed = false,
		Title = options.Title or section.Title,
		Type = "TabBox",
		Id = options.Id,
		_manualVisible = options.Visible ~= false,
		_dependencyVisible = true,
		_manualEnabled = not (options.Disabled == true or type(options.Disabled) == "string"),
		_dependencyEnabled = true,
		_parentEnabled = true,
	}, TabBox)
	section._janitor:Add(self, "Destroy", self)
	if self.Id then
		self._window.Registry:Add(self, {
			Id = self.Id,
			Type = "TabBox",
			Title = self.Title or "TabBox",
			Tab = self._tab.Id,
			Section = section.Title,
			Path = `{self._tab.Title} -> {section.Title or "Default"}`,
			Persist = false,
		})
	end
	section:_registerControl(self)
	Dependency.Bind(self, options.VisibleWhen, "visible")
	Dependency.Bind(self, options.EnabledWhen, "enabled")
	if section._mounted then
		self:_mount()
	end
	return self
end
function TabBox:_mount()
	if self._mounted or self._destroyed then
		return
	end
	self._mounted = true
	local w = self._window
	local t = w.Tokens
	self._root = Create.New("Frame", {
		Name = "TabBox",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = self:IsVisible(),
		Parent = self._section:_controlParent(self),
	})
	self._janitor:Add(self._root)
	local rootLayout = Create.List(8)
	rootLayout.Parent = self._root
	self._bar = Create.New(
		"Frame",
		{ Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 0, BorderSizePixel = 0, Parent = self._root }
	)
	Create.New("UICorner", { CornerRadius = UDim.new(0, t:Get("FieldRadius")), Parent = self._bar })
	w:_bind(self._bar, { BackgroundColor3 = "ControlInset" })
	local l = Create.List(4, Enum.FillDirection.Horizontal)
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Parent = self._bar
	Create.New("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = self._bar })
	self._content = Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = self._root,
	})
	for _, tab in self._tabs do
		tab:_mount()
	end
	if self._active then
		self:Select(self._active.Id)
	elseif self._tabs[1] then
		self:Select(self._tabs[1].Id)
	end
	self:_applyContainerState()
end
function TabBox:AddTab(options)
	if type(options) ~= "table" or type(options.Title) ~= "string" then
		error("[BobloUI] TabBox:AddTab requires Title.", 2)
	end
	local id = options.Id or string.lower(string.gsub(options.Title, "%s+", "-"))
	for _, existing in self._tabs do
		if existing.Id == id then
			error(`[BobloUI] duplicate TabBox tab Id "{id}".`, 2)
		end
	end
	local tab = SubTab.new(self, options)
	table.insert(self._tabs, tab)
	if self._mounted then
		tab:_mount()
	end
	if not self._active then
		self._active = tab
		if self._mounted then
			self:Select(tab.Id)
		end
	end
	return tab
end
function TabBox:Select(id)
	for _, tab in self._tabs do
		local active = tab.Id == id
		if tab._page then
			tab._page.Visible = active
		end
		if tab._button then
			tab._button.BackgroundTransparency = if active then 0 else 1
			tab._button.TextColor3 = self._window.Theme:Get(if active then "Text" else "TextSecondary")
		end
		if active then
			self._active = tab
		end
	end
	return self
end
function TabBox:_refreshSeparators() end
function TabBox:SetVisible(visible)
	self._manualVisible = visible == true
	self:_applyContainerState()
	return self
end
function TabBox:IsVisible()
	return self._manualVisible and self._dependencyVisible
end
function TabBox:SetEnabled(enabled)
	self._manualEnabled = enabled ~= false
	self:_applyContainerState()
	return self
end
function TabBox:IsEnabled()
	return self._parentEnabled and self._manualEnabled and self._dependencyEnabled
end
function TabBox:_setContainerEnabled(enabled)
	self._parentEnabled = enabled ~= false
	self:_applyContainerState()
	return self
end
function TabBox:_applyContainerState()
	if self._root then
		self._root.Visible = self:IsVisible()
	end
	local enabled = self:IsEnabled()
	for _, tab in self._tabs do
		for _, control in tab._controls do
			if control._setContainerEnabled then
				control:_setContainerEnabled(enabled)
			end
		end
	end
	if self._section and self._section._refreshSeparators then
		self._section:_refreshSeparators()
	end
end
function TabBox:Reset()
	for _, tab in self._tabs do
		for _, c in tab._controls do
			if c.Reset then
				c:Reset()
			end
		end
	end
	return self
end
function TabBox:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._section._janitor:Release(self)
	for _, tab in table.clone(self._tabs) do
		tab:Destroy()
	end
	self._janitor:Destroy()
	self._window.Registry:Remove(self)
	self._section:_removeControl(self)
end
return TabBox
