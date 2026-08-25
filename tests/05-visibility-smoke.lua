local BobloUI = loadstring(
	game:HttpGet(
		"https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.lua?cb=" .. tostring(os.time())
	)
)()
local actualVersion = tostring(BobloUI.Version)
assert(actualVersion == "0.11.5-beta.1", string.format("wrong version %q (length %d)", actualVersion, #actualVersion))
local UI = BobloUI:CreateWindow({
	Id = "bobloui-visibility-0113",
	Title = "BobloUI Visibility",
	Subtitle = "Hide -> Show BobloUI",
	Theme = "Dark",
	ShowText = "Show BobloUI",
	ToggleUIKeybind = "RightShift",
})
local tab = UI:AddTab({ Id = "main", Title = "Main", Icon = "home" })
local sec = tab:AddSection({ Title = "Visibility test" })
sec:AddParagraph({
	Content = "Press the window close/minimize control. A 'Show BobloUI' prompt must appear at the top on desktop AND mobile. Tap/click it to restore. RightShift is an additional desktop shortcut.",
})
sec:AddButton({
	Title = "Hide now",
	Text = "Hide",
	Callback = function()
		UI:Hide()
	end,
})
print("[BobloUI 0.11.5 visibility] READY")
print("Hide the window. Expected: Show BobloUI appears at top-center on every device.")
