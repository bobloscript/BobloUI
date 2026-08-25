# BobloUI

Responsive, AI-first UI framework for Roblox script hubs.

**Current release: `0.11.5-beta.1`.** The public API, controls, state, config, search/command palette, mobile layouts and AI artifacts are implemented. The remaining gate before `1.0` is runtime validation in Roblox Studio/executors across desktop and touch devices.

## Install

Host `dist/BobloUI.min.lua` (or `dist/BobloUI.lua`) and the generated
`dist/assets/` folder in the same GitHub repository:

```text
BobloUI.lua
assets/
  bobloui/
    lucide-1.png
    lucide-2.png
```

Then load the library as one Lua file:

```lua
local BobloUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.min.lua"))()

local UI = BobloUI:CreateWindow({
    Id = "my-hub",
    Title = "My Hub",
    Icon = "sword",
    Theme = "Dark",
    FooterText = "My Hub · ready",
    ConfigFolder = "MyHub",
    AutoLoad = true,
})
```

The source stays modular; the bundler turns `src/` into one executor-loadable file. It checks missing modules, cycles and forbidden upward dependencies before emitting the bundle.

```bash
npm run check
npm run build
npm run format:check
npm test
```

## Basic usage

```lua
local Farm = UI:AddTab({Id="farm", Title="Farm", Icon="gamepad"})
local Automation = Farm:AddSection({Title="Automation", Icon="zap", Span="Auto", Layout="Stack"})

local AutoFarm = Automation:AddToggle({
    Id = "AutoFarm",
    Title = "Auto Farm",
    Default = false,
})

Automation:AddSlider({
    Id = "FarmRange",
    Title = "Farm Range",
    Min = 10,
    Max = 250,
    Default = 75,
    VisibleWhen = {AutoFarm = true},
})
```

Sections are optional for small UIs:

```lua
local Main = UI:AddTab({Id="main", Title="Main"})
Main:AddToggle({Id="Enabled", Title="Enabled", Default=true})
Main:AddButton({Title="Run", Callback=function() print("run") end})
```

Direct `Tab:Add*` calls use an implicit section internally.

## Visual identity and icons

Tabs, Sections and controls accept `Icon`; Sections and controls also expose
`SetIcon()`. BobloUI ships a pinned Lucide spritesheet index with 1,756 names.
The index and loader are bundled into `BobloUI.lua`. The two PNG atlases are
hosted in BobloScript's own GitHub repository; no Roblox asset IDs are needed.
Common names include `sword`, `crosshair`, `settings-2`, `shield-check`,
`gamepad-2`, `users`, `bell`, `palette`, `wand-sparkles`, `zap`, `activity`,
`database`, `terminal`, `search`, `save` and `trash-2`.

```lua
Automation:SetIcon("activity")
AutoFarm:SetIcon("toggle-right", "Accent")
```

Names are case-insensitive; spaces, underscores and hyphens are normalized. Unknown names use an intentional sparkle fallback instead of a missing-glyph square.

The complete list is available at runtime:

```lua
print(BobloUI.Icon.Count) -- 1756
print(BobloUI.Icon.Has("sword"))

for _, name in BobloUI.Icon.List() do
    print(name)
end
```

Roblox `ImageLabel` instances cannot display a raw HTTPS URL directly. On the
first icon request, BobloUI downloads only the two pinned PNG files, validates
their PNG signature, exact byte length and dimensions, stores them in
`BobloUI/assets/`, and registers them through the executor's local custom-asset
API. Later launches reuse the cache.

You can inspect the provider without creating a window:

```lua
BobloUI.Icon.Prepare()
local status = BobloUI.Icon.GetStatus()
print(status.State, status.Provider, status.Error)
```

Executors without HTTP, filesystem, or a custom-asset API automatically use
the built-in GuiObject icon set. The UI continues to work; only the full Lucide
catalog is unavailable. After a temporary network failure, call
`BobloUI.Icon.Retry()`.

Forks can point at their own HTTPS-hosted copies before creating windows:

```lua
BobloUI.Icon.SetAtlasUrls(
    "https://raw.githubusercontent.com/OWNER/REPO/main/dist/assets/bobloui/lucide-1.png",
    "https://raw.githubusercontent.com/OWNER/REPO/main/dist/assets/bobloui/lucide-2.png"
)
```

Custom registered icons still take priority over Lucide. The asset-free
GuiObject glyphs also cover unavailable atlases and unknown names. No remote
Lua code is fetched or executed by the icon provider. Licences and the pinned
upstream snapshot are in `vendor/lucide/`; every generated bundle also contains
the required licence notices.

## Canonical controls

There are exactly sixteen constructors. No aliases are provided.

```text
AddButton
AddToggle
AddSlider
AddDropdown
AddInput
AddKeybind
AddColorPicker
AddParagraph
AddDivider
AddStatus
AddProgress
AddCode
AddImage
AddPassthrough
AddViewport
AddVideo
```

Multi-select is the same dropdown:

```lua
Section:AddDropdown({
    Id="Targets",
    Title="Targets",
    Options={"Players","NPCs","Bosses"},
    Multi=true,
})
```

Dictionary `Values` use an Obsidian-compatible selection map, while the classic
array API remains unchanged:

```lua
local modes = Section:AddDropdown({
    Id = "Modes",
    Title = "Modes",
    Values = {Legit = "Legit", Rage = "Rage"},
    Multi = true,
    Default = {Legit = true},
})

print(modes:GetValue().Legit) -- true
```

P3 window tuning includes `DisableSearch`, `SearchbarSize`, `GlobalSearch`,
`ShowMobileButtons`, `MobileButtonsSide`, `EnableCompacting`,
`DisableCompactingSnap`, `SidebarCompacted`, `MinContainerWidth`,
`MinSidebarWidth`, `SidebarCompactWidth`, `SidebarCollapseThreshold`,
`CompactWidthActivation`, `TabTransitionTime`, `TabSwipeOffset` and
`TabSwipeFrom`. See
`docs/p3-controls-window.md` for examples and compatibility behavior.

`Paragraph` without `Title` is the label-like text primitive; there is no `AddLabel`.

### Passthrough, 3D and video

```lua
local customFrame = Instance.new("Frame")
customFrame.Size = UDim2.new(1, 0, 0, 56)

Section:AddPassthrough({
    Title="Custom Roblox UI",
    Instance=customFrame,
    Clone=true,
    Height=56,
})

local preview = Section:AddViewport({
    Title="Item preview",
    Object=workspace.ItemModel,
    Clone=true,
    Interactive=true,
    AutoFocus=true,
    Height=180,
})

local video = Section:AddVideo({
    Title="Tutorial",
    Video="rbxassetid://YOUR_VIDEO",
    Playing=false,
    Looped=true,
    Volume=0.5,
})
```

`Clone=false` preserves and restores source Viewport objects by default; pass
`DestroyObject=true` only when the control should own and destroy that object.

## State

State updates are synchronous. `Batch` coalesces watcher fan-out for bulk changes such as config loading.

```lua
UI.State:Set("AutoFarm", true)
print(UI.State:Get("AutoFarm"))

local disconnect = UI.State:Watch("AutoFarm", function(value, oldValue)
    print(value, oldValue)
end)

UI.State:Batch(function()
    UI.State:Set("AutoFarm", false)
    UI.State:Set("FarmRange", 120)
end)
```

Available methods:

```text
Get  Has  Set  Update  Reset  Watch  WatchMany  Batch  Snapshot
```

Stateful controls with an `Id` automatically bind to the store.

## Dependencies

Simple:

```lua
VisibleWhen = {AutoFarm = true}
```

Dynamic:

```lua
VisibleWhen = function(State)
    return State:Get("ESP") and State:Get("ESPMode") == "Advanced"
end
```

Dynamic dependencies are tracked inside the Store itself. Reads through the `State` argument and through another reference to the same `UI.State` are both recorded; predicates that read no state still produce a development warning.

Both `VisibleWhen` and `EnabledWhen` are supported on controls and on
`Section`, `Row` and `TabBox` containers. Disabling a container suppresses all
of its child controls without overwriting their own disabled state.

## Common control API

Normal controls expose the common handle API:

```text
GetValue / SetValue
SetTitle / SetDescription / SetKeywords
SetVisible / IsVisible
SetDisabled / IsDisabled
SetLoading
SetBadge
Reset / CopyValue / PasteValue
Highlight
Reveal
OnChanged
GetInstance
Destroy
```

Presentation controls expose the meaningful subset plus their specific methods. Component-specific methods are generated into `docs/` and `llms-full.txt` from the same manifest as runtime validation.

## Built-in Settings and responsive UI

The Settings center is enabled by default and is mounted lazily after your first normal tab. It exposes theme preset/accent/full token editing, scale, density, locale, reduced motion, high contrast, keyboard/gamepad navigation, UI sound preferences, window geometry, configs, Favorites and Keybinds.

```lua
UI:OpenSettings()
UI:SetScale(1.1)
UI:SetDensity("Compact")
UI:SetHighContrast(true)
UI:SetSidebarWidth(196)
UI:SetCompact(true)
UI:SetFont(Enum.Font.Gotham)
UI:SetAnimations({Window=true, Tabs=true, Controls=false})
```

Sections can adapt at both page and control level:

```lua
local Advanced = Main:AddSection({
    Title = "Advanced",
    Span = 2,               -- 1 | 2 | "Auto"
    Layout = "Auto",       -- "Stack" | "Grid" | "Auto"
})
```

Field-like controls automatically switch from inline to stacked form when their available width becomes too small.

### Theme editor / arbitrary colors

```lua
UI:SetTheme("Dark")
UI:SetTheme("Light")
UI:SetAccent(Color3.fromHex("#8B7CF6"))
UI:SetThemeToken("Surface", Color3.fromHex("#101216"))

local json = UI:ExportTheme(true) -- optionally copies
UI:ImportTheme(json)
```

BobloUI includes exactly two presets: `Dark` and `Light`. Custom themes can be
registered only for the current run or saved through `ThemeManager`. A complete
custom palette supplies **26 base colors**; BobloUI derives its semantic colors
and interaction states automatically. It also accepts one numeric
`ScrimTransparency` value (`0` = opaque, `1` = invisible). Existing palettes
without that value use a compatible default.
See [docs/themes.md](docs/themes.md) for the exact palette contract.

```lua
UI:SaveCustomTheme("MyDark", UI.Theme:Palette())
UI:SetDefaultTheme("MyDark")
UI:LoadCustomTheme("MyDark")
UI:SetThemeFolder("MyGame") -- optional runtime namespace switch

print(UI:GetDefaultTheme())
print(table.concat(UI:ListCustomThemes(), ", "))
```

Saved themes appear in the built-in Settings theme picker. Stale default markers
are cleared safely if their custom theme file disappears.

### Tab groups and segmented controls

```lua
local Visuals = UI:AddTab({Title="Visuals", Group="PLAYER", Icon="eye"})
Visuals:AddDropdown({
    Id="VisualMode", Title="Mode",
    Options={"ESP","World","Lighting"},
    Style="Segmented",
})
```

### Optional UI sounds

BobloUI ships no audio assets. Register your own and users can disable or change UI sound volume in Settings.

```lua
local UI = BobloUI:CreateWindow({
    Id="hub", Title="Hub",
    Sounds={
        Click={Id="123456789",Volume=0.25},
        Toggle={Id="123456790",Volume=0.20},
        Select={Id="123456791",Volume=0.20},
        Open={Id="123456792",Volume=0.20},
    },
})
```

### Chord keybinds and draggable overlays

```lua
local AutoFarm = Section:AddToggle({Id="AutoFarm", Title="Auto farm"})
local FarmKey = AutoFarm:AddKeybind({
    Id="AutoFarmKey",
    Title="Auto farm shortcut",
    Default=Enum.KeyCode.F,
    Modifiers={"Ctrl", "Shift"},
    ExactModifiers=true,
    Whitelist={Enum.KeyCode.F, Enum.KeyCode.G},
    Mobile=true,
    MobileText="Toggle auto farm",
})

local overlay = UI:AddDraggableLabel({
    Text="Farm: idle",
    Icon="wheat",
    Position=UDim2.fromOffset(16, 80),
})
overlay:SetText("Farm: running")
```

`UI:AddDraggableButton()` and `UI:AddDraggableMenu()` expose the same
position/visibility/destroy handle contract. Keybinds also accept custom modes
and can attach to Buttons at construction or with `Attach()`.

### Custom controls

```lua
BobloUI:RegisterControl("ActionCard", function(section, options)
    return section:AddButton({Title=options.Title, Text=options.Text or "Run", Callback=options.Callback})
end)

local card = Section:AddCustom("ActionCard", {Title="Server Hop"})
```

## Configs

Enable configs by passing `ConfigFolder` to `CreateWindow`.

```lua
UI.Config:Save("Default")
UI.Config:Load("Default")
UI.Config:SetAutoLoad("Default")
```

Supported operations:

```text
List
Save / Load / Delete
Rename / Duplicate
Export / Import
SetAutoLoad / GetAutoLoad / LoadAuto
SetIgnored
RegisterMigration
```

Configs serialize Roblox values used by the controls, batch state restoration, preserve unknown/orphan values, and create a `.bak` before a migration. In Studio or environments without filesystem APIs, storage falls back to memory.

## Search and command palette

One surface handles controls, commands and tabs:

```text
walk        search controls
> save      commands
@farm       tabs
#default    config profiles
*esp        favorites
```

Open it with `Ctrl+K`, the header search button, or:

```lua
UI:OpenSearch("walk")
UI:OpenCommands()
```

Search indexes IDs, localized titles, descriptions, keywords and paths. Selecting a result reveals its tab/section and highlights the control. Hidden dependency-controlled results keep their dependency information instead of being forcibly shown.

Commands:

```lua
UI.Commands:Register({
    Id="config.save",
    Title="Save config",
    Keywords={"config","save"},
    Callback=function()
        UI.Config:Save("Default")
    end,
})
```

## Responsive layout

BobloUI separates viewport layout from input class:

```text
Wide    >= 1100px   sidebar + two section columns
Rail    700–1099px  compact icon rail + one column
Drawer  < 700px     mobile/off-canvas navigation + one column
```

`Device.Class` is `Phone`, `Tablet` or `Desktop`; `Device.Layout` is `Drawer`, `Rail` or `Wide`. Runtime viewport changes reparent layout containers instead of destroying controls, so state survives rotation/resizing.

On touch layouts, transient pickers use bottom sheets, controls use larger hit targets, and the hidden-window restore button prevents the UI from becoming unreachable without a keyboard.

## Themes, density and motion

```lua
UI:SetTheme("Light")
UI:SetTheme("Dark")
UI:SetAccent(Color3.fromRGB(90,140,255))
UI:SetDensity("Compact")
UI:SetScale(1.1)
UI:SetReducedMotion(true)
UI:SetHighContrast(true)
```

Themes update through a binding registry without rebuilding the UI. Metrics live in `Tokens`, not themes. Phone density is clamped to touch-safe hit sizes.

## Notifications and dialogs

```lua
UI.Notify:Push({
    Title="Saved",
    Content="Default.json",
    Variant="Success",
    Icon="save",
    Image="rbxassetid://OPTIONAL_IMAGE",
    AccentColor=Color3.fromHex("#8172F2"),
    Sound="Saved",
    Duration=4,
})

local dialog = UI.Dialog:Confirm({
    Title="Reset settings?",
    Content="This cannot be undone.",
    Danger=true,
})

if dialog:Await() then
    print("confirmed")
end
```

Dialogs return handles so they can also be resolved/closed programmatically.
`Dialog:Alert`, `Confirm`, `Prompt`, `Choice` and `Custom` are implemented.
Custom dialogs accept every canonical control and dynamic footer actions:

```lua
local dialog = UI.Dialog:Custom({
    Title="Deploy configuration",
    Description="Review the options before continuing.",
    OutsideClickDismiss=false,
    AutoDismiss=false,
    FooterButtons={
        cancel={Text="Cancel", Order=1},
        deploy={Text="Deploy", Variant="Primary", WaitTime=2, Order=2},
    },
    Build=function(content, handle)
        content:AddToggle({Title="Create backup", Default=true})
        content:AddDropdown({Title="Region", Options={"EU", "US"}, Default="EU"})
    end,
})

dialog:SetButtonDisabled("deploy", false)
dialog:AddFooterButton("later", {Text="Later", Close=false})
dialog:SetDescription("Ready to deploy.")
```

Notifications can be updated in place and expose `Progress` / `SetProgress()`
plus optional icon, large image, title/content colors and per-item sound.
See [docs/p1-p2-services.md](docs/p1-p2-services.md) for the complete container,
dialog, overlay, window, loading and keybind additions.

## Localization

```lua
UI.Locale:Register("de", {
    ["hub.farm"] = "Farm",
})

UI:SetLocale("de")
```

Strings can use localization keys supported by `Locale:Resolve`; changing locale refreshes registered UI text and reindexes search.

## Declarative / AI-generated UI

```lua
local handles = UI:Build({
    Tabs = {
        {
            Id="farm",
            Title="Farm",
            Sections={
                {
                    Title="Automation",
                    Controls={
                        {Type="Toggle", Id="AutoFarm", Title="Auto Farm", Default=false},
                        {Type="Slider", Id="Range", Title="Range", Min=10, Max=100, Default=50,
                         VisibleWhen={AutoFarm=true}},
                    },
                },
            },
        },
    },
})

handles.AutoFarm:SetValue(true)
UI:Get("Range"):Reveal()
```

`UI:Build` validates the complete descriptor before creating the first tab/control. It reports all structural, unknown-option, missing-required-option and type errors in one pass.

## AI artifacts

`build/manifest.json` is the source of truth. `npm run generate` creates:

```text
src/runtime/RuntimeManifest.lua   compact production validator data
src/schema/Manifest.lua          full generated manifest (tree-shaken from production)
api.json
schema.json
llms.txt
llms-full.txt
docs/*.md
src/runtime/Types.lua
```

This keeps runtime validation, docs and LLM instructions synchronized. The production bundler includes `RuntimeManifest` but tree-shakes the full documentation manifest.

## Architecture

```text
runtime  <-  kernel  <-  primitives  <-  controls  <-  shell  <-  services  <-  schema  <-  init
```

The bundler enforces downward-only dependencies and rejects cycles.

Key pieces:

- `runtime/Janitor` — cascading cleanup
- `runtime/Env` — executor capability abstraction
- `kernel/Store` — state + batching + dependency tracking
- `kernel/Input` — central input/keybind dispatcher
- `kernel/Layer` — Root / Overlay / Toast ScreenGui layers
- `kernel/Registry` — single Id index for State/Search/Config/Favorites/UI:Get
- `primitives/` — shared visual atoms
- `controls/Base` — control lifecycle/state/dependency contract
- `services/` — Config/Search/Commands/Dialogs/Notifications/etc.

## Window registry

Public usage is not a global singleton. Windows are keyed by `Id`:

```lua
BobloUI:CreateWindow({Id="my-hub",Title="Hub",Singleton=true})
```

Re-executing the same hub replaces only the previous window with that `Id`; another hub using BobloUI is not destroyed.

## Build and tests

```bash
npm test
```

Static CI verifies:

- generated artifacts are current
- no missing module dependencies
- no cyclic requires
- no upward layer dependencies
- exactly sixteen canonical constructors
- no deprecated constructor aliases
- full `Manifest` is tree-shaken from production
- compact `RuntimeManifest` is bundled
- AI rules/artifacts are generated

Roblox runtime tests live in `tests/`:

- `00-shell-smoke.lua` — window/theme/layout lifecycle
- `01-full-smoke.lua` — all controls, state, dependencies, declarative validation, search and config
- `02-all-features-smoke.lua` — responsive sections, theme editor, Settings, configs, Favorites, locale, window behavior, palette, dialogs, notification progress, sounds, navigation, extensions and declarative 0.10 contracts
- `leak.lua` — 200 controls followed by `Unload`, checking ScreenGui/window-registry cleanup

Replace `https://YOUR_CDN/...` in runtime tests with the hosted `dist/BobloUI.lua` URL.

## Intentionally outside the beta core

The public extension surface, custom icons and keyboard/gamepad navigation are already implemented. The remaining deliberate exclusions are:

- key-system/security gate (a client-side gate is not real protection)
- Recently Used unless real hub usage proves it adds value beyond Favorites/Search
- scroll virtualization for exceptionally large 800+ control pages unless profiling proves it is needed
- executable remote icon code or Roblox asset IDs; the pinned Lucide PNG atlases are data-only and hosted on GitHub with an asset-free fallback

## Release gate for 1.0

Before changing the version to `1.0.0`, run the runtime smoke tests in Studio and at least one desktop and one touch executor/device, then profile a 200-control hub for creation, scrolling, config load, theme switch and unload. After that, freeze constructor/options naming and use semver for breaking changes.

## 0.11 UI expansion

BobloUI 0.11 adds the richer shell/components requested after the 0.10 responsive foundation:

- `AddProgress`, `AddCode`, `AddImage`, `AddPassthrough`, `AddViewport`, `AddVideo`
- icons on normal controls via `Icon` / `IconColor`
- rich Dropdown items (`Title`, `Description`, `Icon`, `Locked`, `LockedReason`, per-item callback)
- array/dictionary `Options` or `Values`, runtime disabled/image maps and drag-select
- live Dropdown data sources and `BobloUI.Sources.Players()`
- multiline textarea inputs with configurable `Height`
- `Section:AddRow()` horizontal groups and `Section:AddTabBox()` sub-tabs
- locked Tabs
- Slider floating value, editable-value toggle and endpoint icons
- Toggle `Style="Checkbox"`
- custom topbar buttons/tags
- loading/boot overlay with icon, stage list, progress/error actions and optional control sidebar
- watermark and keybind HUD
- custom restore/open button
- window opacity/background image
- configurable tab and window transitions
- configurable notification position
- optional custom cursor
- dynamic dialog footer actions and dismiss policies
- draggable public label/button/menu overlays
- modifier/custom/mobile/attached keybinds
- persisted custom themes and default marker
- draggable sidebar width, compact/font controls and granular animation switches

### Rich dropdown

```lua
Section:AddDropdown({
    Id = "Mode",
    Title = "Mode",
    Searchable = true,
    Options = {
        {Value="safe", Title="Safe", Description="Recommended", Icon="check"},
        {Value="pro", Title="Pro", Description="Locked", Icon="lock", Locked=true, LockedReason="Unlock World 2"},
    },
})
```

For stable IDs with friendly labels, pass a dictionary through `Values`:

```lua
local Weapons = Section:AddDropdown({
    Id = "Weapon",
    Title = "Weapon",
    Values = {item01="Excalibur", item05="Aegis Shield"},
    Default = "item01",
})

Weapons:AddValues({item09="Nebula Cannon"})
```

### Live player source

```lua
Section:AddDropdown({
    Id = "TargetPlayer",
    Title = "Player",
    Source = BobloUI.Sources.Players({IncludeLocalPlayer=false}),
    Searchable = true,
    IgnoreConfig = true,
})
```

### Layout primitives

```lua
local Row = Section:AddRow({Columns=2})
Row:AddButton({Title="Rejoin", Text="Run"})
Row:AddToggle({Id="ESP", Title="ESP", Style="Checkbox"})

local Box = Section:AddTabBox({Title="Visual modes"})
local ESP = Box:AddTab({Id="esp", Title="ESP"})
ESP:AddToggle({Id="ESP.Enabled", Title="Enabled"})
```

### Shell extensions

```lua
UI:AddTopbarTag({Text="BETA"})
UI:AddTopbarButton({Icon="star", Callback=function() end})
UI:SetFooterText("My Hub · v1 · ready")
UI:SetWatermark("My Hub · v1")
UI:SetKeybindHUD(true)
UI:SetWindowOpacity(0.92)
UI:SetNotificationPosition("TopRight")
UI:SetRestoreButton({Icon="dashboard", Draggable=true, Shape="Rounded"})
```

## License

BobloUI is released under the [MIT License](LICENSE). It bundles a pinned
snapshot of the Lucide icon set (ISC) and its Roblox port (MIT); those notices
live in `vendor/lucide/` and in every generated bundle.
