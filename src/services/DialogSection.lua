--!nonstrict
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
local DialogSection = {}
DialogSection.__index = DialogSection
function DialogSection.new(window, parent, janitor)
	local fakeTab = { Id = "__dialog", Title = "Dialog", _page = parent, Select = function() end }
	return setmetatable({
		_window = window,
		_content = parent,
		_mounted = true,
		_janitor = janitor,
		_tab = fakeTab,
		_controls = {},
		Title = "Dialog",
	}, DialogSection)
end
function DialogSection:_registerControl(c)
	table.insert(self._controls, c)
end
function DialogSection:_removeControl(c)
	local p = table.find(self._controls, c)
	if p then
		table.remove(self._controls, p)
	end
	self:_refreshSeparators()
end
function DialogSection:_controlParent()
	return self._content
end
function DialogSection:_refreshSeparators()
	local visible = {}
	for _, control in self._controls do
		if control._root and control._root.Visible then
			table.insert(visible, control)
		end
	end
	for i, control in visible do
		if control._separator then
			control._separator.Visible = i < #visible
		end
	end
end
function DialogSection:AddButton(o)
	return Button.new(self, o)
end
function DialogSection:AddToggle(o)
	return Toggle.new(self, o)
end
function DialogSection:AddSlider(o)
	return Slider.new(self, o)
end
function DialogSection:AddDropdown(o)
	return Dropdown.new(self, o)
end
function DialogSection:AddInput(o)
	return TextField.new(self, o)
end
function DialogSection:AddKeybind(o)
	return Keybind.new(self, o)
end
function DialogSection:AddColorPicker(o)
	return ColorPicker.new(self, o)
end
function DialogSection:AddParagraph(o)
	return Paragraph.new(self, o)
end
function DialogSection:AddDivider(o)
	return Divider.new(self, o or {})
end
function DialogSection:AddStatus(o)
	return Status.new(self, o)
end
function DialogSection:AddProgress(o)
	return Progress.new(self, o)
end
function DialogSection:AddCode(o)
	return Code.new(self, o)
end
function DialogSection:AddImage(o)
	return Image.new(self, o)
end
function DialogSection:AddPassthrough(o)
	return Passthrough.new(self, o)
end
function DialogSection:AddViewport(o)
	return Viewport.new(self, o)
end
function DialogSection:AddVideo(o)
	return Video.new(self, o)
end
function DialogSection:SetCollapsed()
	return self
end
return DialogSection
