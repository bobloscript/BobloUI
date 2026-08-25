# Status

Read-only live status indicator; may read State by Id but is never persisted.

Constructor: `AddStatus({...})`

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
- `Value`: any?
- `Status`: string?
- `Pulse`: boolean?

## Specific methods
- `SetStatus()` — Change Neutral/Success/Warning/Error/Info/Pending state.
