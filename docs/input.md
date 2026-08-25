# Input

Text or numeric input.

Constructor: `AddInput({...})`

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
- `Default`: string|number?
- `Placeholder`: string?
- `Numeric`: boolean?
- `MaxLength`: number?
- `Multiline`: boolean?
- `ClearOnFocus`: boolean?
- `ClearTextOnFocus`: boolean?
- `ClearTextOnBlur`: boolean?
- `AllowEmpty`: boolean?
- `EmptyReset`: string|number?
- `Validate`: function?
- `VerifyValue`: function?
- `Finished`: boolean?
- `CommitOn`: string?
- `Height`: number?

## Specific methods
- `Focus()` — Capture text focus.
- `Blur()` — Release text focus.
- `Clear()` — Reset to an empty string or zero.
- `SetAllowEmpty()` — Enable or disable empty values and optionally change the reset value.
- `SetError()` — Show or clear a validation error state.
