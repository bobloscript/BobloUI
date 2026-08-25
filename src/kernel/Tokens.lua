--!nonstrict
local Signal = require("@runtime/Signal")

local Tokens = {}
Tokens.__index = Tokens
Tokens.MinTapTarget = 42

local function enumFont(name, fallback)
	for _, item in Enum.Font:GetEnumItems() do
		if item.Name == name then
			return item
		end
	end
	return fallback
end

Tokens.Fonts = {
	Regular = enumFont("BuilderSans", Enum.Font.Gotham),
	Medium = enumFont("BuilderSansMedium", Enum.Font.GothamMedium),
	Bold = enumFont("BuilderSansBold", Enum.Font.GothamBold),
	Heavy = enumFont("BuilderSansExtraBold", Enum.Font.GothamBold),
}

Tokens.Profiles = {
	Comfortable = {
		ControlHeight = 47,
		ControlPadding = 13,
		ControlRadius = 8,
		FieldHeight = 34,
		FieldRadius = 8,
		RowGap = 2,
		SectionGap = 14,
		ColumnGap = 14,
		TwoColumnMinWidth = 586,
		MinSectionWidth = 286,
		ControlStackBreakpoint = 300,
		ControlGridMinWidth = 600,
		SectionPadding = 12,
		PagePadding = 20,
		HeaderHeight = 56,
		SidebarWidth = 168,
		RailWidth = 54,
		NavItemHeight = 38,
		FontCaption = 11,
		FontSmall = 12,
		FontBody = 14,
		FontTitle = 15,
		FontHeading = 18,
		FontDisplay = 21,
		IconSm = 14,
		IconMd = 18,
		CornerSm = 7,
		CornerMd = 10,
		CornerLg = 14,
		Stroke = 1,
		SliderTrack = 4,
		SliderKnob = 12,
	},
	Compact = {
		ControlHeight = 40,
		ControlPadding = 10,
		ControlRadius = 9,
		FieldHeight = 31,
		FieldRadius = 7,
		RowGap = 0,
		SectionGap = 10,
		ColumnGap = 12,
		TwoColumnMinWidth = 546,
		MinSectionWidth = 267,
		ControlStackBreakpoint = 282,
		ControlGridMinWidth = 560,
		SectionPadding = 9,
		PagePadding = 18,
		HeaderHeight = 50,
		SidebarWidth = 158,
		RailWidth = 50,
		NavItemHeight = 35,
		FontCaption = 10,
		FontSmall = 11,
		FontBody = 13,
		FontTitle = 14,
		FontHeading = 18,
		FontDisplay = 20,
		IconSm = 14,
		IconMd = 18,
		CornerSm = 7,
		CornerMd = 10,
		CornerLg = 15,
		Stroke = 1,
		SliderTrack = 4,
		SliderKnob = 10,
	},
	Touch = {
		ControlHeight = 48,
		ControlPadding = 13,
		ControlRadius = 11,
		FieldHeight = 38,
		FieldRadius = 9,
		RowGap = 0,
		SectionGap = 15,
		ColumnGap = 14,
		TwoColumnMinWidth = 626,
		MinSectionWidth = 306,
		ControlStackBreakpoint = 324,
		ControlGridMinWidth = 640,
		SectionPadding = 14,
		PagePadding = 14,
		HeaderHeight = 54,
		SidebarWidth = 238,
		RailWidth = 60,
		NavItemHeight = 48,
		FontCaption = 11,
		FontSmall = 13,
		FontBody = 15,
		FontTitle = 16,
		FontHeading = 20,
		FontDisplay = 22,
		IconSm = 17,
		IconMd = 21,
		CornerSm = 8,
		CornerMd = 12,
		CornerLg = 17,
		Stroke = 1,
		SliderTrack = 5,
		SliderKnob = 16,
	},
}

function Tokens.new(density: string?, deviceClass: string?)
	local self = setmetatable({
		Changed = Signal.new("Tokens.Changed"),
		_density = density or "Comfortable",
		_deviceClass = deviceClass or "Desktop",
		_values = {},
	}, Tokens)
	self:_recompute()
	return self
end
function Tokens:_effectiveDensity()
	if self._deviceClass == "Phone" and self._density == "Comfortable" then
		return "Touch"
	end
	return self._density
end
function Tokens:_recompute()
	local profile = Tokens.Profiles[self:_effectiveDensity()] or Tokens.Profiles.Comfortable
	local values = table.clone(profile)
	if self._deviceClass == "Phone" then
		values.ControlHeight = math.max(values.ControlHeight, Tokens.MinTapTarget)
		values.NavItemHeight = math.max(values.NavItemHeight, Tokens.MinTapTarget)
		values.FieldHeight = math.max(values.FieldHeight, 34)
	end
	self._values = values
end
function Tokens:Get(key)
	local value = self._values[key]
	if value == nil then
		error(`[BobloUI] unknown token "{key}"`, 2)
	end
	return value
end
function Tokens:All()
	return table.clone(self._values)
end
function Tokens:GetDensity()
	return self._density
end
function Tokens:SetDensity(density)
	if not Tokens.Profiles[density] then
		error(`[BobloUI] unknown density "{density}". Valid: Comfortable, Compact, Touch`, 2)
	end
	if self._density == density then
		return
	end
	self._density = density
	self:_recompute()
	self.Changed:Fire(self)
end
function Tokens:SetDeviceClass(deviceClass)
	if self._deviceClass == deviceClass then
		return
	end
	self._deviceClass = deviceClass
	local before = self._values
	self:_recompute()
	for key, value in self._values do
		if before[key] ~= value then
			self.Changed:Fire(self)
			return
		end
	end
end
function Tokens:Destroy()
	self.Changed:Destroy()
end
return Tokens
