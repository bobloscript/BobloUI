# P1/P2 service and container APIs

This page covers the BobloUI APIs added by the completed Obsidian documentation
gap audit. Component option tables remain generated in the individual
`docs/*.md` pages.

## Reactive containers

`VisibleWhen` and `EnabledWhen` accept the same table or function forms on
Sections, Rows and TabBoxes as on controls.

```lua
local Advanced = Tab:AddSection({
	Title = "Advanced",
	VisibleWhen = { MasterEnabled = true },
	EnabledWhen = function(State)
		return State:Get("AccessLevel") >= 2
	end,
})

local Row = Advanced:AddRow({Columns=2, EnabledWhen={Ready=true}})
local Box = Advanced:AddTabBox({Title="Modes", VisibleWhen={Ready=true}})
```

Container methods are `SetVisible`, `IsVisible`, `SetEnabled`, `IsEnabled`,
`Reset` and `Destroy`. A disabled container disables its children without
overwriting each child's manual or dependency-controlled state.

## Dialog v2

```lua
local handle = UI.Dialog:Custom({
	Title = "Confirm task",
	Description = "Review the settings.",
	Height = 420,
	OutsideClickDismiss = false,
	AutoDismiss = false,
	FooterButtons = {
		cancel = {Text="Cancel", Order=1},
		start = {Text="Start", Variant="Primary", WaitTime=2, Order=2},
	},
	Build = function(section, dialog)
		section:AddToggle({Title="Create backup", Default=true})
		section:AddViewport({Title="Preview", Object=workspace.Model})
	end,
})
```

Custom-dialog handles expose:

```text
Section
AddFooterButton / RemoveFooterButton
SetButtonDisabled / SetButtonOrder
SetTitle / SetDescription
Close / Dismiss / IsOpen / Await / Destroy
```

Returning `false` from a footer callback keeps the dialog open. `Close=false`
does the same for that button. `WaitTime` prevents activation until its progress
guard settles.

## Draggable overlays

```lua
local label = UI:AddDraggableLabel({Text="Status: idle", Icon="activity"})
local button = UI:AddDraggableButton({
	Text="Run",
	Icon="play",
	Callback=function(handle) end,
})
local menu = UI:AddDraggableMenu("Tools", {Size=UDim2.fromOffset(260, 180)})

label:SetText("Status: running")
menu:SetTitle("Advanced tools")
```

Every overlay handle supports `SetVisible`, `SetPosition`, `GetInstance` and
`Destroy`. Menus expose a `Content` Frame for custom Roblox UI.

## Window customization

```lua
UI:SetSidebarWidth(200)
UI:SetSidebarResizeEnabled(true)
UI:SetCompact(true)
UI:SetFont(Enum.Font.Gotham)
UI:SetAnimations({Window=true, Tabs=false, Controls=true})
UI:SetAnimationEnabled("Tabs", true)
```

Sidebar width, hidden state and compact state are included in remembered Config
geometry. Reduced motion remains a global override over all animation categories.

## Loading and notifications

`ShowLoading` accepts `Icon`, `Message`/`Status`, `Description`, `Steps`,
`CurrentStep`, `TotalSteps`, `Sidebar=true`/`ShowSidebar=true`, or a
`Build(section, handle)` callback. Its handle supports `SetTitle`, `SetMessage`,
`SetStatus`, `SetDescription`, `SetProgress`, `SetStep`, `SetCurrentStep`,
`SetTotalSteps`, `SetSteps`, `SetIcon`/`SetLoadingIcon`, loading-icon color and
rotation time, `ShowSidebarPage`, `ShowErrorPage`, `SetErrorMessage`,
`SetErrorButtons`, `SetError`, `Continue`, `Destroy` and `Dismiss`.

Notifications additionally accept `Icon`, `Image`/`BigImage`/`BigIcon`,
`ImageScaleType`, `Color`/`AccentColor`/`IconColor`, `TitleColor`, `ContentColor`,
`Sound`, `SoundOptions`, `Persist`, and `Time`/`Duration`. `Description` is an
alias of `Content`.
Notification handles expose `Update`, `ChangeTitle`, `ChangeDescription`,
`ChangeStep`/`SetStep`, `SetProgress`, `SetImage`, `SetColors`, `Destroy` and
`Dismiss`.

## Keybind composition

Keybinds accept `Modifiers`/`DefaultModifiers`, `ExactModifiers`, primary-key
`Whitelist`/`Blacklist`, modifier `ModifierWhitelist`/`ModifierBlacklist` or
`WhitelistedModifiers`/`BlacklistModifiers`,
`CustomModes`, `WaitForCallback`, `AttachTo`, `SyncToggle`, `NoUI`, `Mobile`
and `MobileText`.
Buttons and Toggles expose `AddKeybind(options)`. `Trigger()` powers code and
touch actions without requiring physical modifier keys to be held.

## Dropdown runtime maps

`Options` and the compatibility alias `Values` accept arrays, rich option
records, or dictionaries where the key is the stable value and the mapped value
is the visible label. Advanced Dropdown handles expose `SetOptions`/`SetValues`,
`AddOption`/`AddValues`, `SetDragSelect`, `GetActiveValues`,
`SetDisabledValues`/`AddDisabledValues`, `SetValueDisabled`,
`SetValueImage`/`SetValueImages`/`AddValueImages`, `SetMaxVisibleRows` and
`SetFormatters`. Runtime map changes rebuild an open picker immediately.
