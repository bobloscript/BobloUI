# Slider

Numeric slider.

Constructor: `AddSlider({...})`

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
- `Min`: number — required
- `Max`: number — required
- `Default`: number?
- `Step`: number?
- `Precision`: number?
- `Rounding`: number?
- `Prefix`: string?
- `Suffix`: string?
- `Format`: function?
- `FormatDisplayValue`: function?
- `ValueInput`: boolean?
- `AllowRightClickInput`: boolean?
- `FloatingValue`: boolean?
- `Compact`: boolean?
- `HideMax`: boolean?
- `IconFrom`: string?
- `IconTo`: string?

## Specific methods
- `SetMin()` — Change the minimum and clamp the current value.
- `SetMax()` — Change the maximum and clamp the current value.
- `SetStep()` — Change the numeric step.
- `SetPrefix()` — Change the displayed prefix.
- `SetSuffix()` — Change the displayed suffix.
