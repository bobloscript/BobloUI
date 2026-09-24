# Unreleased

- Stabilized window dragging on desktop and touch devices: pointer capture now
  follows only the mouse button or finger that began the drag, active window
  position tweens are cancelled before manual movement, and the window remains
  clamped to the current safe area.
- Added a manual drag regression smoke covering animation, scale changes and
  multi-touch input.
- Custom themes now take part in light/dark switching. Every palette has an
  appearance polarity, derived from `Canvas` luminance and overridable with
  `Appearance = "Dark" | "Light"`; an optional `Pair` names an explicit
  counterpart. Both fields are metadata rather than colour tokens and survive
  save/load.
- The header theme button and the `ui.theme` command now resolve their target
  through `Theme:Counterpart()` instead of hardcoding Dark/Light. The library
  remembers the last theme used at each polarity and persists it, so toggling
  away from a custom theme and back returns to that theme rather than a built-in.
- Deleting the active custom theme now falls back to the built-in of the same
  polarity; a deleted light theme no longer drops the user into a dark UI.
- The Settings theme picker labels which polarity each theme belongs to.
- Added `Theme:Polarity()`, `Theme:Counterpart()`, `Theme:RecentByPolarity()`
  and `Theme:RememberPolarity()`.
- Added `tests/theme.spec.lua` and a Color3 shim to the headless harness, wired
  in as `npm run test:theme`.

# 0.11.5-beta.1

- Hardened the release theme contract: 26 author-selected colors plus numeric
  `ScrimTransparency`, WCAG-derived foregrounds for accent/status surfaces,
  state-specific primary/danger hover and press colors, and the deprecated
  `AccentText` compatibility alias.
- Removed component-level scrim constants; live modal backdrops now bind to the
  active theme's `Scrim` and `ScrimTransparency` tokens.
- Added a real border to every audited raised floating surface in Light,
  including the Slider value bubble.
- Completed P3 from the official Obsidian gap audit: Input empty/blur policies,
  Slider display/editing options, Paragraph RichText/size/wrapping, Divider
  margins, dictionary multi-dropdown maps and low-level responsive Window tuning.
- Preserved the historical numeric Input contract: `Clear()` returns `0` unless
  `AllowEmpty=true` or a custom `EmptyReset` policy is explicitly selected.
- Dictionary `Values` multi-dropdowns now return `{[key] = true}` maps by default;
  classic `Options` multi-dropdowns retain ordered arrays, with safe cross-format
  conversion during `SetValue` and config loading.
- Added configurable search width/scope, mobile restore-button side, sidebar
  compaction thresholds and tab transition duration/distance/direction.
- Completed every P1/P2 item from the official Obsidian documentation gap audit while preserving BobloUI's own Dark/Light visual system.
- Added `AddPassthrough`, interactive `AddViewport` and `AddVideo`, bringing the canonical control count to 16 across Tab, Section, Row, TabBox and DialogSection containers.
- Added reactive `VisibleWhen` / `EnabledWhen` to Section, Row and TabBox with shared Store tracking and child disabled-state propagation.
- Upgraded Custom dialogs with all controls, outside/automatic dismissal policies, dynamic footer add/remove/order/disable, `WaitTime`, and runtime title/description mutation.
- Added public draggable Label, Button and Menu overlays.
- Upgraded keybinds with modifier chords, exact matching, whitelist/blacklist, custom modes, Button/Toggle attachment and actionable mobile HUD entries.
- Added persisted custom-theme save/list/load/delete/reload/default APIs and Settings integration while keeping Dark and Light as the only bundled presets.
- Added runtime sidebar width and drag-resize, explicit compact mode, runtime font replacement and independent Window/Tab/Control motion categories.
- Expanded Image with tint/transparency/sprite rectangles, Loading with stages/icon/control sidebar, and Notifications with per-item image/icon/color/sound.
- Expanded Button with risky confirmation, double-click, sub-actions and attached keybinds; expanded Dropdown with drag multi-select, row limits, formatters, disabled maps and image maps.
- Reduced bundled theme presets to Dark and Light while retaining custom theme registration and legacy Midnight/OLED config fallback to Dark.
- Removed the outer window shadow, made corner radius reach every visible shell layer, and strengthened the real root border.
- Added `FooterText` / `SetFooterText()` / `GetFooterText()` and redesigned the resize affordance so it stays fully inside the footer.
- Increased inactive navigation icon contrast and made section borders uniform, rounded and inset from clipping edges.
- Reworked the default visual language with a deeper dark palette, layered surfaces, section header cards, accent rails, icon tiles and softer primary actions.
- Vendored a pinned 1,756-icon Lucide atlas, its two source spritesheets and complete ISC/MIT notices; no Roblox asset IDs or third-party runtime code are required.
- Added a BobloScript GitHub PNG provider with format/size validation, executor-local cache and custom-asset registration.
- Added `Icon.List`, `Icon.Has`, `Icon.Resolve`, `Icon.RegisterAlias`, `Icon.SetAtlasUrls`, `Icon.GetAtlasUrls`, `Icon.Prepare`, `Icon.Retry` and `Icon.GetStatus`; names accept spaces, hyphens or underscores and custom registered icons keep priority.
- Kept the asset-free GuiObject glyphs as a deliberate fallback for unavailable executor capabilities, network failures and unknown icon names.
- Added `Icon` and `SetIcon()` to Sections, including declarative schema/build support, plus richer hover, focus and press feedback across controls.
- Replaced recursive State propagation with a guarded FIFO drain; cascade errors now include the key chain and escape watcher dispatch.
- Added Store-level dependency tracking, owner-aware watchers, settled once-per-drain `WatchMany`, cycle-safe table equality and mutable-table change detection.
- Config saves now merge unknown file data, fail on missing migrations, preserve disabled/zero settings and keep autoload consistent across delete/rename.
- Duplicate IDs are rejected before Tab, Section or control construction can leave partial state or Instances behind.
- Replaced per-control `CanvasGroup`/`AbsoluteSize` work with lightweight Frames and section-level adaptive layout delegation.
- Added an incremental lowercase Search index, registry-driven reindexing and 75 ms palette debounce.
- Split the Window shell into `Window`, `Tab`, `WindowChrome` and `WindowLayout` modules; `Common` now remains separate in `RuntimeManifest`.
- Added Lua parser coverage for all source modules, a headless Store behavior spec, a P0/P1/P2 static contract and StyLua enforcement to CI.
- Formatted all of `src/` with StyLua and fixed generated Luau optional-field syntax (`Id: string?`).
- Reworked hide/show behavior after studying Rayfield's current visibility flow.
- Watermark remains fully opt-in and is never created by default.
- Default restore prompt is now touch/mobile-only and remains hidden while the main window is visible.
- On mobile, hiding the UI shows a compact top-center `Show <Title>` prompt; showing the UI dismisses it.
- Desktop defaults to the toggle key and does not leave a floating reopen button on screen.
- Added `ShowText` and Rayfield-compatible `ToggleUIKeybind` window options while keeping legacy `ToggleKey`.
- String toggle keys are matched case-insensitively against `Enum.KeyCode`.
- Explicit `RestoreButton` configuration still supports always-available custom reopen buttons when developers want them.
- Updated showcase/smoke scripts so watermark and keybind HUD do not linger during normal tests.

# Changelog


## 0.10.4-beta.1 — Symmetric page padding regression fix

- Fixed SectionHost relayout accidentally replacing `Size.X = 1, -(PagePadding*2)` with `1, 0`.
- Right-side page padding now remains identical to the left-side page padding after every section height/layout update.
- Added a static regression check that every SectionHost height assignment preserves horizontal padding.

## 0.10.3-beta.1 — Scale-aware layout + real window rounding

- Fixed section/container overflow when UI scale is above or below 100% by converting scaled `AbsoluteSize` values back to logical pixels before laying out sections.
- Fixed resize math and safe-area clamping under `UIScale`; dragging the resize handle no longer double-applies scale.
- Added a hard clip guard on the section host so a section can never draw outside the page content bounds.
- Window corner radius now affects the visible header/footer surfaces as well as the root border, so the setting is actually visible.
- Replaced the crooked three-slash resize mark with a crisp bottom-right corner grip.
- Adaptive Section/Grid/Control breakpoints are now scale-aware.
- `SetScale()` immediately reapplies safe geometry and section layout.

## 0.10.2-beta.1 — Compile fix + window polish

- Fixed invalid Luau method-reference syntax in Settings (`w:GetCornerRadius and` -> `w.GetCornerRadius and`).
- Added visible footer resize affordance and bottom-right drag grip.
- Added sidebar hide/show toggle and public sidebar visibility API.
- Added configurable window corner radius.
- Replaced the theme toggle glyph with a sun-style icon.
- Hardened tooltip rendering against function/table values.
- Changed two-column section placement to row-safe layout so cards cannot overlap beneath the opposite column.
- Added a static guard for colon-method references used as boolean values.


## 0.10.1-beta.1 — Runtime regression fixes

- fixed Choice dialog option buttons inheriting full parent height and escaping the dialog; choices are now 34px rows, full-width, and scroll when necessary
- desktop dialog surfaces now clamp to the live viewport and clip as a final overflow guard
- replaced paired-row section placement with two-column masonry so a tall section no longer creates a large vertical hole under the shorter neighboring section
- `Span = 2` remains a full-width synchronization barrier; a single `Span = "Auto"` section still expands to full width
- sidebar icons now derive from the active accent in both selected and unselected states (`Accent` / `AccentMuted`) and refresh after runtime theme/accent changes
- keybind capture no longer fails just because Roblox marks the key as game-processed
- active keybinds now continue to work when the game consumes the same key, while remaining suppressed whenever a TextBox/chat field has keyboard focus
- starting a second key capture cleanly cancels the first instead of leaving the first control stuck on `Press a key…`
- keybind capture cleanup no longer leaves stale capture callbacks in the control Janitor
- public API unchanged

## 0.10.0-beta.1

- added Midnight theme preset

- Smart section spans and responsive control stacking.
- Built-in Settings center with theme editor, scale/density, configs, favorites, keybinds, localization and window preferences.
- Arbitrary theme token overrides, OLED preset, high contrast, theme import/export.
- Window lock/geometry APIs and config persistence for UI preferences.
- Tab groups, segmented dropdown style, reset/copy context actions, Choice dialogs, config/favorite palette providers, custom control registration.

- Section `Layout = Stack | Grid | Auto` and adaptive field stacking for narrow cards.
- Keyboard and gamepad focus navigation.
- Optional user-disableable UI sound registry and sound volume preference.
- Clipboard paste for compatible values when the environment exposes clipboard read.
- Notification progress bars / `SetProgress()`.
- Header minimize action and persisted accessibility/sound preferences.
- Declarative schema now includes tab groups/descriptions and section span/layout fields.


## 0.9.5-beta.1 — Responsive layout hardening V6

- fixed two-column section overflow caused by full-width page children combined with horizontal UIPadding
- page intro, empty state and section host now use explicit horizontal content bounds
- section columns are sized from real SectionHost AbsoluteSize with exact gap subtraction
- Wide pages automatically fall back to one column when the actual window content is too narrow
- fallback is driven by the live window/content width, not only the global viewport category
- resize, density and viewport changes relayout sections through property-change/deferred events, never RenderStepped
- content and scrolling pages clip descendants as a visual safety net; real overlays remain in Layer.Overlay
- resize grip is clamped to the current safe area so the window cannot temporarily grow past the viewport
- Section roots use stable LayoutOrder so two-column -> one-column transitions preserve declaration order
- public API unchanged

## 0.9.4-beta.1 — Overlay polish V5

- compact, content-sized desktop Command Palette with search icon, ESC affordance, empty states and keyboard footer
- dynamic palette height instead of a fixed 430px empty modal
- content-sized dropdown popovers with smaller rows, tighter radius and trigger-aware width
- Popover now supports runtime resizing/repositioning for filtered dropdown results
- compact context menus with hover states and optional vector icons
- smaller tooltips with wrapped sizing, subtle border and faster hover delay
- dialogs now size to their content and use the same field/button language as the main UI
- desktop ColorPicker popover reduced substantially while keeping HSV, HEX/RGB, alpha and presets
- notifications tightened to 320px with vector close controls and lighter overlay borders
- mobile sheets inherit the lighter overlay stroke/grab treatment
- public API and state/config/search contracts unchanged

## 0.9.3-beta.1 — Visual polish V4

- replaced sidebar letter/glyph placeholders with built-in vector-style GuiObject icons
- softened selected-tab treatment and tightened navigation spacing
- increased body/description readability and refined responsive metrics
- reduced section/card contrast and separator weight
- toned down primary action buttons while keeping accent states clear
- refined toggle, slider, field borders and control proportions
- grouped status dot/value into one compact status readout
- replaced dropdown/collapse Unicode chevrons and checks with vector icon primitives
- increased desktop column gap and polished header action states
- public API and state/config/search contracts unchanged

## 0.9.0-beta.1

- Added synchronous State store with batching, watchers and dependency auto-tracking.
- Added central input dispatcher, keybind registry and reduced-motion Motion service.
- Added Registry and globally unique control IDs.
- Added primitives and ten canonical controls.
- Added lazy Tab/Section mounting and Wide/Rail/Drawer responsive section layouts.
- Added desktop popovers and mobile sheets.
- Added Config storage, profiles, autoload, import/export and migrations.
- Added unified Search/Command/Tab palette and Favorites.
- Added notifications, dialogs, tooltips and context menus.
- Added localization and runtime locale switching.
- Added declarative `UI:Build()` with full pre-validation.
- Added generated RuntimeManifest, full Manifest, API JSON, JSON Schema, LLM docs and Luau option types.
- Added reachability/tree-shaking to the production bundler.
- Added per-window singleton registry instead of a global BobloUI singleton.
- Added full smoke and 200-control unload tests for Roblox runtime validation.

## 0.9.2-beta.1 — Visual V2

- Reworked the visual design without changing the public API.
- Added BuilderSans-first typography with safe legacy fallbacks.
- Added semantic theme tokens for canvas, sidebar, raised surfaces, controls, inset fields and subtle borders.
- Redesigned Window header, sidebar navigation, active-tab indicator and content hierarchy.
- Redesigned Section presentation and control cards.
- Slider now uses a full-width stacked layout instead of the old 62/38 row layout.
- Redesigned Toggle, Button, Input, Dropdown, Keybind and ColorPicker triggers.
- Redesigned Popover, mobile Sheet, Command Palette, Dialogs and Notifications.
- Added `examples/visual-showcase.lua` for visual QA.

## 0.9.2-beta.1

- Visual V3: flatter grouped controls instead of nested card-per-row styling.
- Added page title/description hierarchy to tabs.
- Softer graphite palette and less saturated active navigation states.
- Compact spacing, typography, fields, toggles and sliders.
- Replaced header glyph search/theme icons with drawn vector primitives.
- Hardened lazy tab mounting so unmounted sections are always mounted on select.
- Fixed Status theme binding typo that could abort showcase construction and leave later tabs empty.
