# Using a BobloUI hub

Everything on this page is available to the person running a hub, without any
code and without the hub author enabling anything. If you write hubs, read it
anyway — you are shipping all of it whether you planned to or not.

## Keyboard shortcuts

| Key | Action |
| --- | --- |
| `Right Shift` | Show/hide the window |
| `Ctrl` + `K` | Open search and the command palette |
| `Tab` / `Shift` + `Tab` | Move between controls |
| Arrow keys | Move within a control |
| `Enter` | Activate the focused control |

The hub author can change the show/hide key or switch it off entirely, so it is
not guaranteed to be `Right Shift` in every script. Gamepads navigate with the
D-pad, `A` to activate and `B` to go back.

If the window is hidden and the toggle key does not work — common on touch
devices, or when an author disabled it — there is a floating restore button.
It can be dragged anywhere and exists specifically so the UI can never become
unreachable.

## Search and the command palette

`Ctrl` + `K` opens one field that searches several things at once. The first
character decides what:

| Prefix | Searches |
| --- | --- |
| *(none)* | Controls, by title, description, keywords and ID |
| `>` | Commands |
| `@` | Tabs |
| `#` | Config profiles |
| `*` | Favorites |

Picking a result jumps to the tab and section that holds it and highlights the
control, which is usually faster than remembering which tab something was on.
Results hidden by a dependency still appear, showing what needs enabling first
rather than silently vanishing.

Five commands exist in every hub: toggle the UI, switch between light and dark,
open settings, reset the window layout, and unload the UI entirely. Authors add
their own on top.

## The Settings centre

Every hub has one, mounted after the author's own tabs. Open it from the header
or with `>` `settings` in the palette.

**Appearance** — theme preset, accent colour, UI scale, window corner radius,
density (Comfortable / Compact / Touch), language, reduced motion, high
contrast, keyboard navigation, and UI sound volume. Reduced motion is worth
knowing about if animations make you uncomfortable or you are on a weak device;
high contrast strengthens borders and text for readability.

The light/dark switch works with your own themes too. Each theme is either a
light one or a dark one, and the switch moves to the last theme you used on the
other side — so if you made your own dark theme, switching away and back returns
to yours rather than the built-in. Once you have one of each, the switch moves
between your two and stops showing the built-ins. The theme picker labels which
side each theme is on.

**Theme editor** — full control over the palette, not just the accent. A
complete custom theme is 26 base colours plus one scrim transparency value;
BobloUI derives all the interaction states from those. Themes can be saved by
name, marked as your default, and exported or imported as JSON, so a palette you
like can move between hubs. See [themes.md](themes.md) for the exact contract.

**Window** — lock the window in place, remember its position and size between
sessions, hide the sidebar, set opacity, enable the custom cursor, choose which
corner notifications appear in, and reset either the layout or every setting.

**Configs** — only present if the hub author enabled config profiles.

**Favorites** and **Keybinds** — described below.

Settings changes are yours, not the hub's: they persist across scripts that use
BobloUI rather than being re-set each time.

## Config profiles

When an author passes a config folder, you get named profiles that store every
option in the hub. Save, load, rename, duplicate and delete them; export one to
JSON to share a setup with someone else, and import theirs.

Marking a profile for autoload restores it the moment the hub starts, before
anything runs. That is the setting worth using — it turns "re-configure the hub
every session" into nothing at all.

Values the author marked as volatile — a list of currently-online players, for
instance — are deliberately excluded. Options that no longer exist in a newer
version of the hub are preserved rather than discarded, so downgrading does not
lose your settings, and a backup is written before any migration.

In Roblox Studio, or an executor without filesystem access, configs fall back to
memory and are gone when you leave. Nothing breaks; nothing is saved either.

## Favorites

Right-click any control (long-press on touch) and choose **Add to Favorites**.
Favorited controls are collected in Settings and reachable through `*` in the
palette — the point being that a hub with two hundred options usually has six
you actually touch.

The same context menu offers **Reset to default**, **Copy value** and **Paste
value**. Copy and paste move a single setting between hubs or to a friend
without exporting a whole profile.

## Keybind manager

Settings lists every keybind the hub registered in one place, so you can see
what is bound and rebind it without hunting through tabs. Bindings support
chords such as `Ctrl` + `Shift` + `F`, and different modes: hold to activate,
toggle on and off, or always-on.

On phones and tablets, bindings the author marked as mobile-capable appear as
labelled buttons in a HUD instead — a keybind with no mobile flag simply has no
touch equivalent.

## On a phone or tablet

The layout changes shape with the window, not with the device:

| Width | Layout |
| --- | --- |
| 1100px and up | Sidebar plus two columns of sections |
| 700–1099px | Compact icon rail, one column |
| Below 700px | Slide-out drawer navigation, one column |

Rotating or resizing moves the layout containers rather than rebuilding them, so
nothing you have set is lost when the screen changes.

Touch layouts get larger hit targets, bottom sheets instead of floating pickers,
and the restore button described above. Density defaults to touch-safe sizes on
phones and cannot be shrunk below them.

## Icons look wrong

If icons appear as simple shapes rather than proper glyphs, the icon atlases
could not be downloaded and the UI fell back to a built-in set. Everything still
works. See [troubleshooting.md](troubleshooting.md) for why and what to do.
