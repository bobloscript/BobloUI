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
		ControlHeight = 40,
		ControlPadding = 12,
		ControlRadius = 5,
		FieldHeight = 34,
		FieldRadius = 4,
		RowGap = 2,
		SectionGap = 12,
		ColumnGap = 12,
		TwoColumnMinWidth = 560,
		MinSectionWidth = 268,
		ControlStackBreakpoint = 280,
		ControlGridMinWidth = 560,
		SectionPadding = 10,
		PagePadding = 16,
		HeaderHeight = 46,
		SidebarWidth = 162,
		RailWidth = 50,
		NavItemHeight = 36,
		FontCaption = 11,
		FontSmall = 11,
		FontBody = 13,
		FontTitle = 14,
		FontHeading = 16,
		FontDisplay = 18,
		IconSm = 14,
		IconMd = 16,
		CornerSm = 5,
		CornerMd = 6,
		CornerLg = 8,
		Stroke = 1,
		SliderTrack = 4,
		SliderKnob = 10,
	},
	Compact = {
		ControlHeight = 38,
		ControlPadding = 10,
		ControlRadius = 4,
		FieldHeight = 30,
		FieldRadius = 4,
		RowGap = 0,
		SectionGap = 10,
		ColumnGap = 10,
		TwoColumnMinWidth = 520,
		MinSectionWidth = 256,
		ControlStackBreakpoint = 270,
		ControlGridMinWidth = 520,
		SectionPadding = 8,
		PagePadding = 14,
		HeaderHeight = 44,
		SidebarWidth = 152,
		RailWidth = 48,
		NavItemHeight = 34,
		FontCaption = 10,
		FontSmall = 11,
		FontBody = 13,
		FontTitle = 13,
		FontHeading = 15,
		FontDisplay = 17,
		IconSm = 13,
		IconMd = 15,
		CornerSm = 4,
		CornerMd = 5,
		CornerLg = 7,
		Stroke = 1,
		SliderTrack = 3,
		SliderKnob = 8,
	},
	Touch = {
		ControlHeight = 48,
		ControlPadding = 12,
		ControlRadius = 8,
		FieldHeight = 36,
		FieldRadius = 6,
		RowGap = 0,
		SectionGap = 12,
		ColumnGap = 12,
		TwoColumnMinWidth = 600,
		MinSectionWidth = 290,
		ControlStackBreakpoint = 310,
		ControlGridMinWidth = 600,
		SectionPadding = 12,
		PagePadding = 14,
		HeaderHeight = 48,
		SidebarWidth = 228,
		RailWidth = 56,
		NavItemHeight = 44,
		FontCaption = 11,
		FontSmall = 12,
		FontBody = 14,
		FontTitle = 15,
		FontHeading = 18,
		FontDisplay = 20,
		IconSm = 16,
		IconMd = 19,
		CornerSm = 6,
		CornerMd = 8,
		CornerLg = 10,
		Stroke = 1,
		SliderTrack = 4,
		SliderKnob = 14,
	},
}

function Tokens.new(density: string?, deviceClass: string?, minimal: boolean?)
	local self = setmetatable({
		Changed = Signal.new("Tokens.Changed"),
		_density = density or "Comfortable",
		_deviceClass = deviceClass or "Desktop",
		_minimal = minimal == true,
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
	if self._minimal then
		values.ControlHeight = math.max(44, values.ControlHeight)
		values.PagePadding = 8
		values.SectionGap = 8
		values.RowGap = 4
		values.SectionPadding = 0
		values.HeaderHeight = 46
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
