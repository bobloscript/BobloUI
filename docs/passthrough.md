# Passthrough

Host an existing Roblox GuiObject.

Constructor: `AddPassthrough({...})`

Stateful: **no**

## Options
- `Id`: string?
- `Title`: string?
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
- `Instance`: Instance — required
- `Height`: number?
- `Fill`: boolean?
- `Clone`: boolean?
- `DestroyInstance`: boolean?

## Specific methods
- `SetInstance()` — Replace hosted GuiObject.
- `GetContentInstance()` — Read hosted GuiObject.
- `SetHeight()` — Resize passthrough block.
