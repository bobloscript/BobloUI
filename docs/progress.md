# Progress

Determinate or indeterminate progress bar.

Constructor: `AddProgress({...})`

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
- `Min`: number?
- `Max`: number?
- `Default`: number?
- `Suffix`: string?
- `ShowValue`: boolean?
- `Indeterminate`: boolean?
- `Format`: function?

## Specific methods
- `SetIndeterminate()` — Enable or disable indeterminate animation.
