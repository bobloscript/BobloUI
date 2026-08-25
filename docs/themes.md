# Theme palette contract

BobloUI bundles only `Dark` and `Light`. A custom theme passed to
`UI:RegisterTheme(name, palette)` needs **26 base `Color3` values** and one
numeric overlay-alpha value. Those are the only values a normal theme author
needs to choose.

| Group | Required tokens |
| --- | --- |
| Window | `Canvas`, `Background`, `Sidebar` |
| Surfaces | `Surface`, `SurfaceRaised`, `SurfaceInset`, `SurfaceSecondary`, `SurfaceHover`, `SurfaceActive` |
| Controls | `Control`, `ControlHover`, `ControlPressed`, `ControlInset` |
| Borders | `BorderSubtle`, `Border`, `BorderStrong` |
| Text | `Text`, `TextSecondary`, `TextTertiary`, `TextDisabled` |
| Brand | `Accent` |
| Status | `Success`, `Warning`, `Error`, `Info` |
| Overlay | `Scrim` (`Color3`), `ScrimTransparency` (`number`, 0–1) |

BobloUI computes interaction colors and readable foregrounds once when the
theme is applied: `AccentHover`, `AccentPressed`, `AccentSoft`, `AccentMuted`,
`AccentBorder`, `AccentGlow`, `SurfaceSheen`, `AccentButton`,
`AccentButtonHover`, `AccentButtonPressed`, `ErrorHover`, `ErrorPressed`,
`TextOnAccent`, `TextOnAccentButton`, `TextOnSuccess`, `TextOnWarning`,
`TextOnError` and `TextOnInfo`. `AccentText` remains as a deprecated alias for
`TextOnAccent` so older custom themes keep working. Advanced themes may
explicitly override any derived token.

Foreground selection uses WCAG relative luminance and chooses black or white
with the higher contrast. Primary, danger and status components use their exact
`TextOn*` token rather than sharing one accent foreground.

```lua
local CustomDark = {
	Canvas = Color3.fromHex("#080A0E"),
	Background = Color3.fromHex("#080A0E"),
	Sidebar = Color3.fromHex("#0B0E14"),
	ScrimTransparency = 0.52,
	-- Add the remaining required tokens from the table above.
}

UI:RegisterTheme("CustomDark", CustomDark)
UI:SetTheme("CustomDark")
```

To persist a palette between runs, use the per-window ThemeManager. It stores
custom palettes separately from Config profiles and keeps only `Dark` and
`Light` protected as built-ins. Saved custom themes store the base 26 colors
and scrim alpha; use `ExportTheme` / `ImportTheme` when derived-token overrides
must also travel with a profile.

```lua
local ok, err = UI:SaveCustomTheme("CustomDark", CustomDark)
if ok then
	UI:SetDefaultTheme("CustomDark")
	UI:LoadCustomTheme("CustomDark")
end

print(UI:GetDefaultTheme())
print(table.concat(UI:ListCustomThemes(), ", "))

UI:ReloadCustomThemes()
UI:DeleteCustomTheme("CustomDark")
```

`ThemeFolder` selects the storage namespace; otherwise BobloUI uses
`ConfigFolder` or the Window `Id`. `AutoLoadTheme=false` disables automatic use
of the saved default when no explicit `Theme` is passed to `CreateWindow`.
`UI:SetThemeFolder(folder)` switches that namespace at runtime, reloads its
custom theme files and validates its default marker.

Use `TextSecondary` for inactive icons: it must remain clearly visible on both
`Sidebar` and `Surface`. `Border` should remain visible on `Surface`, while
`BorderSubtle` is intended only for separators and quiet internal structure.
Every `SurfaceRaised` popover, dialog, tooltip or floating value bubble carries
a `Border`, which is required for the Light theme where raised surfaces may be
the same white as the containing surface.
