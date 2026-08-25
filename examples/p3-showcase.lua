local BobloUI = loadstring(game:HttpGet("YOUR_BOBLOUI_URL"))()

local UI = BobloUI:CreateWindow({
	Id = "p3-showcase",
	Title = "BobloUI P3",
	Theme = "Dark",
	SearchbarSize = 460,
	GlobalSearch = true,
	MobileButtonsSide = "Right",
	SidebarCollapseThreshold = 680,
	CompactWidthActivation = 1040,
	SidebarCompactWidth = 60,
	TabTransitionTime = 0.14,
	TabSwipeOffset = 56,
	TabSwipeFrom = "bottom",
	FooterText = "P3 controls · dictionary mode · responsive tuning",
})

local Tab = UI:AddTab({ Title = "P3", Icon = "settings-2" })
local Controls = Tab:AddSection({ Title = "Controls", Icon = "sliders-horizontal" })

Controls:AddInput({
	Id = "Nickname",
	Title = "Nickname",
	Default = "Player",
	AllowEmpty = false,
	EmptyReset = "Player",
	ClearTextOnBlur = true,
})

Controls:AddSlider({
	Id = "Distance",
	Title = "Distance",
	Min = 0,
	Max = 500,
	Default = 120,
	Prefix = "~",
	Suffix = " studs",
	HideMax = false,
	ValueInput = false,
	AllowRightClickInput = true,
	Compact = true,
})

Controls:AddParagraph({
	Content = '<b>P3</b> supports <font color="#7C5CFF">RichText</font>, manual sizing and wrapping.',
	RichText = true,
	Size = 15,
	DoesWrap = true,
})

Controls:AddDivider({ Text = "Dictionary values", MarginTop = 8, MarginBottom = 12 })

Controls:AddDropdown({
	Id = "Modes",
	Title = "Modes",
	Values = {
		Legit = "Legit",
		Rage = "Rage",
		Visual = "Visual",
	},
	Multi = true,
	Default = { Legit = true },
})

return UI
