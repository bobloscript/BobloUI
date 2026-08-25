# Paragraph

Rich explanatory text; omit Title for label-like text.

Constructor: `AddParagraph({...})`

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
- `Content`: string?
- `Variant`: string?
- `RichText`: boolean?
- `DoesWrap`: boolean?
- `Wrap`: boolean?
- `Size`: number?

## Specific methods
- `SetContent()` — Replace paragraph content.
- `SetRichText()` — Enable or disable Roblox RichText rendering.
- `SetWrap()` — Enable or disable text wrapping.
- `SetSize()` — Set a manual content text size or restore the theme size.
