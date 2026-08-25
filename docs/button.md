# Button

Action button.

Constructor: `AddButton({...})`

Stateful: **no**

## Options
- `Id`: string?
- `Title`: string? — required
- `Description`: string?
- `Keywords`: table?
- `Badge`: string?
- `Disabled`: boolean|string?
- `Visible`: boolean?
- `VisibleWhen`: table|function?
- `EnabledWhen`: table|function?
- `IgnoreConfig`: boolean?
- `Order`: number?
- `Callback`: function?
- `Tooltip`: string|function?
- `ContextMenu`: table?
- `Adaptive`: boolean?
- `Icon`: string?
- `IconColor`: string|Color3?
- `Text`: string?
- `Variant`: string?
- `Confirm`: string?
- `Risky`: boolean?
- `DoubleClick`: boolean?
- `DoubleClickWindow`: number?
- `SubButtons`: table?
- `Actions`: table?

## Specific methods
- `Click()` — Programmatically invoke the button action.
- `AddAction()` — Append an attached sub-action button.
- `AddKeybind()` — Attach a Keybind control to this button.
