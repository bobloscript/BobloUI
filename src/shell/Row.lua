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
local Row = {}
Row.__index = Row
function Row.new(section, options)
	options = options or {}
	if options.Id then
		section._window.Registry:AssertAvailable(options.Id, 3)
	end
	local self = setmetatable({
		_section = section,
		_window = section._window,
		_tab = section._tab,
		_janitor = Janitor.new("Row"),
		_controls = {},
		_cells = {},
		_mounted = false,
		_destroyed = false,
		Columns = math.clamp(tonumber(options.Columns) or 2, 1, 4),
		Gap = tonumber(options.Gap) or section._window.Tokens:Get("ColumnGap"),
		Title = options.Title or section.Title,
		Type = "Row",
		Id = options.Id,
		_manualVisible = options.Visible ~= false,
		_dependencyVisible = true,
		_manualEnabled = not (options.Disabled == true or type(options.Disabled) == "string"),
		_dependencyEnabled = true,
		_parentEnabled = true,
	}, Row)
	section._janitor:Add(self, "Destroy", self)
	if self.Id then
		self._window.Registry:Add(self, {
			Id = self.Id,
			Type = "Row",
			Title = self.Title or "Row",
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
function Row:_mount()
	if self._mounted then
		return
	end
	self._mounted = true
	self._root = Create.New("Frame", {
		Name = "ControlRow",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Visible = self:IsVisible(),
		Parent = self._section:_controlParent(self),
	})
	self._janitor:Add(self._root)
	self._layout = Create.List(self.Gap, Enum.FillDirection.Horizontal)
	self._layout.VerticalAlignment = Enum.VerticalAlignment.Top
	self._layout.Parent = self._root
	for _, control in self._controls do
		control:_mount()
	end
	self:_applyContainerState()
end
function Row:_newCell()
	local index = #self._cells + 1
	if index > self.Columns then
		error(`[BobloUI] Row supports at most {self.Columns} controls. Create another row or increase Columns.`, 3)
	end
	local gap = self.Gap
	local width = 1 / self.Columns
	local offset = -gap * (self.Columns - 1) / self.Columns
	local cell = Create.New("Frame", {
		Name = "Cell" .. index,
		Size = UDim2.new(width, offset, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = index,
		Parent = self._root,
	})
	table.insert(self._cells, cell)
	return cell
end
function Row:_controlParent(control)
	if control._rowCell and control._rowCell.Parent then
		return control._rowCell
	end
	local cell = self:_newCell()
	control._rowCell = cell
	return cell
end
function Row:_registerControl(control)
	table.insert(self._controls, control)
	if control._setContainerEnabled then
		control:_setContainerEnabled(self:IsEnabled())
	end
	if self._mounted then
		control:_mount()
	end
end
function Row:_removeControl(control)
	local p = table.find(self._controls, control)
	if p then
		table.remove(self._controls, p)
	end
	if control._rowCell then
		local c = control._rowCell
		control._rowCell = nil
		local cp = table.find(self._cells, c)
		if cp then
			table.remove(self._cells, cp)
		end
		c:Destroy()
	end
end
function Row:_refreshSeparators()
	for _, c in self._controls do
		if c._separator then
			c._separator.Visible = false
		end
	end
end
function Row:SetCollapsed()
	return self
end
function Row:AddButton(o)
	return Button.new(self, o)
end
function Row:AddToggle(o)
	return Toggle.new(self, o)
end
function Row:AddSlider(o)
	return Slider.new(self, o)
end
function Row:AddDropdown(o)
	return Dropdown.new(self, o)
end
function Row:AddInput(o)
	return TextField.new(self, o)
end
function Row:AddKeybind(o)
	return Keybind.new(self, o)
end
function Row:AddColorPicker(o)
	return ColorPicker.new(self, o)
end
function Row:AddParagraph(o)
	return Paragraph.new(self, o)
end
function Row:AddDivider(o)
	return Divider.new(self, o or {})
end
function Row:AddStatus(o)
	return Status.new(self, o)
end
function Row:AddProgress(o)
	return Progress.new(self, o)
end
function Row:AddCode(o)
	return Code.new(self, o)
end
function Row:AddImage(o)
	return Image.new(self, o)
end
function Row:AddPassthrough(o)
	return Passthrough.new(self, o)
end
function Row:AddViewport(o)
	return Viewport.new(self, o)
end
function Row:AddVideo(o)
	return Video.new(self, o)
end
function Row:SetVisible(visible)
	self._manualVisible = visible == true
	self:_applyContainerState()
	return self
end
function Row:IsVisible()
	return self._manualVisible and self._dependencyVisible
end
function Row:SetEnabled(enabled)
	self._manualEnabled = enabled ~= false
	self:_applyContainerState()
	return self
end
function Row:IsEnabled()
	return self._parentEnabled and self._manualEnabled and self._dependencyEnabled
end
function Row:_setContainerEnabled(enabled)
	self._parentEnabled = enabled ~= false
	self:_applyContainerState()
	return self
end
function Row:_applyContainerState()
	if self._root then
		self._root.Visible = self:IsVisible()
	end
	local enabled = self:IsEnabled()
	for _, control in self._controls do
		if control._setContainerEnabled then
			control:_setContainerEnabled(enabled)
		end
	end
	if self._section and self._section._refreshSeparators then
		self._section:_refreshSeparators()
	end
end
function Row:Reset()
	for _, c in self._controls do
		if c.Reset then
			c:Reset()
		end
	end
	return self
end
function Row:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._section._janitor:Release(self)
	for _, c in table.clone(self._controls) do
		c:Destroy()
	end
	self._janitor:Destroy()
	self._window.Registry:Remove(self)
	self._section:_removeControl(self)
end
return Row
