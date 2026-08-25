--[[
	BobloUI full runtime diagnostic

	Purpose:
	  * loads the published GitHub build with a cache-busting query;
	  * exercises the public API without stopping at the first failure;
	  * shows PASS / FAIL / SKIP results inside BobloUI and in the console;
	  * leaves the window open for visual, mouse, keyboard and touch checks.

	Run this in the same Roblox executor / Studio environment in which BobloUI
	will be used. Upload dist/BobloUI.lua to the URL below before running it.
]]

local SOURCE = "https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.lua"
local EXPECTED_VERSION = "0.11.5-beta.1"
local EXPECTED_API_LEVEL = 11
local PREVIOUS_RUN_KEY = "__BOBLOUI_FULL_DIAGNOSTIC"

local HttpService = game:GetService("HttpService")

local function fatal(message)
	error("[BobloUI Full Diagnostic] " .. tostring(message), 0)
end

local globals = _G
if type(getgenv) == "function" then
	globals = getgenv()
end

local previous = globals[PREVIOUS_RUN_KEY]
if previous then
	pcall(function()
		previous:Unload()
	end)
	globals[PREVIOUS_RUN_KEY] = nil
end

local cacheBust = tostring(os.time()) .. "-" .. tostring(math.floor(os.clock() * 100000))
local requestUrl = SOURCE .. "?cb=" .. cacheBust
local httpOk, sourceOrError = pcall(function()
	return game:HttpGet(requestUrl)
end)
if not httpOk then
	fatal("cannot download BobloUI.lua: " .. tostring(sourceOrError))
end

local chunk, compileError = loadstring(sourceOrError, "@BobloUI.lua")
if not chunk then
	fatal("downloaded BobloUI.lua does not compile: " .. tostring(compileError))
end

local loadOk, BobloUI = xpcall(chunk, debug.traceback)
if not loadOk then
	fatal("BobloUI.lua failed during initialization:\n" .. tostring(BobloUI))
end
if type(BobloUI) ~= "table" then
	fatal("BobloUI.lua returned " .. typeof(BobloUI) .. " instead of a library table")
end

local guidOk, guid = pcall(function()
	return HttpService:GenerateGUID(false)
end)
if not guidOk then
	guid = tostring(os.time()) .. "-" .. tostring(math.floor(os.clock() * 100000))
end

local windowId = "bobloui-full-diagnostic-" .. guid
local statePrefix = "__diag." .. guid .. "."
local configPrefix = "Diag_" .. string.gsub(guid, "%-", "")
local configFolder = "BobloUI_FullDiagnostic"
local themeArtifacts = {}

-- Public extension surfaces are registered before the window is constructed.
BobloUI.Icon.Register("diagnostic-dot", function(window, root)
	local dot = Instance.new("Frame")
	dot.Name = "DiagnosticDot"
	dot.Size = UDim2.fromOffset(9, 9)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.BorderSizePixel = 0
	dot.BackgroundColor3 = window.Theme:Get("Accent")
	dot.Parent = root

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
end)

BobloUI:RegisterControl("DiagnosticAction", function(section, options)
	return section:AddButton({
		Id = options.Id,
		Title = options.Title or "Custom action",
		Description = options.Description,
		Text = options.Text or "Run",
		Icon = options.Icon or "diagnostic-dot",
		Variant = options.Variant,
		Callback = options.Callback,
	})
end)

local UI = BobloUI:CreateWindow({
	Id = windowId,
	Title = "BobloUI Full Diagnostic",
	Subtitle = "automatic API checks + manual visual QA",
	Icon = "flask-conical",
	Theme = "Dark",
	Accent = Color3.fromHex("8172F2"),
	Density = "Comfortable",
	Scale = 1,
	Size = UDim2.fromOffset(860, 620),
	ConfigFolder = configFolder,
	AutoLoad = false,
	Settings = true,
	RememberGeometry = true,
	KeyboardNavigation = true,
	ReducedMotion = false,
	SoundEnabled = false,
	SoundVolume = 0,
	ToggleUIKeybind = Enum.KeyCode.RightShift,
	ShowText = "Show BobloUI",
	FooterText = "BobloUI diagnostic · ready",
	SidebarWidth = 184,
	EnableSidebarResize = true,
	Compact = false,
	Animations = { Window = true, Tabs = true, Controls = true },
	NotificationPosition = "TopRight",
	Opacity = 0.98,
	RestoreButton = {
		Mode = "Always",
		Text = "Show BobloUI",
		Draggable = true,
	},
	TabTransition = {
		Style = "Slide",
		Direction = "Right",
		Duration = 0.08,
		Offset = 8,
	},
	WindowAnimation = {
		Style = "SlideDown",
		Duration = 0.08,
		Offset = 8,
	},
})

globals[PREVIOUS_RUN_KEY] = UI
UI:OnUnload(function()
	if globals[PREVIOUS_RUN_KEY] == UI then
		globals[PREVIOUS_RUN_KEY] = nil
	end
end)

-- Result collector ---------------------------------------------------------

local tests = {}
local results = {
	Passed = 0,
	Failed = 0,
	Skipped = 0,
	Lines = {},
}

local function addTest(group, name, callback)
	table.insert(tests, {
		Group = group,
		Name = name,
		Callback = callback,
	})
end

local function expect(condition, message)
	if not condition then
		error(message or "expectation failed", 2)
	end
end

local function expectEqual(actual, expected, message)
	if actual ~= expected then
		error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

local function closeEnough(actual, expected, epsilon)
	return math.abs(actual - expected) <= (epsilon or 0.001)
end

local function linearChannel(channel)
	if channel <= 0.04045 then
		return channel / 12.92
	end
	return ((channel + 0.055) / 1.055) ^ 2.4
end

local function relativeLuminance(color)
	return 0.2126 * linearChannel(color.R) + 0.7152 * linearChannel(color.G) + 0.0722 * linearChannel(color.B)
end

local function contrastRatio(first, second)
	local a = relativeLuminance(first)
	local b = relativeLuminance(second)
	return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05)
end

local function contains(text, fragment)
	return string.find(tostring(text), tostring(fragment), 1, true) ~= nil
end

local function waitFor(predicate, timeout)
	local deadline = os.clock() + (timeout or 2)
	repeat
		local ok, value = pcall(predicate)
		if ok and value then
			return true
		end
		task.wait()
	until os.clock() >= deadline
	return false
end

local function skip(reason)
	error({
		__diagnosticSkip = true,
		Reason = reason or "not available in this environment",
	}, 0)
end

local function errorHandler(value)
	if type(value) == "table" and value.__diagnosticSkip then
		return value
	end
	return debug.traceback(tostring(value), 2)
end

local function short(text, limit)
	text = tostring(text or "")
	limit = limit or 650
	if #text <= limit then
		return text
	end
	return string.sub(text, 1, limit) .. "..."
end

local function record(kind, test, detail)
	local prefix = "[" .. kind .. "] " .. test.Group .. " / " .. test.Name
	if detail and detail ~= "" then
		prefix = prefix .. " — " .. short(detail)
	end
	table.insert(results.Lines, prefix)
	if kind == "FAIL" then
		warn("[BobloUI Full Diagnostic] " .. prefix)
	else
		print("[BobloUI Full Diagnostic] " .. prefix)
	end
end

-- Visible test surface -----------------------------------------------------

local OverviewTab = UI:AddTab({
	Id = "diag-overview",
	Title = "Overview",
	Description = "Automatic diagnostic results",
	Icon = "dashboard",
	Group = "DIAGNOSTIC",
	Badge = "RUN",
})
local ControlsTab = UI:AddTab({
	Id = "diag-controls",
	Title = "Controls",
	Description = "Every built-in control",
	Icon = "sliders",
	Group = "DIAGNOSTIC",
})
local LayoutTab = UI:AddTab({
	Id = "diag-layout",
	Title = "Layout",
	Description = "Sections, rows, TabBox and schema",
	Icon = "layout",
	Group = "DIAGNOSTIC",
})
local ServicesTab = UI:AddTab({
	Id = "diag-services",
	Title = "Services",
	Description = "Notifications, dialogs and overlays",
	Icon = "settings",
	Group = "RUNTIME",
})
local ManualTab = UI:AddTab({
	Id = "diag-manual",
	Title = "Manual QA",
	Description = "Checks that require a real person or device",
	Icon = "check",
	Group = "RUNTIME",
	Badge = "9",
})
local LockedTab = UI:AddTab({
	Id = "diag-locked",
	Title = "Locked tab",
	Description = "Used by the lock lifecycle test",
	Icon = "lock",
	Group = "RUNTIME",
	Locked = true,
	LockedReason = "The automatic test unlocks this tab.",
	Visible = false,
})

local SummarySection = OverviewTab:AddSection({
	Id = "diag-summary-section",
	Title = "Runtime report",
	Description = "The suite continues after failures and leaves this UI open.",
	Icon = "activity",
	Span = 2,
	Layout = "Stack",
})
local RunStatus = SummarySection:AddStatus({
	Title = "Suite status",
	Value = "Preparing tests",
	Status = "Pending",
	Pulse = true,
})
local RunProgress = SummarySection:AddProgress({
	Id = "DiagRunProgress",
	Title = "Automatic checks",
	Min = 0,
	Max = 1,
	Default = 0,
	Suffix = "",
	IgnoreConfig = true,
})
local SummaryParagraph = SummarySection:AddParagraph({
	Title = "What is covered",
	Content = "Public API, all 16 controls, reactive containers, State/Store, Config regressions, Search, Commands, persisted themes, window customization, dialog v2, overlays, notifications, staged loading, HUD, schema building and cleanup.",
	Variant = "Info",
})
local ReportCode = SummarySection:AddCode({
	Title = "Detailed output",
	Language = "text",
	Code = "Tests have not started yet.",
	Height = 230,
	Copy = true,
})

-- Built-in controls --------------------------------------------------------

local actionClicks = 0
local disabledClicks = 0
local toggleCallbacks = 0

local CoreSection = ControlsTab:AddSection({
	Id = "diag-core-section",
	Title = "Actions and values",
	Description = "Button, toggles, slider and inputs",
	Icon = "zap",
	Span = 1,
	Layout = "Auto",
	Collapsible = true,
})
local SelectSection = ControlsTab:AddSection({
	Id = "diag-select-section",
	Title = "Selectors",
	Description = "Dropdown, keybind and color",
	Icon = "sliders-horizontal",
	Span = 1,
	Layout = "Auto",
	Collapsible = true,
})
local PresentationSection = ControlsTab:AddSection({
	Id = "diag-presentation-section",
	Title = "Presentation",
	Description = "Read-only and media controls",
	Icon = "image",
	Span = 2,
	Layout = "Grid",
	Collapsible = true,
})

local ActionButton = CoreSection:AddButton({
	Id = "DiagButton",
	Title = "Primary action",
	Description = "Programmatic Click and interactive click",
	Text = "Run",
	Variant = "Primary",
	Icon = "play",
	Keywords = { "diagnostic", "action", "primary" },
	Tooltip = "Tooltip attachment is checked visually.",
	ContextMenu = {
		{
			Text = "Context action",
			Callback = function()
				actionClicks += 10
			end,
		},
	},
	Callback = function()
		actionClicks += 1
	end,
})
local doubleClicks = 0
local DoubleClickButton = CoreSection:AddButton({
	Title = "Double-click action",
	Text = "Double click",
	DoubleClick = true,
	DoubleClickWindow = 0.8,
	SubButtons = {
		{ Text = "More", Callback = function() end },
	},
	Callback = function()
		doubleClicks += 1
	end,
})
local DisabledButton = CoreSection:AddButton({
	Title = "Disabled action",
	Text = "Unavailable",
	Disabled = "Diagnostic disabled reason",
	Variant = "Ghost",
	Callback = function()
		disabledClicks += 1
	end,
})
local Toggle = CoreSection:AddToggle({
	Id = "DiagToggle",
	Title = "Master toggle",
	Description = "Dependency owner",
	Default = false,
	Icon = "toggle-right",
	Callback = function()
		toggleCallbacks += 1
	end,
})
local Checkbox = CoreSection:AddToggle({
	Id = "DiagCheckbox",
	Title = "Checkbox style",
	Default = true,
	Style = "Checkbox",
})
local Slider = CoreSection:AddSlider({
	Id = "DiagSlider",
	Title = "Advanced slider",
	Description = "Step, precision, suffix, floating value and input",
	Min = 0,
	Max = 100,
	Step = 5,
	Default = 25,
	Precision = 0,
	Suffix = "%",
	ValueInput = true,
	FloatingValue = true,
	IconFrom = "minus",
	IconTo = "plus",
	VisibleWhen = { DiagToggle = true },
})
local Input = CoreSection:AddInput({
	Id = "DiagInput",
	Title = "Text input",
	Default = "BobloUI",
	Placeholder = "Type text",
	MaxLength = 32,
	Validate = function(value)
		return #tostring(value) >= 2, "Use at least two characters"
	end,
})
local NumericInput = CoreSection:AddInput({
	Id = "DiagNumber",
	Title = "Numeric input",
	Default = 7,
	Numeric = true,
	CommitOn = "Enter",
})
local MultilineInput = CoreSection:AddInput({
	Id = "DiagNotes",
	Title = "Multiline input",
	Default = "Line one\nLine two",
	Placeholder = "Notes",
	Multiline = true,
	Height = 90,
})
local P3Input = CoreSection:AddInput({
	Id = "DiagP3Input",
	Title = "P3 empty policy",
	Default = "Reset value",
	AllowEmpty = false,
	EmptyReset = "Reset value",
	ClearTextOnBlur = true,
})
local P3Slider = CoreSection:AddSlider({
	Id = "DiagP3Slider",
	Title = "P3 slider",
	Min = 0,
	Max = 10,
	Default = 5,
	Prefix = "~",
	Suffix = "x",
	HideMax = false,
	Compact = true,
	ValueInput = false,
	AllowRightClickInput = true,
})
local DependencyButton = CoreSection:AddButton({
	Id = "DiagDependentButton",
	Title = "Tracked dependency",
	Text = "Enabled by toggle",
	EnabledWhen = function(state)
		return state:Get("DiagToggle") == true
	end,
	Callback = function() end,
})

local Dropdown = SelectSection:AddDropdown({
	Id = "DiagDropdown",
	Title = "Searchable dropdown",
	Options = {
		{ Value = "safe", Title = "Safe", Description = "Normal mode", Icon = "check" },
		{ Value = "fast", Title = "Fast", Description = "Faster mode", Icon = "star" },
		{
			Value = "locked",
			Title = "Locked",
			Description = "Unavailable option",
			Icon = "lock",
			Locked = true,
			LockedReason = "Diagnostic locked option",
		},
	},
	Default = "safe",
	Searchable = true,
})
local MultiDropdown = SelectSection:AddDropdown({
	Id = "DiagMulti",
	Title = "Multi-select",
	Options = { "Alpha", "Beta", "Gamma", "Delta" },
	Default = { "Alpha" },
	Multi = true,
	Max = 3,
	AllowNone = true,
})
local MapDropdown = SelectSection:AddDropdown({
	Id = "DiagMapDropdown",
	Title = "Dictionary multi-select",
	Values = { alpha = "Alpha", beta = "Beta", gamma = "Gamma" },
	Default = { alpha = true },
	Multi = true,
})
local SegmentedDropdown = SelectSection:AddDropdown({
	Id = "DiagSegmented",
	Title = "Segmented style",
	Options = { "Low", "Medium", "High" },
	Default = "Medium",
	Style = "Segmented",
})

local sourceValues = { "One", "Two" }
local sourceSignal = Instance.new("BindableEvent")
local SourceDropdown = SelectSection:AddDropdown({
	Id = "DiagSource",
	Title = "Reactive data source",
	Source = BobloUI.Source(function()
		return sourceValues
	end, { sourceSignal.Event }),
	Default = "One",
	AllowNone = true,
	IgnoreConfig = true,
})
local PlayersDropdown = SelectSection:AddDropdown({
	Id = "DiagPlayerSource",
	Title = "Players source",
	Source = BobloUI.Sources.Players({ IncludeLocalPlayer = true }),
	AllowNone = true,
	IgnoreConfig = true,
})
local Keybind = SelectSection:AddKeybind({
	Id = "DiagKeybind",
	Title = "Diagnostic keybind",
	Default = Enum.KeyCode.F,
	Mode = "Toggle",
	AllowedModes = { "Toggle", "Hold", "Always" },
	Blacklist = { Enum.KeyCode.RightShift },
	Whitelist = { Enum.KeyCode.F, Enum.KeyCode.G },
	DefaultModifiers = { "Ctrl" },
	ModifierWhitelist = { "Ctrl", "Shift" },
	BlacklistModifiers = { "Alt" },
	ExactModifiers = true,
	WaitForCallback = true,
	Mobile = true,
	MobileText = "Diagnostic action",
	CustomModes = {
		Pulse = function(event, active)
			return if event == "Press" then true else active
		end,
	},
	Callback = function() end,
})
local AttachedKeybind = Toggle:AddKeybind({
	Id = "DiagAttachedKeybind",
	Title = "Attached keybind",
	Default = Enum.KeyCode.G,
	Mode = "Toggle",
	NoUI = true,
	Mobile = true,
})
local ColorPicker = SelectSection:AddColorPicker({
	Id = "DiagColor",
	Title = "Color + alpha",
	Default = Color3.fromHex("8172F2"),
	Alpha = true,
	DefaultAlpha = 0.8,
	Presets = {
		Color3.fromHex("8172F2"),
		Color3.fromHex("FF5EA8"),
		Color3.fromHex("43D17A"),
	},
})

local Paragraph = PresentationSection:AddParagraph({
	Id = "DiagParagraph",
	Title = "Information paragraph",
	Content = "This text is replaced by the automatic control-method test.",
	Variant = "Info",
})
PresentationSection:AddParagraph({ Content = "Warning presentation variant", Variant = "Warning" })
PresentationSection:AddParagraph({ Content = "Danger presentation variant", Variant = "Danger" })
local Divider = PresentationSection:AddDivider({ Title = "Runtime values" })
local P3Paragraph = PresentationSection:AddParagraph({
	Content = "<b>Rich P3 paragraph</b>",
	RichText = true,
	DoesWrap = true,
	Size = 15,
})
local P3Divider = PresentationSection:AddDivider({ Text = "P3 margins", MarginTop = 6, MarginBottom = 9 })
local Status = PresentationSection:AddStatus({
	Id = "DiagStatus",
	Title = "Service health",
	Value = "Ready",
	Status = "Success",
	Pulse = true,
})
local Progress = PresentationSection:AddProgress({
	Id = "DiagProgress",
	Title = "Progress control",
	Min = 0,
	Max = 100,
	Default = 35,
	Suffix = "%",
})
local Code = PresentationSection:AddCode({
	Id = "DiagCode",
	Title = "Code block",
	Code = "print('BobloUI diagnostic')",
	Language = "lua",
	Height = 100,
	Copy = true,
})
local Image = PresentationSection:AddImage({
	Id = "DiagImage",
	Title = "Image block",
	Image = "rbxassetid://0",
	Height = 90,
	Caption = "Replace rbxassetid://0 for a real visual check.",
	ScaleType = Enum.ScaleType.Fit,
	Tint = Color3.new(1, 1, 1),
	Transparency = 0,
	BackgroundTransparency = 0.2,
	RectOffset = Vector2.new(0, 0),
	RectSize = Vector2.new(0, 0),
})
local PassthroughSource = Instance.new("Frame")
PassthroughSource.Name = "DiagnosticPassthroughSource"
PassthroughSource.Size = UDim2.new(1, 0, 0, 46)
PassthroughSource.BackgroundColor3 = Color3.fromHex("2A2440")
local passthroughCorner = Instance.new("UICorner")
passthroughCorner.CornerRadius = UDim.new(0, 8)
passthroughCorner.Parent = PassthroughSource
local Passthrough = PresentationSection:AddPassthrough({
	Id = "DiagPassthrough",
	Title = "Passthrough GuiObject",
	Instance = PassthroughSource,
	Height = 46,
	Clone = true,
})
local ViewportPart = Instance.new("Part")
ViewportPart.Name = "DiagnosticViewportPart"
ViewportPart.Anchored = true
ViewportPart.Size = Vector3.new(3, 2, 1)
ViewportPart.Color = Color3.fromHex("8172F2")
local Viewport = PresentationSection:AddViewport({
	Id = "DiagViewport",
	Title = "Viewport",
	Object = ViewportPart,
	Height = 120,
	Interactive = true,
	Clone = true,
})
local Video = PresentationSection:AddVideo({
	Id = "DiagVideo",
	Title = "Video",
	Video = "rbxassetid://0",
	Height = 100,
	Looped = false,
	Playing = false,
	Volume = 0,
})
local customClicks = 0
local CustomControl = PresentationSection:AddCustom("DiagnosticAction", {
	Id = "DiagCustomAction",
	Title = "Registered custom control",
	Text = "Custom",
	Variant = "Ghost",
	Callback = function()
		customClicks += 1
	end,
})

-- Layout primitives --------------------------------------------------------

local StackSection = LayoutTab:AddSection({
	Id = "diag-stack-section",
	Title = "Stack section",
	Description = "Span=1, Layout=Stack, adaptive controls",
	Icon = "list",
	Span = 1,
	Layout = "Stack",
	Collapsible = true,
})
local GridSection = LayoutTab:AddSection({
	Id = "diag-grid-section",
	Title = "Grid section",
	Description = "Span=1, Layout=Grid",
	Icon = "grid",
	Span = 1,
	Layout = "Grid",
	Collapsible = true,
})
local AutoSection = LayoutTab:AddSection({
	Id = "diag-auto-section",
	Title = "Auto section",
	Description = "Span=2 and responsive layout",
	Icon = "layout",
	Span = 2,
	Layout = "Auto",
	Collapsible = true,
})

local LayoutToggle = StackSection:AddToggle({
	Id = "DiagLayoutToggle",
	Title = "Adaptive toggle",
	Default = false,
	Adaptive = true,
})
StackSection:AddSlider({
	Id = "DiagLayoutSlider",
	Title = "Adaptive slider",
	Min = 0,
	Max = 10,
	Default = 4,
	Adaptive = true,
})
GridSection:AddInput({
	Id = "DiagGridInput",
	Title = "Grid input",
	Default = "Grid",
})
GridSection:AddDropdown({
	Id = "DiagGridDropdown",
	Title = "Grid dropdown",
	Options = { "A", "B" },
	Default = "A",
})

local Row = AutoSection:AddRow({ Columns = 3, Gap = 8 })
local RowButtonClicks = 0
local RowButton = Row:AddButton({
	Title = "Row button",
	Text = "Left",
	Callback = function()
		RowButtonClicks += 1
	end,
})
local RowToggle = Row:AddToggle({ Id = "DiagRowToggle", Title = "Center", Default = true, Style = "Checkbox" })
local RowStatus = Row:AddStatus({ Title = "Right", Value = "OK", Status = "Success" })

local TabBox = AutoSection:AddTabBox({ Title = "Nested TabBox" })
local SubTabA = TabBox:AddTab({ Id = "a", Title = "First" })
local TabBoxToggle = SubTabA:AddToggle({ Id = "DiagTabBoxToggle", Title = "Nested toggle", Default = true })
local SubTabB = TabBox:AddTab({ Id = "b", Title = "Second" })
local TabBoxSlider = SubTabB:AddSlider({
	Id = "DiagTabBoxSlider",
	Title = "Nested slider",
	Min = 0,
	Max = 20,
	Default = 10,
})

local ReactiveSection = LayoutTab:AddSection({
	Id = "diag-reactive-section",
	Title = "Reactive containers",
	Icon = "workflow",
	Span = 2,
	VisibleWhen = { DiagLayoutToggle = true },
	EnabledWhen = function(state)
		return state:Get("DiagToggle") == true
	end,
})
local ReactiveSectionToggle = ReactiveSection:AddToggle({
	Id = "DiagReactiveSectionToggle",
	Title = "Section child",
	Default = false,
})
local ReactiveRow = ReactiveSection:AddRow({
	Id = "diag-reactive-row",
	Columns = 1,
	EnabledWhen = { DiagLayoutToggle = true },
})
local ReactiveRowButton = ReactiveRow:AddButton({ Title = "Row child", Text = "Reactive" })
local ReactiveTabBox = ReactiveSection:AddTabBox({
	Id = "diag-reactive-tabbox",
	Title = "Reactive TabBox",
	VisibleWhen = { DiagLayoutToggle = true },
})
local ReactiveSubTab = ReactiveTabBox:AddTab({ Id = "reactive", Title = "Reactive" })
local ReactiveTabToggle = ReactiveSubTab:AddToggle({
	Id = "DiagReactiveTabToggle",
	Title = "TabBox child",
	Default = true,
})

-- Manual and service launchers --------------------------------------------

local ServiceSection = ServicesTab:AddSection({
	Id = "diag-service-launchers",
	Title = "Interactive service demos",
	Description = "These buttons intentionally open visible surfaces.",
	Icon = "bell",
	Span = 2,
	Layout = "Grid",
})

ServiceSection:AddButton({
	Title = "Notification variants",
	Text = "Show notifications",
	Icon = "bell",
	Callback = function()
		for index, variant in { "Default", "Success", "Warning", "Error" } do
			UI.Notify:Push({
				Title = variant,
				Content = "BobloUI notification variant",
				Variant = variant,
				Duration = 3 + index * 0.2,
			})
		end
	end,
})
ServiceSection:AddButton({
	Title = "Alert dialog",
	Text = "Open alert",
	Callback = function()
		UI.Dialog:Alert({ Title = "Alert", Content = "Close this dialog manually." })
	end,
})
ServiceSection:AddButton({
	Title = "Confirm dialog",
	Text = "Open confirm",
	Callback = function()
		UI.Dialog:Confirm({ Title = "Confirm", Content = "Test both actions." })
	end,
})
ServiceSection:AddButton({
	Title = "Prompt dialog",
	Text = "Open prompt",
	Callback = function()
		UI.Dialog:Prompt({ Title = "Prompt", Content = "Type and submit text.", Default = "BobloUI" })
	end,
})
ServiceSection:AddButton({
	Title = "Choice dialog",
	Text = "Open choice",
	Callback = function()
		UI.Dialog:Choice({
			Title = "Choose a mode",
			Choices = {
				{ Text = "Safe", Value = "safe", Primary = true },
				{ Text = "Fast", Value = "fast" },
				{ Text = "Danger", Value = "danger", Danger = true },
			},
		})
	end,
})
ServiceSection:AddButton({
	Title = "Custom dialog",
	Text = "Open custom",
	Callback = function()
		UI.Dialog:Custom({
			Title = "Custom dialog v2",
			Description = "Dynamic footer actions and every control container contract.",
			OutsideClickDismiss = false,
			AutoDismiss = false,
			FooterButtons = {
				cancel = { Text = "Cancel", Order = 1 },
				continue = { Text = "Continue", Variant = "Primary", WaitTime = 2, Order = 2 },
			},
			Build = function(section)
				section:AddParagraph({ Content = "Controls inside DialogSection" })
				section:AddToggle({ Title = "Temporary toggle", Default = true })
				section:AddSlider({ Title = "Temporary slider", Min = 0, Max = 10, Default = 5 })
			end,
		})
	end,
})
ServiceSection:AddButton({
	Title = "Loading overlay",
	Text = "Run loading demo",
	Callback = function()
		task.spawn(function()
			local loading = UI:ShowLoading({
				Title = "Loading demo",
				Status = "Starting",
				Progress = 0,
				Icon = "rocket",
				Steps = { "Prepare", "Download", "Validate", "Finish" },
				Build = function(section)
					section:AddToggle({ Title = "Create backup", Default = true })
					section:AddStatus({ Title = "Connection", Value = "Ready", Status = "Success" })
				end,
			})
			for step = 1, 4 do
				loading:SetStep(step, 4, "Step " .. tostring(step))
				task.wait(0.35)
			end
			loading:Dismiss()
		end)
	end,
})
ServiceSection:AddButton({
	Title = "Draggable overlays",
	Text = "Create overlays",
	Icon = "panels-top-left",
	Callback = function()
		UI:AddDraggableLabel({ Text = "Drag me", Icon = "move", Position = UDim2.fromOffset(18, 90) })
		UI:AddDraggableButton({
			Text = "Overlay action",
			Icon = "play",
			Position = UDim2.fromOffset(18, 132),
			Callback = function()
				UI.Notify:Push({ Title = "Overlay clicked", Variant = "Success" })
			end,
		})
	end,
})
ServiceSection:AddButton({
	Title = "Search palette",
	Text = "Open Search",
	Callback = function()
		UI:OpenSearch("slider")
	end,
})
ServiceSection:AddButton({
	Title = "Command palette",
	Text = "Open Commands",
	Callback = function()
		UI:OpenCommands()
	end,
})
ServiceSection:AddButton({
	Title = "Settings center",
	Text = "Open Settings",
	Callback = function()
		UI:OpenSettings()
	end,
})

local ManualSection = ManualTab:AddSection({
	Id = "diag-manual-section",
	Title = "Manual checklist",
	Description = "PASS these only after observing the expected behavior.",
	Icon = "shield-check",
	Span = 2,
	Layout = "Stack",
})
ManualSection:AddParagraph({
	Title = "1. Drag and resize",
	Content = "Drag the header, then resize from the footer/corner. Lock the window in Settings and verify both interactions stop.",
	Variant = "Info",
})
ManualSection:AddParagraph({
	Title = "2. Hide and restore",
	Content = "Press RightShift. Verify the draggable Show BobloUI button appears, then restore the window. Repeat after moving that button.",
})
ManualSection:AddParagraph({
	Title = "3. Mouse interactions",
	Content = "Hover the Primary action for its tooltip; right-click or long-press it for the context menu; drag the slider; search inside the dropdown.",
})
ManualSection:AddParagraph({
	Title = "4. Keyboard and gamepad",
	Content = "Use Tab/arrows/Enter, capture a new keybind, and verify Toggle, Hold and Always modes with the Keybind HUD visible.",
})
ManualSection:AddParagraph({
	Title = "5. Phone / touch",
	Content = "Run in a phone emulator/device: open the drawer, dropdown, color picker and dialogs; verify bottom sheets, scrolling, keyboard avoidance and safe-area insets.",
})
ManualSection:AddParagraph({
	Title = "6. Clipboard",
	Content = "Use Copy on the code/report and Copy/Paste value from a control context menu. Some executors support write-only clipboard access.",
})
ManualSection:AddParagraph({
	Title = "7. Visual matrix",
	Content = "Inspect Dark and Light at Compact/Comfortable/Touch density and scales 0.75, 1.0, 1.25 and 1.5. Check every card border, inactive navigation icon, rounded corner and footer resize grip.",
})
ManualSection:AddParagraph({
	Title = "8. Real assets and audio",
	Content = "Replace rbxassetid://0 and the diagnostic sound ID with assets you own, then verify image, video, notification media, background image, sound volume and cleanup.",
})
ManualSection:AddParagraph({
	Title = "9. P1/P2 interaction pass",
	Content = "Drag the sidebar divider and public overlays; orbit/zoom the Viewport; drag-select the multi-dropdown; try modifier and mobile keybind actions; inspect dialog WaitTime and the loading control sidebar.",
})
ManualSection:AddButton({
	Title = "Hide for two seconds",
	Text = "Hide → auto-show",
	Variant = "Primary",
	Callback = function()
		UI:Hide()
		task.delay(2, function()
			if not UI:IsUnloaded() then
				UI:Show()
			end
		end)
	end,
})
ManualSection:AddButton({
	Title = "Show HUD surfaces",
	Text = "Watermark + keybind HUD",
	Callback = function()
		UI:SetWatermark(function()
			return "BobloUI " .. tostring(BobloUI.Version) .. " | " .. tostring(os.date("%H:%M:%S"))
		end)
		UI:SetKeybindHUD(true)
	end,
})
ManualSection:AddButton({
	Title = "Disable HUD surfaces",
	Text = "Hide HUD",
	Callback = function()
		UI:SetWatermark(false)
		UI:SetKeybindHUD(false)
		UI:SetCustomCursor(false)
	end,
})
ManualSection:AddButton({
	Title = "Custom cursor",
	Text = "Enable cursor",
	Callback = function()
		UI:SetCustomCursor(true, { Size = 10, Token = "Accent" })
	end,
})
ManualSection:AddButton({
	Title = "Open mobile drawer",
	Text = "Open drawer",
	Callback = function()
		UI:OpenDrawer()
	end,
})
ManualSection:AddButton({
	Title = "Unload diagnostic",
	Text = "Unload BobloUI",
	Variant = "Danger",
	Confirm = "This destroys the entire diagnostic window. Run the script again to recreate it.",
	Callback = function()
		UI:Unload()
	end,
})

local topbarTag = UI:AddTopbarTag({ Id = "diag-tag", Text = "FULL TEST", Token = "AccentSoft" })
local topbarClicks = 0
local topbarButton = UI:AddTopbarButton({
	Id = "diag-home",
	Icon = "star",
	Callback = function()
		topbarClicks += 1
		OverviewTab:Select()
	end,
})

-- Automatic checks ---------------------------------------------------------

addTest("Bootstrap", "version and API level", function()
	expectEqual(BobloUI.Version, EXPECTED_VERSION, "unexpected published version")
	expect(BobloUI.ApiLevel >= EXPECTED_API_LEVEL, "ApiLevel is below " .. tostring(EXPECTED_API_LEVEL))
end)

addTest("Bootstrap", "public extension and data-source APIs", function()
	expect(type(BobloUI.RegisterControl) == "function", "RegisterControl is missing")
	expect(type(BobloUI.Icon.Register) == "function", "Icon.Register is missing")
	expect(type(BobloUI.Source) == "function", "Source is missing")
	expect(type(BobloUI.Sources.Players) == "function", "Sources.Players is missing")
	local source = BobloUI.Source(function()
		return { "A", "B" }
	end)
	expectEqual(source.Get()[2], "B", "custom source getter failed")
	expect(type(BobloUI.Sources.Players({}).Get()) == "table", "Players source did not return a table")
end)

addTest("Bootstrap", "vendored Lucide registry and GitHub provider", function()
	expectEqual(BobloUI.Icon.Count, 1756, "unexpected Lucide icon count")
	expect(type(BobloUI.Icon.List) == "function", "Icon.List is missing")
	expect(type(BobloUI.Icon.Has) == "function", "Icon.Has is missing")
	expect(type(BobloUI.Icon.Resolve) == "function", "Icon.Resolve is missing")
	expect(type(BobloUI.Icon.SetAtlasUrls) == "function", "Icon.SetAtlasUrls is missing")
	expect(type(BobloUI.Icon.GetAtlasUrls) == "function", "Icon.GetAtlasUrls is missing")
	expect(type(BobloUI.Icon.Prepare) == "function", "Icon.Prepare is missing")
	expect(type(BobloUI.Icon.Retry) == "function", "Icon.Retry is missing")
	expect(type(BobloUI.Icon.GetStatus) == "function", "Icon.GetStatus is missing")
	expect(BobloUI.Icon.Has("sword"), "Lucide sword icon is missing")
	expect(BobloUI.Icon.Has("settings_2"), "normalized settings-2 icon is missing")
	expect(BobloUI.Icon.Has("dashboard"), "dashboard alias is missing")
	expect(not BobloUI.Icon.Has("definitely-not-a-real-icon"), "unknown icon reported as available")

	local names = BobloUI.Icon.List()
	expectEqual(#names, 1756, "Icon.List count")
	names[1] = "mutated-copy"
	expect(BobloUI.Icon.List()[1] ~= "mutated-copy", "Icon.List exposed its internal table")

	local urls = BobloUI.Icon.GetAtlasUrls()
	expectEqual(#urls, 2, "GitHub atlas URL count")
	expect(
		contains(urls[1], "raw.githubusercontent.com/bobloscript/BobloUI/main/dist/assets/bobloui/lucide-1.png"),
		"first GitHub atlas URL is invalid"
	)
	expect(
		contains(urls[2], "raw.githubusercontent.com/bobloscript/BobloUI/main/dist/assets/bobloui/lucide-2.png"),
		"second GitHub atlas URL is invalid"
	)
	urls[1] = "mutated-copy"
	expect(BobloUI.Icon.GetAtlasUrls()[1] ~= "mutated-copy", "GetAtlasUrls exposed its internal table")

	local status = BobloUI.Icon.GetStatus()
	expect(
		status.State == "Ready" or status.State == "Fallback",
		"unexpected icon provider state: " .. tostring(status.State)
	)
	expectEqual(status.Ready, status.State == "Ready", "icon provider Ready flag")
	expect(type(status.Urls) == "table" and #status.Urls == 2, "icon provider status omitted URLs")

	if status.State == "Fallback" then
		local renderedFallback
		for _, instance in UI:GetInstance():GetDescendants() do
			if instance:GetAttribute("BobloIconSource") == "Fallback" then
				renderedFallback = instance
				break
			end
		end
		expect(renderedFallback and renderedFallback:IsA("GuiObject"), "asset-free fallback did not render")
	end
end)

addTest("Bootstrap", "GitHub atlas custom-asset rendering", function()
	local status = BobloUI.Icon.GetStatus()
	if not status.Ready then
		skip("executor-local Lucide atlas unavailable: " .. tostring(status.Error))
	end

	local asset = BobloUI.Icon.Resolve("crosshair")
	expect(type(asset) == "table", "Icon.Resolve did not return an asset")
	expect(type(asset.Url) == "string" and asset.Url ~= "", "resolved custom asset URL is invalid")
	expect(not contains(asset.Url, "rbxassetid://"), "resolved atlas unexpectedly uses a Roblox asset ID")
	expect(typeof(asset.ImageRectOffset) == "Vector2", "resolved ImageRectOffset is invalid")
	expect(typeof(asset.ImageRectSize) == "Vector2", "resolved ImageRectSize is invalid")
	expect(asset.ImageRectSize.X > 0 and asset.ImageRectSize.Y > 0, "resolved sprite rectangle is empty")

	local rendered
	for _, instance in UI:GetInstance():GetDescendants() do
		if instance:GetAttribute("BobloIconSource") == "Lucide" then
			rendered = instance
			break
		end
	end
	expect(rendered and rendered:IsA("ImageLabel"), "no Lucide ImageLabel was rendered")
end)

addTest("Bootstrap", "window registry and root instance", function()
	expect(BobloUI:GetWindow(windowId) == UI, "GetWindow did not return this window")
	expect(table.find(BobloUI:ListWindows(), windowId) ~= nil, "ListWindows omitted this window")
	expect(typeof(UI:GetInstance()) == "Instance", "GetInstance did not return an Instance")
	expect(UI:Get("DiagToggle") == Toggle, "Window:Get registry lookup failed")
	expect(UI:GetTab("diag-controls") == ControlsTab, "Window:GetTab lookup failed")
end)

addTest("Bootstrap", "topbar tag and button lifecycle", function()
	expect(topbarTag.Instance.Parent ~= nil and topbarButton.Instance.Parent ~= nil, "topbar items were not mounted")
	topbarTag:SetText("TESTING"):SetVisible(false):SetVisible(true)
	topbarButton:SetText("Home"):SetVisible(false):SetVisible(true)
	expect(topbarTag.Instance.Visible and topbarButton.Instance.Visible, "topbar visibility methods failed")
	local disposable = UI:AddTopbarTag("TEMP")
	disposable:Destroy()
	expect(disposable.Instance.Parent == nil, "topbar Destroy failed")
end)

addTest("Controls", "Button and registered custom control", function()
	local beforeAction = actionClicks
	ActionButton:Click()
	expectEqual(actionClicks, beforeAction + 1, "Button:Click callback count")
	local beforeCustom = customClicks
	CustomControl:Click()
	expectEqual(customClicks, beforeCustom + 1, "custom control callback count")
	expect(DisabledButton:IsDisabled(), "disabled reason did not disable the button")
	DisabledButton:Click()
	expectEqual(disabledClicks, 0, "disabled button ran its callback")
	DoubleClickButton:Click()
	expectEqual(doubleClicks, 0, "double-click action fired on first click")
	DoubleClickButton:Click()
	expectEqual(doubleClicks, 1, "double-click action did not fire on second click")
	local actionCount = #DoubleClickButton.SubButtons
	DoubleClickButton:AddAction({ Text = "Extra", Callback = function() end })
	expectEqual(#DoubleClickButton.SubButtons, actionCount + 1, "Button:AddAction")
end)

addTest("Controls", "duplicate Id rejected before construction", function()
	local registryCount = #UI.Registry:Entries()
	local sectionCount = #CoreSection._controls
	local ok, err = pcall(function()
		CoreSection:AddToggle({ Id = "DiagToggle", Title = "Duplicate", Default = true })
	end)
	expect(not ok, "duplicate Id was accepted")
	expect(contains(err, "duplicate Id"), "duplicate error is not descriptive: " .. tostring(err))
	expectEqual(#UI.Registry:Entries(), registryCount, "duplicate changed registry size")
	expectEqual(#CoreSection._controls, sectionCount, "duplicate constructed a partial control")
end)

addTest("Controls", "Toggle owner suppression and callback once", function()
	Toggle:SetValue(false, true)
	toggleCallbacks = 0
	Toggle:SetValue(true)
	expectEqual(Toggle:GetValue(), true, "Toggle:SetValue failed")
	expectEqual(toggleCallbacks, 1, "control callback must run exactly once")
	Toggle:Flip()
	expectEqual(Toggle:GetValue(), false, "Toggle:Flip failed")
	expectEqual(toggleCallbacks, 2, "Toggle:Flip callback count")
	expectEqual(Checkbox:GetValue(), true, "checkbox default failed")
end)

addTest("Controls", "reactive VisibleWhen and EnabledWhen", function()
	Toggle:SetValue(false, true)
	expect(not Slider:IsVisible(), "VisibleWhen false branch failed")
	expect(DependencyButton:IsDisabled(), "EnabledWhen false branch failed")
	Toggle:SetValue(true, true)
	expect(Slider:IsVisible(), "VisibleWhen true branch failed")
	expect(not DependencyButton:IsDisabled(), "EnabledWhen true branch failed")
end)

addTest("Controls", "Slider normalization and range methods", function()
	Slider:SetValue(63)
	expectEqual(Slider:GetValue(), 65, "slider step normalization")
	Slider:SetMin(10):SetMax(80):SetStep(10):SetValue(73)
	expectEqual(Slider:GetValue(), 70, "slider runtime range/step methods")
	Slider:SetMin(0):SetMax(100):SetStep(5):Reset(true)
	expectEqual(Slider:GetValue(), 25, "slider reset")
	expect(Slider._bubble and Slider._bubble:FindFirstChildOfClass("UIStroke"), "floating value bubble border")
end)

addTest("Controls", "Input methods and numeric/multiline values", function()
	Input:SetValue("Changed")
	expectEqual(Input:GetValue(), "Changed", "text input set")
	Input:SetError("Diagnostic error"):SetError(nil)
	Input:Focus():Blur()
	Input:Clear()
	expectEqual(Input:GetValue(), "", "Input:Clear text")
	NumericInput:SetValue(42):Clear()
	expectEqual(NumericInput:GetValue(), 0, "Input:Clear numeric")
	MultilineInput:SetValue("A\nB")
	expectEqual(MultilineInput:GetValue(), "A\nB", "multiline value")
end)

addTest("Controls", "P3 Input and Slider compatibility options", function()
	ControlsTab:Select()
	task.wait()
	P3Input._box.Text = ""
	P3Input:_commit()
	expectEqual(P3Input:GetValue(), "Reset value", "Input EmptyReset")
	P3Input:SetAllowEmpty(true)
	P3Input._box.Text = ""
	P3Input:_commit()
	expectEqual(P3Input:GetValue(), "", "Input AllowEmpty")
	P3Input:SetAllowEmpty(false, "Reset value")
	expectEqual(P3Input:GetValue(), "Reset value", "Input SetAllowEmpty reset")
	expect(P3Input.ClearTextOnBlur == true, "Input ClearTextOnBlur option")
	expectEqual(P3Slider:_format(5), "~5 / 10x", "Slider Prefix/HideMax/Suffix")
	expect(P3Slider.Compact and P3Slider.AllowRightClickInput, "Slider compact/right-click options")
	P3Slider:SetPrefix("$"):SetSuffix(" total")
	expectEqual(P3Slider:_format(5), "$5 / 10 total", "Slider:SetPrefix/SetSuffix")
	P3Slider:SetPrefix("~"):SetSuffix("x")
end)

addTest("Controls", "Dropdown methods and selection modes", function()
	ControlsTab:Select()
	task.wait()
	Dropdown:Open():Close()
	Dropdown:SetOptions({ "One", "Two" }):AddOption("Three")
	Dropdown:SetValue("Three")
	expectEqual(Dropdown:GetValue(), "Three", "Dropdown:AddOption/SetValue")
	Dropdown:RemoveOption("Three")
	expect(Dropdown:GetValue() ~= "Three", "Dropdown:RemoveOption kept removed value")
	Dropdown:Refresh({ "safe", "fast" }):SetValue("safe")
	expectEqual(Dropdown:GetValue(), "safe", "Dropdown:Refresh")
	Dropdown:SetValues({ stable_a = "Stable A", stable_b = "Stable B" }):SetValue("stable_b")
	expectEqual(Dropdown:_labelFor("stable_b"), "Stable B", "Dropdown dictionary Values")
	Dropdown:AddValues({ stable_c = "Stable C" }):SetValue("stable_c")
	expectEqual(Dropdown:GetValue(), "stable_c", "Dropdown:AddValues dictionary")
	MultiDropdown:SetValue({ "Beta", "Gamma" })
	expectEqual(#MultiDropdown:GetValue(), 2, "multi-select value")
	MultiDropdown:SetDragSelect(true)
	MultiDropdown:SetMaxVisibleRows(2)
	MultiDropdown:SetDisabledValues({ "Delta" })
	expect(MultiDropdown._options[4].Locked == true, "Dropdown:SetDisabledValues")
	MultiDropdown:AddDisabledValues({ "Gamma" })
	expect(MultiDropdown._options[3].Locked == true, "Dropdown:AddDisabledValues")
	MultiDropdown:SetValueDisabled("Delta", false)
	expect(MultiDropdown._options[4].Locked == false, "Dropdown:SetValueDisabled")
	MultiDropdown:SetValueImages({ Beta = "rbxassetid://0" }):AddValueImages({ Gamma = "rbxassetid://0" })
	MultiDropdown:SetValueImage("Beta", "rbxassetid://1")
	expectEqual(MultiDropdown.ValueImages.Beta, "rbxassetid://1", "Dropdown:SetValueImage")
	expectEqual(MultiDropdown:GetActiveValues(true), 2, "Dropdown:GetActiveValues count")
	expectEqual(#MultiDropdown:GetActiveValues(), 2, "Dropdown:GetActiveValues values")
	MultiDropdown:SetFormatters(function(value)
		return "Selected " .. tostring(value)
	end, function(value)
		return "Option " .. tostring(value)
	end)
	expect(contains(MultiDropdown:_display({ "Beta" }), "Selected Beta"), "Dropdown display formatter")
	expectEqual(MapDropdown.MultiValueMode, "Map", "dictionary MultiValueMode inference")
	expect(MapDropdown:GetValue().alpha == true, "dictionary default map")
	MapDropdown:SetValue({ beta = true, gamma = true })
	expectEqual(MapDropdown:GetActiveValues(true), 2, "dictionary map count")
	MapDropdown:SetValue({ "alpha", "gamma" })
	expect(MapDropdown:GetValue().alpha and MapDropdown:GetValue().gamma, "array-to-map compatibility")
	SegmentedDropdown:SetValue("High")
	expectEqual(SegmentedDropdown:GetValue(), "High", "segmented dropdown")
end)

addTest("Controls", "reactive and Players dropdown sources", function()
	sourceValues = { "Two", "Three" }
	sourceSignal:Fire()
	expect(
		waitFor(function()
			SourceDropdown:SetValue("Three")
			return SourceDropdown:GetValue() == "Three"
		end, 1),
		"reactive source did not refresh"
	)
	PlayersDropdown:RefreshSource(true)
	expect(type(PlayersDropdown._options) == "table", "Players source refresh failed")
end)

addTest("Controls", "Keybind modes and capture cancellation", function()
	ControlsTab:Select()
	task.wait()
	Keybind:SetKey(Enum.KeyCode.G, { "Ctrl" })
	expectEqual(Keybind:GetValue().Key, "G", "Keybind:SetKey")
	expectEqual(Keybind:GetModifiers()[1], "Ctrl", "Keybind modifier chord")
	expect(Keybind:SetModifiers({ "Alt" }) == false, "modifier blacklist was ignored")
	expect(Keybind:SetModifiers({ "Shift" }) ~= false, "modifier whitelist rejected Shift")
	Keybind:SetModifiers({ "Ctrl" })
	Keybind:SetMode("Hold")
	expectEqual(Keybind:GetValue().Mode, "Hold", "Keybind:SetMode")
	Keybind:Capture()
	expect(Keybind._capturing == true, "Keybind:Capture did not enter capture mode")
	Keybind:Cancel()
	expect(Keybind._capturing == false, "Keybind:Cancel failed")
	Keybind:Focus():Cancel()
	Keybind:SetMode("Always")
	expect(type(Keybind:IsActive()) == "boolean", "Keybind:IsActive did not return boolean")
	Keybind:SetMode("Pulse")
	Keybind:Trigger()
	expect(Keybind:IsActive(), "custom keybind mode did not trigger")
	Keybind:SetMode("Toggle")
	Toggle:SetValue(false, true)
	AttachedKeybind:Trigger()
	expectEqual(Toggle:GetValue(), true, "attached keybind did not toggle owner")
end)

addTest("Controls", "ColorPicker, Status and Progress methods", function()
	ControlsTab:Select()
	task.wait()
	ColorPicker:Open():Close():SetAlpha(0.25)
	expect(closeEnough(ColorPicker:GetAlpha(), 0.25), "ColorPicker alpha")
	ColorPicker:SetValue(Color3.fromHex("FF5EA8"))
	expectEqual(string.lower(ColorPicker:GetValue():ToHex()), "ff5ea8", "ColorPicker value")
	Status:SetValue("Warning state"):SetStatus("Warning")
	expectEqual(Status.Status, "Warning", "Status:SetStatus")
	Progress:SetValue(70):SetIndeterminate(true):SetIndeterminate(false)
	expectEqual(Progress:GetValue(), 70, "Progress value")
	expect(Progress.Indeterminate == false, "Progress:SetIndeterminate")
end)

addTest("Controls", "Paragraph, Divider, Code and Image methods", function()
	Paragraph:SetContent("Paragraph method passed")
	expectEqual(Paragraph.Content, "Paragraph method passed", "Paragraph:SetContent")
	Divider:SetTitle("Updated divider")
	expectEqual(Divider.Title, "Updated divider", "Divider:SetTitle")
	P3Paragraph:SetRichText(false):SetWrap(false):SetSize(16)
	expect(not P3Paragraph.RichText and not P3Paragraph.DoesWrap and P3Paragraph.TextSize == 16, "Paragraph P3 methods")
	P3Divider:SetMargins(4, 8)
	expectEqual(P3Divider.MarginTop, 4, "Divider MarginTop")
	expectEqual(P3Divider.MarginBottom, 8, "Divider MarginBottom")
	Code:SetCode("return 'updated'")
	expectEqual(Code:GetCode(), "return 'updated'", "Code:SetCode/GetCode")
	expectEqual(Code:CopyCode(), "return 'updated'", "Code:CopyCode")
	expect(Code._copy and Code._copy:FindFirstChildOfClass("UIStroke"), "Code copy button border")
	Image:SetImage("rbxassetid://0")
		:SetCaption("Updated caption")
		:SetHeight(96)
		:SetTint(Color3.fromHex("FFFFFF"))
		:SetTransparency(0.1, 0.3)
		:SetRect(Vector2.new(0, 0), Vector2.new(0, 0))
		:SetScaleType(Enum.ScaleType.Fit)
	expectEqual(Image.Caption, "Updated caption", "Image:SetCaption")
end)

addTest("Controls", "Passthrough, Viewport and Video media controls", function()
	expect(Passthrough:GetContentInstance() ~= PassthroughSource, "Passthrough Clone=true reused source")
	Passthrough:SetHeight(52)
	expectEqual(Passthrough.Height, 52, "Passthrough:SetHeight")
	Viewport:SetInteractive(false):SetInteractive(true):SetHeight(132):Focus()
	expectEqual(Viewport.Height, 132, "Viewport:SetHeight")
	local replacement = ViewportPart:Clone()
	replacement.Size = Vector3.new(2, 2, 2)
	Viewport:SetObject(replacement, true):Focus()
	Video:SetLooped(true):SetVolume(0):SetHeight(110):Play():Pause()
	expect(Video.Looped and not Video.Playing and Video.Height == 110, "Video playback methods")
	replacement:Destroy()
end)

addTest("Controls", "common Base methods and registry reindex hooks", function()
	Toggle:SetTitle("Diagnostic Toggle Indexed")
	Toggle:SetDescription("Updated searchable description")
	Toggle:SetKeywords({ "needle-keyword", "toggle" })
	Toggle:SetIcon("diagnostic-dot", "Accent")
	Toggle:SetBadge("NEW", "Success")
	Toggle:SetVisible(false)
	expect(not Toggle:IsVisible(), "Base:SetVisible(false)")
	Toggle:SetVisible(true)
	Toggle:SetDisabled(true, "temporary")
	expect(Toggle:IsDisabled(), "Base:SetDisabled(true)")
	Toggle:SetDisabled(false):SetLoading(true):SetLoading(false)
	expect(not Toggle:IsDisabled(), "Base:SetDisabled(false)")
	expect(type(Toggle:CopyValue()) == "string", "Base:CopyValue")
	expect(typeof(Toggle:GetInstance()) == "Instance", "Base:GetInstance")
	Toggle:Highlight(0.05):Reveal()
end)

addTest("Controls", "Changed connection, Reset and optional PasteValue", function()
	local calls = 0
	local connection = Toggle:OnChanged(function()
		calls += 1
	end)
	Toggle:SetValue(false, true)
	Toggle:SetValue(true)
	expectEqual(calls, 1, "Base:OnChanged")
	connection:Disconnect()
	Toggle:Reset(true)
	expectEqual(Toggle:GetValue(), false, "Base:Reset")
	local ok, err = Toggle:PasteValue()
	if not ok then
		skip("clipboard read/write is unavailable or rejected: " .. tostring(err))
	end
	expect(ok, "PasteValue failed: " .. tostring(err))
end)

addTest("Store", "FIFO nested writes", function()
	local state = UI.State
	local a = statePrefix .. "fifoA"
	local b = statePrefix .. "fifoB"
	state:SetDefault(a, 0)
	state:SetDefault(b, 0)
	local order = {}
	local stopA = state:Watch(a, function(value)
		table.insert(order, "A" .. tostring(value))
		if value == 1 then
			state:Set(b, 1)
		end
		table.insert(order, "A-done")
	end)
	local stopB = state:Watch(b, function(value)
		table.insert(order, "B" .. tostring(value))
	end)
	state:Set(a, 1)
	stopA()
	stopB()
	expectEqual(table.concat(order, ","), "A1,A-done,B1", "nested dispatch order")
end)

addTest("Store", "WatchMany fires once with settled snapshot", function()
	local state = UI.State
	local a = statePrefix .. "manyA"
	local b = statePrefix .. "manyB"
	state:SetDefault(a, 0)
	state:SetDefault(b, 0)
	local stopCascade = state:Watch(a, function(value)
		state:Set(b, value + 1)
	end)
	local calls = 0
	local settled
	local stopMany = state:WatchMany({ a, b }, function(snapshot)
		calls += 1
		settled = snapshot
	end)
	state:Set(a, 5)
	stopCascade()
	stopMany()
	expectEqual(calls, 1, "WatchMany call count")
	expectEqual(settled[a], 5, "settled A")
	expectEqual(settled[b], 6, "settled B")
end)

addTest("Store", "origin suppresses owner watcher", function()
	local state = UI.State
	local id = statePrefix .. "owner"
	local owner = {}
	local ownCalls = 0
	local otherCalls = 0
	state:SetDefault(id, 0)
	local ownStop = state:Watch(id, function()
		ownCalls += 1
	end, owner)
	local otherStop = state:Watch(id, function()
		otherCalls += 1
	end)
	state:Set(id, 1, { Source = owner })
	ownStop()
	otherStop()
	expectEqual(ownCalls, 0, "owner watcher was not suppressed")
	expectEqual(otherCalls, 1, "non-owner watcher did not run")
end)

addTest("Store", "Store-level Track sees direct aliases", function()
	local state = UI.State
	local a = statePrefix .. "trackA"
	local b = statePrefix .. "trackB"
	state:SetDefault(a, true)
	state:SetDefault(b, "Advanced")
	local alias = state
	local ids, result = state:Track(function(store)
		return store:Get(a) and alias:Get(b) == "Advanced"
	end)
	expect(result == true, "Track predicate result")
	expectEqual(table.concat(ids, ","), a .. "," .. b, "tracked dependency order")
end)

addTest("Store", "Batch, Update, Snapshot, Has and Reset", function()
	local state = UI.State
	local a = statePrefix .. "batchA"
	local b = statePrefix .. "batchB"
	state:SetDefault(a, 1)
	state:SetDefault(b, 2)
	state:Batch(function()
		state:Update(a, function(value)
			return value + 4
		end)
		state:Set(b, 9)
	end)
	local snapshot = state:Snapshot()
	expect(state:Has(a) and state:Has(b), "Store:Has")
	expectEqual(snapshot[a], 5, "Store:Update/Snapshot A")
	expectEqual(snapshot[b], 9, "Store:Batch/Snapshot B")
	state:Reset(a)
	expectEqual(state:Get(a), 1, "Store:Reset")
end)

addTest("Store", "in-place table mutation and cycle-safe equality", function()
	local state = UI.State
	local tableId = statePrefix .. "table"
	state:SetDefault(tableId, { "a" })
	local value = state:Get(tableId)
	table.insert(value, "b")
	expect(state:Set(tableId, value) == true, "in-place table mutation was short-circuited")

	local cycleId = statePrefix .. "cycle"
	local cycle = {}
	cycle.self = cycle
	state:SetDefault(cycleId, cycle)
	local stored = state:Get(cycleId)
	stored.changed = true
	expect(state:Set(cycleId, stored) == true, "cycle-safe equality did not detect the mutation")
end)

addTest("Store", "cascade guard propagates key chain", function()
	local state = UI.State
	local a = statePrefix .. "cascadeA"
	local b = statePrefix .. "cascadeB"
	state:SetDefault(a, 0)
	state:SetDefault(b, 0)
	local stopA = state:Watch(a, function(value)
		state:Set(b, value + 1)
	end)
	local stopB = state:Watch(b, function(value)
		state:Set(a, value + 1)
	end)
	local ok, err = pcall(function()
		state:Set(a, 1)
	end)
	stopA()
	stopB()
	expect(not ok, "recursive cascade was accepted")
	expect(contains(err, "State cascade exceeded 64 updates"), "cascade limit is missing from error")
	expect(contains(err, a .. " -> " .. b .. " -> " .. a), "cascade key chain is missing from error")
end)

addTest("Store", "zero-dependency warning path remains usable", function()
	local disposable = CoreSection:AddButton({
		Title = "Zero dependency warning probe",
		VisibleWhen = function()
			return true
		end,
		Callback = function() end,
	})
	disposable:Destroy()
	skip("verify one 'dependency tracked 0 State:Get calls' warning in the console")
end)

addTest("Search", "index updates and explicit Reindex", function()
	local indexed = UI.Search:Query("needle-keyword")
	expect(#indexed > 0 and indexed[1].Handle == Toggle, "keyword was not indexed")
	Toggle:SetTitle("Reindexed Control Title")
	local updated = UI.Search:Query("reindexed control")
	expect(#updated > 0 and updated[1].Handle == Toggle, "registry update did not update the index")
	UI.Search:Reindex()
	local rebuilt = UI.Search:Query("updated searchable")
	expect(#rebuilt > 0 and rebuilt[1].Handle == Toggle, "Search:Reindex failed")
	expect(UI.Search:Reveal("DiagToggle"), "Search:Reveal failed")
end)

addTest("Search", "debounce cancels stale query", function()
	local calls = 0
	local finalResults
	UI.Search:QueryDebounced("does-not-exist", function(value)
		calls += 1
		finalResults = value
	end, 0.04)
	UI.Search:QueryDebounced("reindexed", function(value)
		calls += 1
		finalResults = value
	end, 0.04)
	expect(
		waitFor(function()
			return finalResults ~= nil
		end, 1),
		"debounced callback timed out"
	)
	expectEqual(calls, 1, "stale debounce callback was not cancelled")
	expect(#finalResults > 0 and finalResults[1].Handle == Toggle, "debounced result is wrong")
	UI.Search:CancelPending()
end)

addTest("Favorites", "Add, Remove, Toggle, Set and List", function()
	UI.Favorites:Set({ "DiagToggle" })
	expect(UI.Favorites:Has("DiagToggle"), "Favorites:Set/Has")
	expect(table.find(UI.Favorites:List(), "DiagToggle") ~= nil, "Favorites:List")
	UI.Favorites:Toggle("DiagSlider")
	expect(UI.Favorites:Has("DiagSlider"), "Favorites:Toggle add")
	UI.Favorites:Remove("DiagToggle")
	expect(not UI.Favorites:Has("DiagToggle"), "Favorites:Remove")
	UI.Favorites:Add("DiagToggle")
end)

addTest("Commands", "register, list, query, run and unregister", function()
	local ran = 0
	UI.Commands:Register({
		Id = "diag.command",
		Title = "Diagnostic Command",
		Keywords = { "needle-command" },
		Callback = function()
			ran += 1
		end,
	})
	expect(#UI.Commands:Query("needle-command") == 1, "Commands:Query")
	expect(table.find(UI.Commands:List(), UI.Commands:Query("needle-command")[1].Command) ~= nil, "Commands:List")
	expect(UI.Commands:Run("diag.command"), "Commands:Run returned false")
	expectEqual(ran, 1, "command callback count")
	UI.Commands:Unregister("diag.command")
	expect(not UI.Commands:Run("diag.command"), "Commands:Unregister")
end)

addTest("Layout", "Tab methods, locking and selection", function()
	expect(LockedTab:IsLocked(), "locked constructor option")
	LockedTab:SetVisible(true)
	LockedTab:SetLocked(false)
	expect(not LockedTab:IsLocked(), "Tab:SetLocked(false)")
	LockedTab:SetTitle("Unlocked tab")
	LockedTab:SetDescription("Runtime description")
	LockedTab:SetIcon("diagnostic-dot")
	LockedTab:SetBadge("OK")
	LockedTab:SetGroup("DIAGNOSTIC")
	LockedTab:SetVisible(false):SetVisible(true):Select()
	expect(LockedTab:IsSelected(), "Tab:Select/IsSelected")
	expect(typeof(LockedTab:GetInstance()) == "Instance", "Tab:GetInstance")
	OverviewTab:Select()
	LockedTab:SetVisible(false)
end)

addTest("Layout", "Section methods and reset", function()
	LayoutTab:Select()
	task.wait()
	StackSection:SetTitle("Stack section updated")
	StackSection:SetSpan(2):SetLayout("Auto"):SetIcon("layout")
	expectEqual(StackSection.Span, 2, "Section:SetSpan")
	expectEqual(StackSection.Layout, "Auto", "Section:SetLayout")
	expectEqual(StackSection.Icon, "layout", "Section:SetIcon")
	StackSection:SetCollapsed(true):SetCollapsed(false)
	StackSection:SetVisible(false):SetVisible(true)
	LayoutToggle:SetValue(true)
	StackSection:Reset()
	expectEqual(LayoutToggle:GetValue(), false, "Section:Reset")
	expect(typeof(StackSection:GetInstance()) == "Instance", "Section:GetInstance")
	StackSection:SetSpan(1):SetLayout("Stack"):SetIcon("list")
end)

addTest("Layout", "Row and TabBox primitives", function()
	local before = RowButtonClicks
	RowButton:Click()
	expectEqual(RowButtonClicks, before + 1, "Row child button")
	RowToggle:SetValue(false)
	Row:Reset()
	expectEqual(RowToggle:GetValue(), true, "Row:Reset")
	RowStatus:SetStatus("Info")
	TabBox:Select("b")
	TabBoxSlider:SetValue(15)
	TabBoxToggle:SetValue(false)
	TabBox:Reset()
	expectEqual(TabBoxSlider:GetValue(), 10, "TabBox slider reset")
	expectEqual(TabBoxToggle:GetValue(), true, "TabBox toggle reset")
end)

addTest("Layout", "reactive Section, Row and TabBox containers", function()
	LayoutToggle:SetValue(false, true)
	Toggle:SetValue(false, true)
	expect(not ReactiveSection:IsVisible(), "reactive Section VisibleWhen false branch")
	expect(not ReactiveSection:IsEnabled(), "reactive Section EnabledWhen false branch")
	expect(ReactiveSectionToggle:IsDisabled(), "Section did not disable child control")
	LayoutToggle:SetValue(true, true)
	Toggle:SetValue(true, true)
	expect(ReactiveSection:IsVisible() and ReactiveSection:IsEnabled(), "reactive Section true branch")
	expect(not ReactiveSectionToggle:IsDisabled(), "Section child remained disabled")
	expect(ReactiveRow:IsEnabled() and not ReactiveRowButton:IsDisabled(), "reactive Row did not settle")
	expect(ReactiveTabBox:IsVisible() and not ReactiveTabToggle:IsDisabled(), "reactive TabBox did not settle")
end)

addTest("Layout", "declarative Build and atomic validation", function()
	local handles = UI:Build({
		Tabs = {
			{
				Id = "diag-declarative",
				Title = "Declarative",
				Icon = "code",
				Group = "DIAGNOSTIC",
				Sections = {
					{
						Id = "diag-declarative-section",
						Title = "Descriptor",
						Icon = "package",
						Span = 2,
						Layout = "Auto",
						Controls = {
							{
								Type = "Toggle",
								Id = "DiagDeclarativeToggle",
								Title = "Declarative toggle",
								Default = true,
							},
							{
								Type = "Dropdown",
								Id = "DiagDeclarativeMode",
								Title = "Declarative mode",
								Options = { "A", "B", "C" },
								Default = "B",
								Style = "Segmented",
							},
						},
					},
				},
			},
		},
	})
	expect(handles.DiagDeclarativeToggle ~= nil, "Build handles")
	expectEqual(handles["diag-declarative-section"].Icon, "package", "Build section icon")
	expectEqual(UI:Get("DiagDeclarativeMode"):GetValue(), "B", "Build control value")
	local badOk = pcall(function()
		UI:Build({
			Tabs = {
				{
					Id = "diag-invalid-schema",
					Title = "Invalid",
					Sections = {
						{ Title = "Bad", Span = 3, Controls = { { Type = "Slider", Title = "Oops", Min = 0 } } },
					},
				},
			},
		})
	end)
	expect(not badOk, "invalid schema was accepted")
	expect(UI:GetTab("diag-invalid-schema") == nil, "invalid schema created a partial tab")
end)

addTest("Theme", "presets, accent, tokens, contrast and custom theme", function()
	local original = UI.Theme:Export()
	local presets = UI.Theme:List()
	expectEqual(#presets, 2, "built-in preset count")
	expect(table.find(presets, "Dark") ~= nil and table.find(presets, "Light") ~= nil, "Dark/Light presets")
	for _, name in { "Dark", "Light" } do
		UI:SetTheme(name)
		expectEqual(UI.Theme:Current(), name, "theme preset " .. name)
		local pairsToCheck = {
			{ "Accent", "TextOnAccent" },
			{ "AccentButton", "TextOnAccentButton" },
			{ "AccentButtonHover", "TextOnAccentButton" },
			{ "AccentButtonPressed", "TextOnAccentButton" },
			{ "Success", "TextOnSuccess" },
			{ "Warning", "TextOnWarning" },
			{ "Error", "TextOnError" },
			{ "ErrorHover", "TextOnError" },
			{ "ErrorPressed", "TextOnError" },
			{ "Info", "TextOnInfo" },
		}
		for _, pair in pairsToCheck do
			local ratio = contrastRatio(UI.Theme:Get(pair[1]), UI.Theme:Get(pair[2]))
			expect(ratio >= 4.5, name .. " " .. pair[1] .. " contrast below 4.5:1")
		end
	end
	UI:SetAccent(Color3.fromHex("FF5EA8"))
	expectEqual(string.lower(UI.Theme:Get("Accent"):ToHex()), "ff5ea8", "SetAccent")
	UI:SetThemeToken("Surface", Color3.fromHex("15111A"))
	expectEqual(string.lower(UI.Theme:Get("Surface"):ToHex()), "15111a", "SetThemeToken")
	expect(UI.Theme:GetOverrides().Surface ~= nil, "Theme:GetOverrides")
	UI.Theme:ResetToken("Surface")
	UI:SetThemeToken("ScrimTransparency", 0.37)
	expect(closeEnough(UI.Theme:Get("ScrimTransparency"), 0.37), "numeric theme token")
	UI.Theme:ResetToken("ScrimTransparency")
	UI:SetHighContrast(true)
	expect(UI.Theme:IsHighContrast(), "SetHighContrast")
	local palette = UI.Theme:Palette()
	palette.Accent = Color3.fromHex("43D17A")
	local customName = "DiagnosticTheme-" .. guid
	UI:RegisterTheme(customName, palette):SetTheme(customName)
	expectEqual(UI.Theme:Current(), customName, "RegisterTheme")
	expect(table.find(UI.Theme:List(), customName) ~= nil, "Theme:List")
	UI.Theme:Import(original)
	UI.Theme:ResetOverrides()
	UI:SetHighContrast(false)
	UI:SetTheme("Dark")
end)

addTest("Theme", "JSON export/import", function()
	UI:SetTheme("Light")
	UI:SetAccent(Color3.fromHex("43D17A"))
	UI:SetThemeToken("ScrimTransparency", 0.41)
	local exported = UI:ExportTheme(false)
	expect(type(exported) == "string" and contains(exported, "Light") and contains(exported, "0.41"), "ExportTheme")
	UI:SetTheme("Dark")
	local ok, err = UI:ImportTheme(exported)
	expect(ok, "ImportTheme failed: " .. tostring(err))
	expectEqual(UI.Theme:Current(), "Light", "ImportTheme preset")
	expect(closeEnough(UI.Theme:Get("ScrimTransparency"), 0.41), "ImportTheme numeric token")
	UI.Theme:ResetOverrides()
	UI:SetTheme("Dark")
end)

addTest("Theme", "persisted custom library and default theme", function()
	local name = "DiagnosticPersisted-" .. string.gsub(guid, "%-", "")
	table.insert(themeArtifacts, name)
	local palette = UI.Theme:Palette()
	palette.Accent = Color3.fromHex("4FD1C5")
	local saveOk, saveErr = UI:SaveCustomTheme(name, palette)
	expect(saveOk, "SaveCustomTheme failed: " .. tostring(saveErr))
	expect(table.find(UI:ListCustomThemes(), name) ~= nil, "ListCustomThemes")
	expect(UI.ThemeManager:GetCustomTheme(name) ~= nil, "ThemeManager:GetCustomTheme")
	local defaultOk, defaultErr = UI:SetDefaultTheme(name)
	expect(defaultOk, "SetDefaultTheme failed: " .. tostring(defaultErr))
	expectEqual(UI:GetDefaultTheme(), name, "GetDefaultTheme")
	UI:SetTheme("Dark")
	expect(UI.ThemeManager:SaveDefault(name), "ThemeManager:SaveDefault")
	local defaultLoadOk, defaultLoadErr = UI:LoadDefaultTheme()
	expect(defaultLoadOk, "LoadDefaultTheme failed: " .. tostring(defaultLoadErr))
	local loadOk, loadErr = UI.ThemeManager:ApplyTheme(name)
	expect(loadOk, "LoadCustomTheme failed: " .. tostring(loadErr))
	expectEqual(UI.Theme:Current(), name, "custom theme was not activated")
	expect(table.find(UI:ReloadCustomThemes(), name) ~= nil, "ReloadCustomThemes")
	local deleteOk, deleteErr = UI:DeleteCustomTheme(name)
	expect(deleteOk, "DeleteCustomTheme failed: " .. tostring(deleteErr))
	expect(UI:GetDefaultTheme() == nil, "deleting default custom theme did not clear default")
	expectEqual(UI.Theme:Current(), "Dark", "deleting active custom theme did not restore Dark")
end)

addTest("Locale", "register, add, switch, resolve and list", function()
	UI.Locale:Register("diag", { ["diag.hello"] = "Hello {name}" })
	UI.Locale:Add("diag", { ["diag.added"] = "Added" })
	UI:SetLocale("diag")
	expectEqual(UI.Locale:T("diag.hello", { name = "BobloUI" }), "Hello BobloUI", "Locale:T variables")
	expectEqual(UI.Locale:Resolve("@diag.added"), "Added", "Locale:Resolve")
	expect(table.find(UI.Locale:List(), "diag") ~= nil, "Locale:List")
	UI:SetLocale("ru")
	expectEqual(UI.Locale:Get(), "ru", "Russian locale")
	UI:SetLocale("es")
	expectEqual(UI.Locale:Get(), "es", "Spanish locale")
	UI:SetLocale("en")
end)

addTest("Window", "scale, density, geometry and layout controls", function()
	local original = UI:GetGeometry()
	local originalFont = UI:GetFont()
	UI:SetScale(1.15)
	expect(closeEnough(UI:GetScale(), 1.15), "SetScale/GetScale")
	UI:SetDensity("Compact")
	expectEqual(UI.Tokens:GetDensity(), "Compact", "SetDensity")
	expect(type(UI.Tokens:All()) == "table" and UI.Tokens:Get("ControlHeight") > 0, "Tokens API")
	UI:SetLocked(true)
	expect(UI:IsLocked(), "SetLocked/IsLocked")
	UI:SetRememberGeometry(false)
	expect(not UI:GetRememberGeometry(), "SetRememberGeometry(false)")
	UI:SetSidebarHidden(true)
	expect(UI:IsSidebarHidden(), "SetSidebarHidden")
	UI:ToggleSidebar()
	expect(not UI:IsSidebarHidden(), "ToggleSidebar")
	UI:SetSidebarWidth(206)
	expectEqual(UI:GetSidebarWidth(), 206, "SetSidebarWidth/GetSidebarWidth")
	UI:SetSidebarResizeEnabled(false):SetSidebarResizeEnabled(true)
	UI:SetSidebarCompacted(true)
	expect(UI:IsSidebarCompacted(), "SetSidebarCompacted/IsSidebarCompacted")
	UI:SetResponsiveThresholds({
		MinContainerWidth = 460,
		MinSidebarWidth = 112,
		SidebarCompactWidth = 58,
		SidebarCollapseThreshold = 660,
		CompactWidthActivation = 1000,
		EnableCompacting = true,
		DisableCompactingSnap = false,
	})
	expectEqual(UI._sidebarCompactWidth, 58, "SetResponsiveThresholds")
	UI:SetSearchEnabled(false):SetSearchEnabled(true)
	UI:SetGlobalSearch(false):SetGlobalSearch(true)
	UI:SetSearchbarSize(440)
	expectEqual(UI._searchbarSize, 440, "SetSearchbarSize")
	UI:SetTabSwipe(52, "bottom")
	expectEqual(UI._tabTransition.Offset, 52, "SetTabSwipe offset")
	expectEqual(UI._tabTransition.Direction, "bottom", "SetTabSwipe direction")
	UI:SetCompact(true)
	expect(UI:IsCompact(), "SetCompact/IsCompact")
	UI:SetFont(Enum.Font.Code)
	expectEqual(UI:GetFont().Regular, Enum.Font.Code, "SetFont/GetFont")
	UI:SetFont(originalFont)
	UI:SetAnimations({ Window = false, Tabs = true, Controls = true })
	expect(not UI.Motion:IsEnabled("Window"), "Window animation category")
	expect(UI.Motion:IsEnabled("Tabs") and UI.Motion:IsEnabled("Controls"), "independent animation categories")
	UI:SetAnimationEnabled("Window", true)
	UI:SetCornerRadius(6)
	expectEqual(UI:GetCornerRadius(), 6, "SetCornerRadius")
	for _, corner in { UI._rootCorner, UI._headerCorner, UI._footerCorner, UI._backgroundImageCorner, UI._flashCorner } do
		expect(corner and corner.CornerRadius.Offset == 6, "corner radius did not reach a visible surface")
	end
	expect(UI._rootHalo == nil, "window shadow halo still exists")
	UI:SetRounded(false)
	expectEqual(UI:GetCornerRadius(), 0, "SetRounded(false)")
	UI:SetSize(Vector2.new(780, 540)):SetPosition(UDim2.fromScale(0.5, 0.5))
	expect(typeof(UI:GetGeometry().Size) == "UDim2", "SetSize/GetGeometry")
	UI:ResetGeometry()
	expect(closeEnough(UI:GetScale(), 1), "ResetGeometry")
	UI:OpenDrawer()
	UI:CloseDrawer()
	UI:SetSize(original.Size):SetPosition(original.Position):SetScale(original.Scale or 1)
	UI:SetSidebarWidth(original.SidebarWidth or 184)
	UI:SetLocked(original.Locked == true):SetRememberGeometry(original.Remember ~= false)
	UI:SetDensity("Comfortable")
	UI:SetAnimations({ All = true })
	UI:SetRounded(true)
	UI:SetSidebarCompacted(original.SidebarCompacted == true)
end)

addTest("Window", "chrome, visibility and accessibility methods", function()
	UI:SetTitle("BobloUI Full Diagnostic — running")
	UI:SetSubtitle("automatic tests in progress")
	UI:SetIcon("activity")
	expect(UI.Icon == "activity", "Window:SetIcon")
	UI:SetWindowOpacity(0.91)
	expect(closeEnough(UI:GetWindowOpacity(), 0.91), "SetWindowOpacity/GetWindowOpacity")
	UI:SetBackgroundImage("rbxassetid://0", 0.2, 0.9)
	UI:SetBackgroundImage(nil)
	UI:SetTabTransition({ Style = "Fade", Duration = 0.03 })
	UI:SetWindowAnimation({ Style = "None" })
	UI:SetRestoreButton({ Mode = "Always", Text = "Show BobloUI", Draggable = true })
	UI:SetShowText("Show BobloUI")
	UI:SetFooterText("Diagnostic footer")
	expectEqual(UI:GetFooterText(), "Diagnostic footer", "SetFooterText/GetFooterText")
	expect(UI._footerText.Text == "Diagnostic footer", "footer label did not update")
	expect(UI._grip.Parent == UI._footer, "resize grip is outside footer")
	UI:SetReducedMotion(true)
	expect(UI.Motion.Enabled == false, "SetReducedMotion(true)")
	UI:SetReducedMotion(false)
	expect(UI.Motion.Enabled == true, "SetReducedMotion(false)")
	UI:SetKeyboardNavigation(false)
	expect(not UI.Navigation:IsEnabled(), "SetKeyboardNavigation(false)")
	UI:SetKeyboardNavigation(true)
	UI:Hide()
	expect(not UI:IsVisible(), "Hide")
	UI:Show()
	expect(UI:IsVisible(), "Show")
	UI:Toggle()
	expect(not UI:IsVisible(), "Toggle hide")
	UI:Toggle()
	expect(UI:IsVisible(), "Toggle show")
	UI:Minimize()
	expect(not UI:IsVisible(), "Minimize")
	UI:Restore()
	expect(UI:IsVisible(), "Restore")
	UI:SetWindowOpacity(0.98)
	UI:SetWindowAnimation({ Style = "SlideDown", Duration = 0.08, Offset = 8 })
	UI:SetTitle("BobloUI Full Diagnostic")
	UI:SetSubtitle("automatic API checks + manual visual QA")
	UI:SetIcon("flask-conical")
end)

addTest("Window", "ResetAll and transient window unload lifecycle", function()
	Toggle:SetValue(true)
	UI:ResetAll()
	expectEqual(Toggle:GetValue(), false, "Window:ResetAll")
	local transientId = "bobloui-transient-" .. guid
	local transient = BobloUI:CreateWindow({
		Id = transientId,
		Title = "Transient diagnostic",
		Settings = false,
		ToggleUIKeybind = false,
		WindowAnimation = { Style = "None" },
	})
	local unloaded = false
	transient:OnUnload(function()
		unloaded = true
	end)
	transient:Unload()
	expect(unloaded and transient:IsUnloaded(), "OnUnload/IsUnloaded")
	expect(BobloUI:GetWindow(transientId) == nil, "window registry cleanup")
	expect(type(BobloUI:SweepOrphans("nonexistent-" .. guid)) == "number", "SweepOrphans return value")
end)

local configArtifacts = {}
local function makeConfigName(suffix)
	local name = configPrefix .. "_" .. suffix
	table.insert(configArtifacts, name)
	return name
end

addTest("Config", "Save/Load, signals, list, duplicate and export", function()
	local base = makeConfigName("Base")
	local copy = makeConfigName("Copy")
	local saved = 0
	local loaded = 0
	local savedConnection = UI.Config.Saved:Connect(function(name)
		if name == base then
			saved += 1
		end
	end)
	local loadedConnection = UI.Config.Loaded:Connect(function(name)
		if name == base then
			loaded += 1
		end
	end)
	Toggle:SetValue(true)
	Slider:SetValue(75)
	local saveOk, saveErr = UI.Config:Save(base)
	expect(saveOk, "Config:Save failed: " .. tostring(saveErr))
	expectEqual(saved, 1, "Config.Saved signal")
	expect(table.find(UI.Config:List(), base) ~= nil, "Config:List")
	local duplicateOk, duplicateErr = UI.Config:Duplicate(base, copy)
	expect(duplicateOk, "Config:Duplicate failed: " .. tostring(duplicateErr))
	local exported = UI.Config:Export(base)
	expect(type(exported) == "string" and #exported > 30, "Config:Export")
	Toggle:SetValue(false)
	Slider:SetValue(10)
	local loadOk, loadErr = UI.Config:Load(base)
	expect(loadOk, "Config:Load failed: " .. tostring(loadErr))
	expectEqual(loaded, 1, "Config.Loaded signal")
	expectEqual(Toggle:GetValue(), true, "config control restore")
	expectEqual(Slider:GetValue(), 75, "config slider restore")
	savedConnection:Disconnect()
	loadedConnection:Disconnect()
end)

addTest("Config", "Save merges unknown keys", function()
	local name = makeConfigName("Merge")
	local raw = HttpService:JSONEncode({
		["$schema"] = 1,
		name = name,
		extension = { owner = "external", enabled = false },
		values = {
			DiagToggle = false,
			UnknownControl = { future = true, amount = 0 },
		},
		meta = {
			customMeta = { keep = "yes", zero = 0, disabled = false },
		},
	})
	local importOk, importErr = UI.Config:Import(raw, name)
	expect(importOk, "Config:Import failed: " .. tostring(importErr))
	Toggle:SetValue(true)
	local saveOk, saveErr = UI.Config:Save(name)
	expect(saveOk, "merge Save failed: " .. tostring(saveErr))
	local decoded = HttpService:JSONDecode(UI.Config:Export(name))
	expectEqual(decoded.extension.owner, "external", "unknown top-level key was lost")
	expectEqual(decoded.extension.enabled, false, "unknown false value was lost")
	expectEqual(decoded.values.UnknownControl.future, true, "unknown control was lost")
	expectEqual(decoded.values.UnknownControl.amount, 0, "unknown zero value was lost")
	expectEqual(decoded.meta.customMeta.keep, "yes", "unknown meta key was lost")
	expectEqual(decoded.meta.customMeta.disabled, false, "unknown meta false was lost")
	expectEqual(decoded.values.DiagToggle, true, "known value was not refreshed")
end)

addTest("Config", "false and zero settings survive Save/Load", function()
	local name = makeConfigName("FalseZero")
	UI:SetKeyboardNavigation(false)
	UI:SetUISounds(false)
	UI:SetSoundVolume(0)
	local saveOk, saveErr = UI.Config:Save(name)
	expect(saveOk, "Config:Save failed: " .. tostring(saveErr))
	local decoded = HttpService:JSONDecode(UI.Config:Export(name))
	expectEqual(decoded.meta.keyboardNavigation, false, "false keyboard navigation was defaulted away")
	expectEqual(decoded.meta.uiSounds, false, "false UI sounds was defaulted away")
	expectEqual(decoded.meta.soundVolume, 0, "zero sound volume was defaulted away")
	UI:SetKeyboardNavigation(true)
	UI:SetUISounds(true)
	UI:SetSoundVolume(1)
	local loadOk, loadErr = UI.Config:Load(name)
	expect(loadOk, "Config:Load failed: " .. tostring(loadErr))
	expect(not UI.Navigation:IsEnabled(), "false keyboard navigation was not restored")
	expect(not UI.Sound:IsEnabled(), "false UI sounds was not restored")
	expectEqual(UI.Sound:GetVolume(), 0, "zero sound volume was not restored")
	UI:SetKeyboardNavigation(true)
end)

addTest("Config", "autoload follows Rename and clears on Delete", function()
	local sourceName = makeConfigName("Autoload")
	local renamed = makeConfigName("AutoloadRenamed")
	local saveOk, saveErr = UI.Config:Save(sourceName)
	expect(saveOk, "Config:Save failed: " .. tostring(saveErr))
	UI.Config:SetAutoLoad(sourceName)
	expectEqual(UI.Config:GetAutoLoad(), sourceName, "SetAutoLoad/GetAutoLoad")
	local renameOk, renameErr = UI.Config:Rename(sourceName, renamed)
	expect(renameOk, "Config:Rename failed: " .. tostring(renameErr))
	expectEqual(UI.Config:GetAutoLoad(), renamed, "Rename did not update autoload")
	local loadAutoOk, loadAutoErr = UI.Config:LoadAuto()
	expect(loadAutoOk, "Config:LoadAuto failed: " .. tostring(loadAutoErr))
	local deleteOk, deleteErr = UI.Config:Delete(renamed)
	expect(deleteOk, "Config:Delete failed: " .. tostring(deleteErr))
	expect(UI.Config:GetAutoLoad() == nil, "Delete did not clear autoload")
end)

addTest("Config", "missing migration is an error; registered migration runs", function()
	local missing = makeConfigName("MissingMigration")
	local legacyRaw = HttpService:JSONEncode({ ["$schema"] = 0, values = {} })
	expect(UI.Config:Import(legacyRaw, missing), "legacy import failed")
	local missingOk, missingErr = UI.Config:Load(missing)
	expect(not missingOk, "missing migration silently succeeded")
	expect(contains(missingErr, "missing config migration 0 -> 1"), "missing migration error is unclear")

	UI.Config:RegisterMigration(0, 1, function(data)
		data.values = data.values or {}
		data.values.DiagToggle = true
		return data
	end)
	local migrated = makeConfigName("Migrated")
	expect(UI.Config:Import(legacyRaw, migrated), "migration fixture import failed")
	Toggle:SetValue(false)
	local migrateOk, migrateErr = UI.Config:Load(migrated)
	expect(migrateOk, "registered migration failed: " .. tostring(migrateErr))
	expectEqual(Toggle:GetValue(), true, "migration output was not loaded")
end)

addTest("Config", "ignored value and SetFolder", function()
	local ignored = makeConfigName("Ignored")
	UI.Config:SetIgnored("DiagSlider", true)
	local saveOk, saveErr = UI.Config:Save(ignored)
	expect(saveOk, "ignored Save failed: " .. tostring(saveErr))
	local decoded = HttpService:JSONDecode(UI.Config:Export(ignored))
	expect(decoded.values.DiagSlider == nil, "SetIgnored value was persisted")
	UI.Config:SetIgnored("DiagSlider", false)
	UI.Config:SetFolder(configFolder)
	expect(type(UI.Config:List()) == "table", "Config:SetFolder")
end)

addTest("Services", "notification queue, update, progress and position", function()
	UI:SetNotificationPosition("BottomLeft")
	expectEqual(UI.Notify:GetPosition(), "BottomLeft", "notification position")
	local notices = {}
	for index = 1, 5 do
		notices[index] = UI.Notify:Push({
			Title = "Queue " .. tostring(index),
			Content = if index == 1 then nil else "Diagnostic notification",
			Description = if index == 1 then "Diagnostic notification alias" else nil,
			Variant = "Loading",
			Progress = 0,
			Icon = "sparkles",
			BigIcon = if index == 1 then "rbxassetid://0" else nil,
			ImageScaleType = Enum.ScaleType.Fit,
			IconColor = Color3.fromHex("8172F2"),
			TitleColor = Color3.fromHex("FFFFFF"),
			ContentColor = Color3.fromHex("B8B2CC"),
			Persist = true,
			Steps = if index == 1 then 4 else nil,
		})
	end
	expectEqual(notices[1].Content, "Diagnostic notification alias", "notification Description alias")
	expectEqual(notices[1].Duration, 0, "notification Persist alias")
	expect(notices[1].Image ~= nil, "notification BigIcon alias")
	notices[1]:ChangeTitle("Queue updated"):ChangeDescription("Updated through compatibility methods")
	notices[1]:ChangeStep(2)
	expect(closeEnough(notices[1].Progress, 0.5), "Notify:ChangeStep")
	notices[1]:SetProgress(0.5):Update({ Content = "Updated", Variant = "Success", Progress = 1 })
	notices[1]:SetImage(nil):SetColors(Color3.fromHex("43D17A"), nil, nil)
	expectEqual(notices[1].Progress, 1, "Notify:SetProgress/Update")
	expect(notices[1].Image == nil, "Notify:SetImage(nil)")
	for _, notice in notices do
		notice:Dismiss()
	end
	UI:SetNotificationPosition("TopRight")
end)

addTest("Services", "Alert, Confirm, Prompt and Choice handles", function()
	local cases = {
		{ Handle = UI.Dialog:Alert({ Title = "Alert test" }), Value = true },
		{ Handle = UI.Dialog:Confirm({ Title = "Confirm test" }), Value = false },
		{ Handle = UI.Dialog:Prompt({ Title = "Prompt test", Default = "initial" }), Value = "typed" },
		{
			Handle = UI.Dialog:Choice({
				Title = "Choice test",
				Choices = { { Text = "A", Value = "a" }, { Text = "B", Value = "b" } },
			}),
			Value = "b",
		},
	}
	for _, case in cases do
		local resolved = "unset"
		case.Handle.Resolved:Connect(function(value)
			resolved = value
		end)
		expect(case.Handle:IsOpen(), "dialog was not open")
		case.Handle:Resolve(case.Value)
		expectEqual(resolved, case.Value, "dialog resolved value")
		expectEqual(case.Handle:Await(), case.Value, "dialog Await after resolve")
		expect(not case.Handle:IsOpen(), "dialog remained open")
		case.Handle:Destroy()
	end
end)

addTest("Services", "Custom dialog and DialogSection", function()
	local built = false
	local handle = UI.Dialog:Custom({
		Title = "Custom test",
		Description = "Dynamic footer and full DialogSection test",
		Height = 340,
		OutsideClickDismiss = true,
		AutoDismiss = false,
		FooterButtons = {
			cancel = { Text = "Cancel", Order = 1 },
			continue = { Text = "Continue", Variant = "Primary", WaitTime = 0.03, Order = 2 },
		},
		Build = function(section)
			built = true
			section:AddParagraph({ Content = "Custom content" })
			section:AddToggle({ Title = "Anonymous toggle", Default = true })
			section:AddDivider({ Title = "Divider" })
			section:AddStatus({ Title = "Status", Value = "OK", Status = "Success" })
			section:AddProgress({ Title = "Progress", Min = 0, Max = 1, Default = 0.5 })
			section:AddCode({ Title = "Code", Code = "return true", Height = 54 })
			section:AddImage({ Title = "Image", Image = "rbxassetid://0", Height = 54 })
		end,
	})
	expect(built and handle.Section ~= nil, "Dialog:Custom Build")
	expect(handle:IsOpen(), "custom dialog was not open")
	handle:SetTitle("Custom test updated"):SetDescription("Updated description")
	handle:SetButtonDisabled("cancel", true)
	expect(handle._buttons.cancel.Disabled, "Dialog:SetButtonDisabled")
	handle:SetButtonOrder("continue", 3)
	expectEqual(handle._buttons.continue.Button.LayoutOrder, 3, "Dialog:SetButtonOrder")
	handle:AddFooterButton("later", { Text = "Later", Close = false })
	expect(handle._buttons.later ~= nil, "Dialog:AddFooterButton")
	handle:RemoveFooterButton("later")
	expect(handle._buttons.later == nil, "Dialog:RemoveFooterButton")
	expect(
		waitFor(function()
			return not handle._buttons.continue.Waiting
		end, 0.5),
		"Dialog WaitTime did not settle"
	)
	handle:Close("done")
	expect(not handle:IsOpen(), "custom dialog did not close")
	expectEqual(handle:Await(), "done", "custom dialog Await result")
end)

addTest("Services", "loading handle and facade", function()
	local retried = false
	local loading = UI:ShowLoading({
		Title = "Diagnostic loading",
		Message = "Starting",
		Description = "Loading method compatibility test",
		Progress = 0.1,
		Icon = "rocket",
		LoadingIconTweenTime = 0,
		LoadingIconColor = Color3.fromHex("8172F2"),
		Steps = { "Prepare", "Validate", "Finish" },
		CurrentStep = 1,
		TotalSteps = 3,
		ShowSidebar = true,
		Build = function(section)
			section:AddParagraph({ Content = "Loading sidebar content" })
			section:AddToggle({ Title = "Optional loading choice", Default = true })
		end,
	})
	expect(loading.Frame.Parent ~= nil, "ShowLoading did not mount")
	expect(loading.Sidebar ~= nil, "loading control sidebar")
	loading:ShowSidebarPage(false):ShowSidebarPage(true)
	loading
		:SetTitle("Diagnostic loading updated")
		:SetMessage("Working")
		:SetDescription("Updated loading description")
		:SetProgress(0.5)
		:SetSteps({ "One", "Two", "Three", "Four" })
		:SetLoadingIcon("loader-circle")
		:SetLoadingIconTweenTime(0)
		:SetLoadingIconColor(Color3.fromHex("8172F2"))
		:SetTotalSteps(4)
		:SetCurrentStep(2, "Halfway")
	expectEqual(loading._currentStep, 2, "Loading:SetCurrentStep")
	expectEqual(loading._totalSteps, 4, "Loading:SetTotalSteps")
	loading:SetErrorMessage("Expected diagnostic error")
	loading:SetErrorButtons({
		{
			Text = "Retry",
			Callback = function()
				retried = true
			end,
		},
	})
	loading:ShowErrorPage(false):ShowErrorPage(true)
	expect(loading._fill.Size.X.Scale >= 0 and loading._fill.Size.X.Scale <= 1, "loading progress range")
	loading:Dismiss()
	UI:HideLoading()
	expect(retried == false, "loading action ran without a click")
end)

addTest("Services", "public draggable overlays", function()
	local label = UI:AddDraggableLabel({ Text = "Diagnostic label", Icon = "activity" })
	local clicked = 0
	local button = UI:AddDraggableButton({
		Text = "Diagnostic button",
		Icon = "play",
		Callback = function()
			clicked += 1
		end,
	})
	local menu = UI:AddDraggableMenu("Diagnostic menu", { Size = UDim2.fromOffset(220, 140) })
	label:SetText("Updated label"):SetPosition(UDim2.fromOffset(18, 70)):SetVisible(true)
	button:SetText("Updated button")
	menu:SetTitle("Updated menu")
	expect(typeof(label:GetInstance()) == "Instance", "overlay GetInstance")
	expect(menu.Content ~= nil and button.Button ~= nil, "overlay public handles")
	label:Destroy()
	button:Destroy()
	menu:Destroy()
	expectEqual(clicked, 0, "overlay button callback ran without click")
end)

addTest("Services", "sound registry, enable and zero volume", function()
	UI:RegisterSound("DiagnosticSilent", { Id = "1", Volume = 0.1, PlaybackSpeed = 1 })
	UI:SetUISounds(false):SetSoundVolume(0)
	expect(not UI.Sound:IsEnabled(), "SetUISounds(false)")
	expectEqual(UI.Sound:GetVolume(), 0, "SetSoundVolume(0)")
	expect(UI:PlaySound("DiagnosticSilent") == nil, "disabled sound unexpectedly played")
	UI.Sound:Unregister("DiagnosticSilent")
	UI:SetUISounds(false)
end)

addTest("Services", "HUD, cursor and Layers", function()
	UI:SetWatermark("Diagnostic watermark")
	expect(UI.HUD._watermark ~= nil, "SetWatermark")
	UI:SetKeybindHUD(true)
	expect(UI.HUD._keybind ~= nil, "SetKeybindHUD(true)")
	UI:SetKeybindHUD(false):SetWatermark(false)
	UI:SetCustomCursor(true, { Size = 8 })
	expect(type(UI.Cursor:IsEnabled()) == "boolean", "Cursor:IsEnabled")
	UI:SetCustomCursor(false)
	expect(not UI.Cursor:IsEnabled(), "SetCustomCursor(false)")
	local before = UI.Layers:StackDepth()
	UI:SetThemeToken("ScrimTransparency", 0.33)
	local themedLayer = UI.Layers:Push({ Scrim = true, Modal = true })
	expect(closeEnough(themedLayer.Catcher.BackgroundTransparency, 0.33), "Layer themed scrim alpha")
	UI:SetThemeToken("ScrimTransparency", 0.29)
	expect(closeEnough(themedLayer.Catcher.BackgroundTransparency, 0.29), "live scrim alpha binding")
	themedLayer:Dismiss()
	UI.Theme:ResetToken("ScrimTransparency")
	local layer = UI.Layers:Push({ Modal = false })
	expect(layer:IsOpen() and UI.Layers:StackDepth() == before + 1, "Layer:Push/StackDepth")
	UI.Layers:DismissTop()
	expect(not layer:IsOpen() and UI.Layers:StackDepth() == before, "Layer:DismissTop")
	local first = UI.Layers:Push({ Modal = false })
	local second = UI.Layers:Push({ Modal = false })
	UI.Layers:DismissAll()
	expect(not first:IsOpen() and not second:IsOpen() and UI.Layers:StackDepth() == 0, "Layer:DismissAll")
end)

addTest("Services", "palette, Settings and keyboard navigation", function()
	UI:OpenSearch("slider")
	expect(
		waitFor(function()
			return UI.Palette._handle ~= nil
		end, 1),
		"OpenSearch"
	)
	UI.Palette:Close()
	UI:OpenCommands()
	expect(
		waitFor(function()
			return UI.Palette._handle ~= nil
		end, 1),
		"OpenCommands"
	)
	UI.Palette:Close()
	UI:OpenSettings()
	task.wait()
	local settingsTab = UI:GetTab("__bobloui_settings")
	expect(settingsTab ~= nil and settingsTab:IsSelected(), "OpenSettings")
	expect(UI:Get("__settings.theme") ~= nil, "Settings appearance controls")
	ControlsTab:Select()
	task.wait()
	UI.Navigation:Move(1)
	expect(UI.Navigation:GetFocused() ~= nil, "Navigation:Move")
	UI.Navigation:Activate()
	UI.Navigation:Clear()
	expect(UI.Navigation:GetFocused() == nil, "Navigation:Clear")
end)

addTest("Cleanup", "dynamic Destroy lifecycle", function()
	local disposableTab = UI:AddTab({ Id = "diag-disposable-tab", Title = "Disposable" })
	local disposableSection = disposableTab:AddSection({ Id = "diag-disposable-section", Title = "Disposable" })
	local disposableControl =
		disposableSection:AddToggle({ Id = "DiagDisposable", Title = "Disposable", Default = true })
	expect(UI:Get("DiagDisposable") == disposableControl, "disposable registration")
	disposableControl:Destroy()
	expect(UI:Get("DiagDisposable") == nil, "control Destroy registry cleanup")
	disposableSection:Destroy()
	disposableTab:Destroy()
	expect(UI:GetTab("diag-disposable-tab") == nil, "tab Destroy cleanup")
end)

-- Runner -------------------------------------------------------------------

local function cleanupConfigArtifacts()
	if not UI.Config then
		return
	end
	UI.Config:SetAutoLoad(nil)
	for _, name in configArtifacts do
		pcall(function()
			UI.Config:Delete(name)
		end)
		pcall(function()
			UI.Config._storage:Delete(UI.Config:_file(name) .. ".bak")
		end)
	end
	pcall(function()
		UI:SetDefaultTheme(nil)
	end)
	for _, name in themeArtifacts do
		pcall(function()
			UI:DeleteCustomTheme(name)
		end)
	end
end

local function updateVisibleReport(index)
	if UI:IsUnloaded() then
		return
	end
	RunProgress:SetValue(if #tests > 0 then index / #tests else 1, true)
	RunStatus:SetValue(
		string.format("%d passed · %d failed · %d skipped", results.Passed, results.Failed, results.Skipped),
		true
	)
	ReportCode:SetCode(table.concat(results.Lines, "\n"))
end

local function runAll()
	print(string.rep("=", 72))
	print("BobloUI Full Diagnostic", BobloUI.Version, requestUrl)
	print("Window Id:", windowId)
	print(string.rep("=", 72))

	OverviewTab:Select()
	task.wait()
	RunStatus:SetValue("Running " .. tostring(#tests) .. " automatic checks", true)
	RunStatus:SetStatus("Pending")

	for index, test in tests do
		if UI:IsUnloaded() then
			record("FAIL", test, "window was unloaded before the suite completed")
			results.Failed += 1
			break
		end

		local ok, value = xpcall(test.Callback, errorHandler)
		if ok then
			results.Passed += 1
			record("PASS", test)
		elseif type(value) == "table" and value.__diagnosticSkip then
			results.Skipped += 1
			record("SKIP", test, value.Reason)
		else
			results.Failed += 1
			record("FAIL", test, value)
		end
		updateVisibleReport(index)
		task.wait()
	end

	cleanupConfigArtifacts()
	sourceSignal:Destroy()
	PassthroughSource:Destroy()
	ViewportPart:Destroy()

	if UI:IsUnloaded() then
		return
	end

	local total = results.Passed + results.Failed + results.Skipped
	local summary = string.format(
		"Finished %d checks: %d PASS, %d FAIL, %d SKIP. Open Detailed output and the console for errors; then complete the Manual QA tab.",
		total,
		results.Passed,
		results.Failed,
		results.Skipped
	)
	SummaryParagraph:SetContent(summary)
	RunProgress:SetValue(1, true)
	RunStatus:SetValue(summary, true)
	RunStatus:SetStatus(if results.Failed == 0 then "Success" else "Error")
	OverviewTab:SetBadge(if results.Failed == 0 then "PASS" else tostring(results.Failed) .. " FAIL")
	ReportCode:SetCode(table.concat(results.Lines, "\n"))
	OverviewTab:Select()

	UI.Notify:Push({
		Title = if results.Failed == 0 then "Automatic diagnostic passed" else "Automatic diagnostic found failures",
		Content = summary,
		Variant = if results.Failed == 0 then "Success" else "Error",
		Duration = 8,
		Progress = 1,
	})

	print(string.rep("=", 72))
	print("BobloUI Full Diagnostic complete:", summary)
	print("The window remains open for Manual QA. Use its Unload button when finished.")
	print(string.rep("=", 72))
end

task.spawn(runAll)

return UI
