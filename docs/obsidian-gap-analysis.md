# BobloUI vs Obsidian: API gap analysis

Audit date: 2026-08-25. Source of truth for the comparison is the official
[Obsidian documentation](https://docs.mspaint.cc/obsidian). BobloUI behavior was
checked against this dev-pack's `src/`, generated manifest, README, and tests.

This is an API/capability comparison, not a recommendation to clone Obsidian's
visual identity. BobloUI keeps its own Dark/Light design system and GitHub-hosted
Lucide spritesheets.

## Executive summary

BobloUI now covers the complete P1/P2/P3 comparison surface: responsive windows,
tabs, sections, nested tab boxes, 16 control types, reactive controls and
containers, dialog v2, public draggable overlays, chord/mobile keybinds,
notifications, staged loading, persisted custom themes, configuration, search,
commands, localization, accessibility, and a synchronous State/Store.

P3 closes the remaining option-level conveniences while preserving BobloUI's
existing result shapes by default. BobloUI deliberately keeps its own API names
and visual identity instead of cloning Obsidian.

## Capability matrix

| Area | Obsidian | BobloUI now | Gap / decision | Priority |
| --- | --- | --- | --- | --- |
| Built-in themes | Multiple presets plus persisted custom themes and a default-theme marker through [ThemeManager](https://docs.mspaint.cc/obsidian/core/addons/thememanager) | Exactly Dark and Light plus a persisted custom-theme library, default marker, load/list/delete/reload APIs and Settings integration | Complete; keeping two bundled presets is intentional | Done (P2) |
| Window shell | Runtime footer, background, corner radius, compact/sidebar controls and other shell options in [Window](https://docs.mspaint.cc/obsidian/core/library/window) | Footer/image/radius, scale, density, sidebar compaction, configurable search width/scope, mobile-button side, responsive thresholds, tab motion distance/direction, geometry persistence and independent motion switches | Complete | Done (P3) |
| Dialogs | All groupbox controls, auto/outside dismissal, dynamic ordered footer buttons, disabled state and timed lock in [Dialogs](https://docs.mspaint.cc/obsidian/core/library/dialogs) | Custom supports all 16 controls, auto/outside policies, dynamic ordered/disabled footer actions, `WaitTime`, and runtime title/description | Complete | Done (P1) |
| Floating overlays | Draggable label, button and free-form menu in [Overlays](https://docs.mspaint.cc/obsidian/core/library/overlays) | Public draggable Label, Button and Menu handles with position/visibility/content mutation and cleanup | Complete | Done (P1) |
| Keybinds | Modifiers, whitelist/blacklist, custom modes, attachment to other controls and mobile keybind menu in [Keybinds](https://docs.mspaint.cc/obsidian/elements/keybinds) and [Keybind Menu](https://docs.mspaint.cc/obsidian/core/library/keybind-menu) | Modifier chords, exact matching, whitelist/blacklist, custom modes, Button/Toggle attachment and mobile HUD tap actions | Complete | Done (P1) |
| Reactive containers | Conditional dependency boxes and groupboxes in [Dependency Boxes](https://docs.mspaint.cc/obsidian/structure/dependencyboxes) and [Dependency Groupboxes](https://docs.mspaint.cc/obsidian/structure/dependencygroupboxes) | Store-tracked `VisibleWhen` / `EnabledWhen` on controls, Section, Row and TabBox with child enabled propagation | Complete | Done (P1) |
| UI passthrough | Hosts an existing `GuiBase2d` instance through [UI Passthrough](https://docs.mspaint.cc/obsidian/elements/ui-passthrough) | `AddPassthrough` with clone/ownership, fill, height, replacement and content access | Complete | Done (P1) |
| 3D content | Interactive/orbitable `ViewportFrame`, object/camera setters and autofocus in [Viewports](https://docs.mspaint.cc/obsidian/elements/viewports) | `AddViewport` with object ownership, clone, autofocus, camera replacement, orbit, zoom and sizing | Complete | Done (P1) |
| Video | `VideoFrame` source, playback, loop, volume and sizing in [Videos](https://docs.mspaint.cc/obsidian/elements/videos) | `AddVideo` with source/play/pause/loop/volume/height APIs | Complete; playback still depends on Roblox/executor asset support | Done (P2) |
| Images | Tint, transparency, background, sprite rect and height in [Images](https://docs.mspaint.cc/obsidian/elements/images) | Image/caption/height plus tint, image/background transparency, sprite rect and scale mode | Complete | Done (P2) |
| Loading | Stages plus richer loading/error content in [Loading](https://docs.mspaint.cc/obsidian/core/library/loading) | Message/description/current/total steps, icon color/spin, errors/actions, runtime sidebar visibility and a full control-bearing sidebar | Complete at P2 capability level | Done (P2) |
| Notifications | Persistent/updateable items, progress and richer media/color/sound options in [Notifications](https://docs.mspaint.cc/obsidian/core/library/notifications) | Queue/actions/update/progress/step aliases plus custom icon, large image, colors and per-item sound | Complete at P2 capability level | Done (P2) |
| Buttons | Double-click, risky confirmation, sub-buttons and attached key picker in [Buttons](https://docs.mspaint.cc/obsidian/elements/buttons) | Confirmation/Risky alias, double-click window, dynamic sub-actions and Button/Toggle `AddKeybind` composition | Complete | Done (P2) |
| Dropdowns | Array/dictionary values, drag-select, max visible rows, disabled/image maps and format hooks in [Dropdowns](https://docs.mspaint.cc/obsidian/elements/dropdowns) | Array/dictionary definitions, array or map result mode, Source, drag multi-select, row cap, formatters and runtime disabled/image maps | Complete; arrays remain the backward-compatible default | Done (P3) |
| Inputs/sliders | Extra empty/blur and compact display options in [Inputs](https://docs.mspaint.cc/obsidian/elements/inputs) and [Sliders](https://docs.mspaint.cc/obsidian/elements/sliders) | Empty/reset/blur policies and aliases; prefix/suffix, compact/max display, format hooks and right-click numeric editing | Complete | Done (P3) |
| Labels/dividers | Rich text sizing/wrapping and divider text/margins in [Labels](https://docs.mspaint.cc/obsidian/elements/labels) and [Dividers](https://docs.mspaint.cc/obsidian/elements/dividers) | Paragraph RichText/manual size/wrapping plus divider text and independent margins | Complete | Done (P3) |

## Compatibility decisions after P1/P2/P3

These do not remove a P1/P2 capability, but they matter if a script is being
ported line-for-line from Obsidian:

- BobloUI's `Options={...}` multi-dropdown remains an ordered array. A dictionary
  `Values={key=label}` definition automatically uses `{[key]=true}` results;
  `MultiValueMode="Array"|"Map"` makes either choice explicit. Config loading
  converts the other representation safely.
- Obsidian has `SpecialType`, built-in player-image flags and a few picker-specific
  aliases. BobloUI uses the more general `Source` and
  `BobloUI.Sources.Players(...)` path.
- Low-level compact/search/mobile/swipe settings now have BobloUI equivalents.
  Names match Obsidian where doing so is unambiguous, while runtime mutation uses
  BobloUI's `SetResponsiveThresholds`, `SetSearchbarSize`, and `SetTabSwipe`.
- Obsidian Loading exposes `AutoResizeHeight` and `AlwaysOnTop`; BobloUI keeps the
  loader modal and viewport-clamped. Its error/sidebar behavior and core
  mutation methods are covered.
- Method spellings are not cloned wholesale: for example BobloUI uses
  `SetTitle`/`IsActive`/`OnChanged` where Obsidian may document
  `SetText`/`GetState`/`Update`. Compatibility aliases were added only where they
  materially improve portability.

## What BobloUI already has that is stronger or outside Obsidian's documented API

- Deterministic Store delivery: FIFO nested writes, owner-aware watcher
  suppression, settled `WatchMany`, direct dependency tracking, cascade diagnostics,
  and cycle-safe table equality.
- Function-based `VisibleWhen` and `EnabledWhen` dependencies on every control.
- Indexed, debounced search plus a command palette that searches commands, tabs,
  configurations and favorites.
- Configuration migrations, unknown-key preservation, rename/duplicate/export,
  and autoload tracking across rename/delete.
- Responsive Wide/Rail/Drawer layouts, density presets, UI scale, reduced motion,
  high contrast, keyboard navigation, touch sheets, and EN/RU/ES localization.
- Declarative `Build` with prevalidation, custom control registration, and the
  additional Status, Progress and Code controls.

## Completion status

All P1, P2 and P3 entries from the audit are implemented and protected by
generated types/schema, static contract checks and the full Roblox diagnostic.
Remaining differences are deliberate naming or architecture choices, not missing
items from the prioritized audit.
