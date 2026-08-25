local BobloUI =
	loadstring(game:HttpGet("https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.lua"))()

local UI = BobloUI:CreateWindow({
	Id = "bobloui-p1-p2-showcase",
	Title = "BobloUI P1/P2",
	Subtitle = "Completed Obsidian gap features",
	Icon = "sparkles",
	Theme = "Dark",
	ConfigFolder = "BobloUIP1P2",
	FooterText = "P1/P2 showcase · drag the sidebar edge",
	SidebarWidth = 190,
	EnableSidebarResize = true,
	Animations = { Window = true, Tabs = true, Controls = true },
})

local Main = UI:AddTab({ Id = "main", Title = "P1/P2", Icon = "blocks", Group = "SHOWCASE" })
local master = Main:AddToggle({ Id = "P12Master", Title = "Enable reactive containers", Default = true })
local features = Main:AddSection({
	Id = "p12-features",
	Title = "Reactive feature set",
	Description = "The whole section follows the master Toggle.",
	Icon = "workflow",
	Span = 1,
	VisibleWhen = { P12Master = true },
	EnabledWhen = { P12Master = true },
})

features:AddDropdown({
	Id = "P12Targets",
	Title = "Advanced multi-dropdown",
	Options = { "Alpha", "Beta", "Gamma", "Delta", "Epsilon" },
	Default = { "Alpha" },
	Multi = true,
	DragSelect = true,
	MaxVisibleRows = 3,
	DisabledValues = { "Epsilon" },
	ValueImages = { Alpha = "rbxassetid://0" },
	FormatDisplayValue = function(value, label)
		return tostring(label):upper()
	end,
})

local action = features:AddButton({
	Title = "Protected action",
	Text = "Double-click",
	Risky = true,
	DoubleClick = true,
	SubButtons = {
		{
			Text = "Info",
			Callback = function()
				UI.Notify:Push({ Title = "Sub-action" })
			end,
		},
	},
	Callback = function()
		UI.Notify:Push({ Title = "Action completed", Variant = "Success" })
	end,
})
action:AddKeybind({
	Id = "P12ActionKey",
	Title = "Action shortcut",
	Default = Enum.KeyCode.F,
	Modifiers = { "Ctrl" },
	Whitelist = { Enum.KeyCode.F },
	Mobile = true,
	MobileText = "Run protected action",
})

local media = Main:AddSection({ Title = "Media and passthrough", Icon = "gallery-horizontal", Span = 1 })
local customFrame = Instance.new("Frame")
customFrame.Size = UDim2.new(1, 0, 0, 48)
customFrame.BackgroundColor3 = Color3.fromHex("2A2440")
media:AddPassthrough({ Title = "Existing GuiObject", Instance = customFrame, Clone = true, Height = 48 })

local part = Instance.new("Part")
part.Anchored = true
part.Size = Vector3.new(3, 2, 1)
part.Color = Color3.fromHex("8172F2")
media:AddViewport({ Title = "Interactive viewport", Object = part, Clone = true, Interactive = true, Height = 150 })
media:AddImage({
	Title = "Sprite-ready image",
	Image = "rbxassetid://0",
	Height = 90,
	Tint = Color3.fromHex("FFFFFF"),
	Transparency = 0,
	RectOffset = Vector2.new(0, 0),
	RectSize = Vector2.new(0, 0),
})
media:AddVideo({ Title = "Video", Video = "rbxassetid://0", Height = 110, Looped = true, Volume = 0 })

local overlay =
	UI:AddDraggableLabel({ Text = "P1/P2 ready", Icon = "badge-check", Position = UDim2.fromOffset(16, 72) })
UI:AddDraggableButton({
	Text = "Open dialog v2",
	Icon = "panel-top-open",
	Position = UDim2.fromOffset(16, 112),
	Callback = function()
		UI.Dialog:Custom({
			Title = "Dialog v2",
			Description = "Dynamic footer, timed action and full controls.",
			OutsideClickDismiss = false,
			AutoDismiss = false,
			FooterButtons = {
				cancel = { Text = "Cancel", Order = 1 },
				continue = { Text = "Continue", Variant = "Primary", WaitTime = 2, Order = 2 },
			},
			Build = function(section)
				section:AddToggle({ Title = "Create backup", Default = true })
				section:AddProgress({ Title = "Readiness", Min = 0, Max = 100, Default = 75 })
			end,
		})
	end,
})

UI:OnUnload(function()
	overlay:Destroy()
	customFrame:Destroy()
	part:Destroy()
end)

return UI
