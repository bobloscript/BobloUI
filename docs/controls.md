# Controls

There are exactly sixteen constructors and no aliases. This page explains what
each one is for and how to use it; the generated pages (`button.md`,
`toggle.md`, …) list every option with its type.

## Options every control shares

These work on all sixteen:

| Option | Purpose |
| --- | --- |
| `Id` | Binds the control to State, search, configs and Favorites. Omit it and the control is invisible to all four. |
| `Title` | The label. Required on most controls. |
| `Description` | Secondary line under the title. |
| `Keywords` | Extra search terms that are not in the title. |
| `Icon` / `IconColor` | Leading icon; see [icons.md](icons.md). |
| `Badge` | Small text marker, e.g. `"NEW"`. |
| `Tooltip` | String or function shown on hover/long-press. |
| `Disabled` | `true`, or a string that is shown as the reason. |
| `Visible` / `VisibleWhen` | Static or reactive visibility. |
| `EnabledWhen` | Reactive disabled state. |
| `IgnoreConfig` | Excludes the value from save/load. |
| `Order` | Sort position within the section. |
| `Callback` | Fires on value change or activation. |
| `ContextMenu` | Extra right-click/long-press entries. |
| `Adaptive` | Lets the control stack its label and field when narrow. |

Passing `Disabled = "Unlock World 2"` rather than `Disabled = true` is worth the
extra few characters — the string surfaces to the player as the reason instead
of leaving them staring at a dead control.

And the handle every control returns:

```
GetValue / SetValue        SetTitle / SetDescription / SetKeywords
SetVisible / IsVisible     SetDisabled / IsDisabled
SetLoading                 SetBadge
Reset / CopyValue / PasteValue
Highlight                  Reveal
OnChanged                  GetInstance                 Destroy
```

Presentation-only controls expose the meaningful subset plus their own methods.

## Button

An action, not a value. Nothing is stored, nothing is restored from a config.

```lua
Section:AddButton({
    Title = "Rejoin server",
    Text = "Run",
    Callback = function() rejoin() end,
})
```

For anything destructive, make the player confirm rather than trusting a steady
hand:

```lua
Section:AddButton({
    Title = "Reset all settings",
    Text = "Reset",
    Risky = true,
    Confirm = "This cannot be undone.",
    Callback = function() wipe() end,
})
```

`DoubleClick` is the lighter alternative when a dialog is too heavy.
`SubButtons` and `Actions` add secondary actions to the same row, and
`AddKeybind()` attaches a shortcut directly to the button.

## Toggle

The workhorse. Stateful, so give it an `Id`.

```lua
local esp = Section:AddToggle({
    Id = "ESP",
    Title = "ESP",
    Default = false,
    Callback = function(on) setEsp(on) end,
})

esp:Flip()
```

`Style = "Checkbox"` renders a checkbox instead of a switch — useful when a row
holds several related booleans and switches would look heavy.

## Slider

```lua
Section:AddSlider({
    Id = "WalkSpeed",
    Title = "Walk speed",
    Min = 16,
    Max = 200,
    Default = 16,
    Step = 1,
    Suffix = " sps",
    ValueInput = true,
})
```

`Min` and `Max` are required alongside `Title`. `Step` controls the increment,
`Precision`/`Rounding` control display, and `ValueInput` lets the player type an
exact number instead of dragging — worth enabling on any range wider than about
a hundred, where dragging cannot hit a specific value.

`Format` takes a function if a suffix is not enough:

```lua
Format = function(value) return string.format("%.1f×", value) end,
```

## Dropdown

The most configurable control, and the one whose options are most often
confused. There are two ways to supply choices.

An array through `Options`, where the value *is* the label:

```lua
Section:AddDropdown({
    Id = "Mode",
    Title = "Mode",
    Options = {"Safe", "Balanced", "Aggressive"},
    Default = "Safe",
})
```

A dictionary through `Values`, where the key is a stable identifier and the
value is the label shown to the player:

```lua
Section:AddDropdown({
    Id = "Weapon",
    Title = "Weapon",
    Values = {item01 = "Excalibur", item05 = "Aegis Shield"},
    Default = "item01",
})
```

Use `Values` whenever the label might change — renaming a display string then
does not invalidate every saved config, which `Options` would.

`Multi = true` turns either form into multi-select. With `Values`, the selection
comes back as a map:

```lua
print(modes:GetValue().Legit) -- true
```

Rich items carry their own description, icon and lock state:

```lua
Options = {
    {Value = "safe", Title = "Safe", Description = "Recommended", Icon = "check"},
    {Value = "pro", Title = "Pro", Icon = "lock", Locked = true, LockedReason = "Unlock World 2"},
},
```

For lists that change while the UI is open, pass a `Source` instead of managing
`SetOptions` yourself:

```lua
Source = BobloUI.Sources.Players({IncludeLocalPlayer = false}),
IgnoreConfig = true,
```

Always pair a live source with `IgnoreConfig` — restoring a player name from
last week's session is meaningless.

Add `Searchable = true` past roughly fifteen entries.

## Input

```lua
Section:AddInput({
    Id = "WebhookUrl",
    Title = "Webhook",
    Placeholder = "https://...",
    MaxLength = 200,
    CommitOn = "Focus",
    Validate = function(text)
        if not string.match(text, "^https://") then
            return false, "Must start with https://"
        end
        return true
    end,
})
```

`CommitOn` decides when the callback fires — on every keystroke or when the
field loses focus. For anything that triggers network calls or heavy work,
commit on focus loss. `Numeric = true` restricts to numbers, `Multiline` with
`Height` gives a textarea, and `Validate` returning `false, reason` shows the
reason inline.

## Keybind

```lua
local farmKey = autoFarm:AddKeybind({
    Id = "AutoFarmKey",
    Title = "Auto farm shortcut",
    Default = Enum.KeyCode.F,
    Modifiers = {"Ctrl", "Shift"},
    ExactModifiers = true,
    Mobile = true,
    MobileText = "Toggle auto farm",
})
```

Attached to a toggle like this, the key flips the toggle. Standalone, it calls
its own callback. `Mode` selects between hold, toggle and always semantics, and
`CustomModes` adds your own. `Whitelist`/`Blacklist` constrain which keys the
player may pick — blacklist the keys your hub already uses.

`Mobile = true` puts a labelled button in the touch HUD, since a phone has no
keyboard. Without it the binding is unreachable on touch devices.

## ColorPicker

```lua
Section:AddColorPicker({
    Id = "EspColor",
    Title = "ESP colour",
    Default = Color3.fromRGB(120, 200, 255),
    Alpha = true,
    Presets = {Color3.new(1, 0, 0), Color3.new(0, 1, 0)},
})
```

With `Alpha = true` the transparency is a separate channel — read it with
`GetAlpha()`, not from the `Color3`.

## Paragraph and Divider

Explanatory text and separators. `Paragraph` without a `Title` is the plain
label primitive; there is no `AddLabel`.

```lua
Section:AddParagraph({
    Content = "Auto farm pauses automatically while you are in combat.",
})

Section:AddDivider({Text = "Advanced"})
```

`RichText = true` enables Roblox markup inside `Content`.

## Status and Progress

`Status` is read-only and never persisted, even with an `Id` — it exists to
mirror something your script computes.

```lua
local status = Section:AddStatus({Id = "FarmStatus", Title = "State", Value = "idle"})
status:SetValue("running")
```

`Progress` covers both determinate and indeterminate work:

```lua
local bar = Section:AddProgress({Id = "Loading", Title = "Loading", Min = 0, Max = 100})
bar:SetValue(40)
bar:SetIndeterminate(true) -- unknown duration
```

## Code

A read-only block with an optional copy button — for showing a key, an ID or a
snippet the player needs to paste elsewhere.

```lua
Section:AddCode({
    Code = "MyHub-8f2a-4c11",
    Language = "text",
    Copy = true,
})
```

## Image, Passthrough, Viewport, Video

The four media controls. All take Roblox content, not URLs.

```lua
Section:AddImage({Image = "rbxassetid://123456789", Height = 120, Caption = "Map"})

Section:AddPassthrough({Title = "Custom UI", Instance = myFrame, Clone = true, Height = 56})

Section:AddViewport({Title = "Preview", Object = workspace.ItemModel, Clone = true, Interactive = true})

Section:AddVideo({Title = "Tutorial", Video = "rbxassetid://987654321", Looped = true, Volume = 0.5})
```

Ownership is the thing to get right on `Passthrough` and `Viewport`. With
`Clone = true` the control works on a copy and your original is untouched. With
`Clone = false` it uses your instance directly and restores it on destroy —
pass `DestroyInstance`/`DestroyObject = true` only if the control should own and
destroy it. Getting this wrong shows up as your source model disappearing from
the workspace when a tab is rebuilt.

## Layout

`Row` places controls side by side; `TabBox` nests sub-tabs inside a section.

```lua
local row = Section:AddRow({Columns = 2})
row:AddButton({Title = "Rejoin", Text = "Run"})
row:AddToggle({Id = "ESP", Title = "ESP", Style = "Checkbox"})

local box = Section:AddTabBox({Title = "Visual modes"})
local esp = box:AddTab({Id = "esp", Title = "ESP"})
esp:AddToggle({Id = "ESP.Enabled", Title = "Enabled"})
```

Both accept `VisibleWhen` and `EnabledWhen`, so a whole group can appear and
disappear as one.

## Custom controls

When a pattern repeats across your hub, register it once:

```lua
BobloUI:RegisterControl("ActionCard", function(section, options)
    return section:AddButton({
        Title = options.Title,
        Text = options.Text or "Run",
        Callback = options.Callback,
    })
end)

local card = Section:AddCustom("ActionCard", {Title = "Server hop"})
```

The factory receives the section and your options table and returns a control
handle. This composes existing controls rather than drawing new ones — for
genuinely new visuals, see [extending.md](extending.md).
