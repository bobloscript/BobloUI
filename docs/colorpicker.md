# ColorPicker

Color selector with HEX/RGB entry.

Constructor: `AddColorPicker({...})`

Stateful: **yes**

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
- `Default`: Color3?
- `Alpha`: boolean?
- `DefaultAlpha`: number?
- `Presets`: table?

## Specific methods
- `Open()` — Open the picker.
- `Close()` — Close the picker.
- `SetAlpha()` — Set alpha from 0 to 1 when Alpha is enabled.
- `GetAlpha()` — Read alpha.
