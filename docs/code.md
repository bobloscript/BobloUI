# Code

Read-only code block with optional copy action.

Constructor: `AddCode({...})`

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
- `Code`: string?
- `Content`: string?
- `Language`: string?
- `Height`: number?
- `Copy`: boolean?

## Specific methods
- `SetCode()` — Replace displayed code.
- `GetCode()` — Read displayed code.
- `CopyCode()` — Copy code to clipboard when supported.
