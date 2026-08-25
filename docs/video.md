# Video

VideoFrame control with playback API.

Constructor: `AddVideo({...})`

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
- `Video`: string — required
- `Looped`: boolean?
- `Playing`: boolean?
- `Volume`: number?
- `Height`: number?

## Specific methods
- `SetVideo()` — Replace video source.
- `SetLooped()` — Set looping.
- `SetPlaying()` — Set playback state.
- `SetVolume()` — Set volume.
- `Play()` — Start playback.
- `Pause()` — Pause playback.
- `SetHeight()` — Resize video.
