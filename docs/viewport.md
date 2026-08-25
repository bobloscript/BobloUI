# Viewport

Interactive 3D ViewportFrame control.

Constructor: `AddViewport({...})`

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
- `Object`: Instance — required
- `Clone`: boolean?
- `DestroyObject`: boolean?
- `Camera`: Instance?
- `Interactive`: boolean?
- `AutoFocus`: boolean?
- `Height`: number?

## Specific methods
- `SetObject()` — Replace displayed 3D object.
- `SetCamera()` — Replace viewport camera.
- `SetInteractive()` — Enable orbit and zoom.
- `SetHeight()` — Resize viewport.
- `Focus()` — Focus camera on object bounds.
