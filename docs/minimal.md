# Minimal window

Use `Presentation = "Minimal"` for scripts with a short list of controls. It is
an opt-in presentation of the same BobloUI window: existing Tab, Section,
controls, Store and Config work without separate implementations.

```lua
local UI = BobloUI:CreateWindow({
    Id = "small-hub",
    Title = "Small Hub",
    Icon = "zap",
    Presentation = "Minimal",
})

local Main = UI:AddTab({ Id = "main", Title = "Main" })
Main:AddToggle({ Id = "AutoFarm", Title = "Auto Farm", Style = "Checkbox" })
Main:AddSlider({ Id = "Delay", Title = "Delay", Min = 0, Max = 2, Default = 0.5 })
```

See [the complete example](../examples/minimal.lua).

The window defaults to 340 logical pixels wide and follows the visible content
height. It stops growing at 72% of the safe viewport height and scrolls beyond
that. `Size = UDim2.fromOffset(320, 300)` sets the width and a 300-pixel height
**limit**, not a fixed height. Use `SetSize()` to update the limit at runtime.

The sidebar, footer, and resize grip are hidden. For multiple tabs, the chevron
in the header opens the tab list; the built-in Settings tab is included when
enabled. One section omits its heading unless it is collapsible. Multiple
sections show compact headings. Explicit Grid sections stack in this narrow
presentation. Toggles default to checkboxes in Minimal and can be switched by
tapping their whole row. An explicit `Style = "Switch"` retains the switch style.

`Presentation = "Standard"` (the default) retains the existing window. The
`Compact` option only changes control density and can be used independently.
`Presentation` is chosen when creating the window; to change it, create a new
window. Keep the same `Id` and `ConfigFolder` to retain saved values.
