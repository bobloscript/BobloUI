# BobloUI implementation status

Version: `0.11.5-beta.1`

## Implemented

- Modular Luau source with strict dependency layers, bundler, reachability/tree-shaking and generated AI artifacts.
- Sixteen canonical controls: Button, Toggle, Slider, Dropdown, Input, Keybind, ColorPicker, Paragraph, Divider, Status, Progress, Code, Image, Passthrough, Viewport and Video.
- Queue-drained synchronous State store, batching, owner-aware watchers, settled `WatchMany`, Store-level `VisibleWhen` / `EnabledWhen` tracking and clean dynamic destruction.
- Responsive Window layouts: Wide / Rail / Drawer, safe-area handling, touch drawer, resize, minimize/restore, lock and remembered geometry.
- P3 Window tuning: search visibility/width/scope, mobile restore-button side,
  sidebar compact/snap thresholds and configurable tab transition motion.
- Smart section layout: `Span = "Auto" | 1 | 2`, automatic two-column fallback, `Layout = "Stack" | "Grid" | "Auto"`, and adaptive controls that stack fields when a card becomes too narrow.
- Themes: Dark and Light presets; persisted custom 26-color + scrim-alpha theme library/default; WCAG-derived foregrounds; complete primary/danger interaction states; arbitrary accent; typed token overrides; high contrast; import/export; runtime theme switching.
- Scale and density controls: Compact / Comfortable / Touch plus runtime `UIScale`.
- Built-in Settings center: appearance, theme editor, localization, accessibility, window preferences, config profiles, Favorites and Keybind manager.
- Config profiles with save/load/autoload/rename/duplicate/delete/import/export, migrations/backups, orphan preservation and UI-preference persistence.
- Favorites / pinned controls and palette provider.
- Indexed, debounced Search + Command Palette with `>` commands, `@` tabs, `#` config profiles and `*` favorites.
- Notifications with update/progress plus per-item icons, images, colors and sounds.
- Alert / Confirm / Prompt / Choice / Custom dialogs; Custom has all controls, dismiss policies, dynamic footer actions and timed locks.
- Public draggable Label/Button/Menu overlays with mutable handles and deterministic cleanup.
- Chord keybinds with modifiers, whitelist/blacklist, custom modes, Button/Toggle attachment and mobile HUD actions.
- Reactive `VisibleWhen` / `EnabledWhen` on Section, Row and TabBox, including child disabled-state propagation.
- Runtime sidebar width/dragging, compact mode, font replacement and independent Window/Tab/Control animation categories.
- Tooltips, disabled reasons, context menus, Reset/Copy/Paste value actions and long-press support.
- Built-in EN/RU/ES system locale packs plus custom runtime locale registration.
- Keyboard navigation (Tab / Shift+Tab / arrows / Enter) and gamepad navigation (D-pad / A / B).
- Optional UI sound registry with global enable/volume controls; no third-party audio assets are bundled.
- Tab groups and segmented selection through `AddDropdown({Style="Segmented"})`.
- P3 control parity: Input empty/reset/blur policies, Slider prefix/compact/max and
  right-click editing, Paragraph RichText/size/wrap, Divider margins, and map-mode
  dictionary multi-dropdowns with backward-compatible array behavior.
- Custom icon registry and public custom-control extension API (`BobloUI:RegisterControl`, `Section:AddCustom`).
- Desktop Popovers and touch bottom Sheets with safe-area, on-screen keyboard and swipe-to-dismiss handling.
- Declarative `UI:Build()` with full prevalidation and support for tab Group/Description and section Span/Layout.
- AI artifacts generated from one manifest: `api.json`, `schema.json`, `llms.txt`, `llms-full.txt`, docs and Luau option types.

## Verification

`npm test` parses every source module through Lua 5.3 lowering, executes the headless Store behavior spec, performs the production build, and checks dependency cycles/layers, generated artifacts, tree-shaking, canonical API and the P0/P1/P2/P3 hardening contract. CI also enforces `stylua --check src`.

Roblox services (`GuiService`, `UserInputService`, `CoreGui`, touch keyboard and executor filesystem/clipboard APIs) cannot be emulated in this build container. `tests/00-shell-smoke.lua`, `tests/01-full-smoke.lua`, `tests/02-all-features-smoke.lua` and `tests/leak.lua` are included for final in-client validation before declaring `1.0.0` stable.

## Still intentionally outside 1.0 scope

- Scroll virtualization for exceptionally large 800+ control pages unless profiling proves it is needed.
- Security/key-system claims: a client-only key gate is not real security and is intentionally not part of the core library.
- Recently Used surface unless real hub usage shows value over Favorites/Search.


## 0.11 expansion

Implemented: Progress/Code/Image/Passthrough/Viewport/Video, rich Dropdown/data sources, textarea, control icons, topbar extensions, staged loading with control sidebar, Row/HStack, reactive TabBox, locked tabs, slider enhancements, checkbox toggle, restore button customization, opacity/background image, transitions, notification placement/media, draggable overlays, HUDs and custom cursor.
