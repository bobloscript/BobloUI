# Keybind

Chord-capable keyboard/mobile binding with custom modes.

Constructor: `AddKeybind({...})`

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
- `Default`: any?
- `Mode`: string?
- `AllowedModes`: table?
- `Blacklist`: table?
- `Blacklisted`: table?
- `Whitelist`: table?
- `Whitelisted`: table?
- `Modifiers`: table?
- `DefaultModifiers`: table?
- `ModifierWhitelist`: table?
- `WhitelistedModifiers`: table?
- `ModifierBlacklist`: table?
- `BlacklistModifiers`: table?
- `BlacklistedModifiers`: table?
- `ExactModifiers`: boolean?
- `CustomModes`: table?
- `Modes`: table?
- `AttachTo`: any?
- `SyncToggle`: boolean?
- `SyncToggleState`: boolean?
- `WaitForCallback`: boolean?
- `ChangedCallback`: function?
- `Clicked`: function?
- `NoUI`: boolean?
- `Mobile`: boolean?
- `MobileText`: string?
- `ShowInHUD`: boolean?

## Specific methods
- `SetMode()` — Change Toggle/Hold/Always mode.
- `IsActive()` — Return current active state.
- `Capture()` — Capture the next key.
- `Cancel()` — Cancel key capture.
- `Focus()` — Alias of Capture for keyboard focus semantics.
- `SetKey()` — Set primary key and optional modifiers.
- `SetModifiers()` — Replace modifier chord.
- `GetModifiers()` — Read modifier chord.
- `Attach()` — Attach this binding to a control.
- `Trigger()` — Trigger from touch or code.
