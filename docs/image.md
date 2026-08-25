# Image

Image/media block using Roblox asset content.

Constructor: `AddImage({...})`

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
- `Image`: string — required
- `Height`: number?
- `Caption`: string?
- `ScaleType`: EnumItem?
- `Tint`: Color3?
- `ImageColor3`: Color3?
- `Transparency`: number?
- `ImageTransparency`: number?
- `BackgroundTransparency`: number?
- `RectOffset`: Vector2?
- `RectSize`: Vector2?
- `ImageRectOffset`: Vector2?
- `ImageRectSize`: Vector2?

## Specific methods
- `SetImage()` — Replace image asset.
- `SetCaption()` — Replace caption.
- `SetHeight()` — Resize image block.
- `SetTint()` — Set image tint.
- `SetTransparency()` — Set image/background transparency.
- `SetRect()` — Set sprite rectangle.
- `SetScaleType()` — Set ScaleType.
