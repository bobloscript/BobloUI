# Troubleshooting

## Icons are plain shapes instead of proper glyphs

This is the fallback, and it is the most common thing people report.

Roblox `ImageLabel` cannot display an HTTPS URL directly, so BobloUI downloads
two PNG atlases on the first icon request, validates them, caches them under
`BobloUI/assets/`, and registers them through the executor's custom-asset API.
If any of those steps is unavailable, the library switches to a built-in
asset-free icon set. The UI keeps working; only the full Lucide catalogue is
missing.

Check what happened:

```lua
BobloUI.Icon.Prepare()
local status = BobloUI.Icon.GetStatus()
print(status.State, status.Provider, status.Error)
```

If it was a temporary network failure, retry without reloading the library:

```lua
BobloUI.Icon.Retry()
```

Three requirements must all hold: HTTP access, filesystem access, and a
custom-asset function such as `getcustomasset` or `getsynasset`. Studio provides
none of them, so the fallback there is expected and not a bug.

Forks hosting their own copies point at them before creating any window:

```lua
BobloUI.Icon.SetAtlasUrls(
    "https://raw.githubusercontent.com/OWNER/REPO/main/dist/assets/bobloui/lucide-1.png",
    "https://raw.githubusercontent.com/OWNER/REPO/main/dist/assets/bobloui/lucide-2.png"
)
```

No Lua is ever downloaded or executed by the icon provider — only the two PNGs,
checked for signature, exact byte length and dimensions before use.

## Settings are not saved between sessions

Either the hub passed no `ConfigFolder` to `CreateWindow`, in which case the
config subsystem is off entirely, or the environment has no filesystem access.
Storage falls back to memory in Studio and in restricted executors: saving
appears to succeed, and everything is gone on rejoin.

## A control's value does not survive save/load

Three usual causes:

- The control has no `Id`. Without one it is invisible to configs, search,
  Favorites and the state store.
- It carries `IgnoreConfig = true`.
- It is a `Status` control, which is read-only and never persisted by design.

## The window does not appear

Try the show/hide key — `Right Shift` unless the hub changed it — and look for
the floating restore button, which exists so a hidden window is always
recoverable. If neither works, another script may have created a window with the
same `Id`: BobloUI replaces windows by `Id`, so two hubs sharing one will fight.

## Re-running the script leaves the old UI behind

Windows are keyed by `Id`. Re-executing with the same `Id` replaces the previous
window, which is what you want. Different `Id`s produce two independent windows.

Loops from the previous run are a separate problem — they are yours, not the
library's, and they keep running against a destroyed UI. Stop them in
`OnUnload`.

## A dependency never updates

```lua
VisibleWhen = function()
    return someLocalVariable   -- reads no state, will never re-evaluate
end
```

Dynamic dependencies re-run when the state keys they read change. A predicate
reading no state can never fire again, so the library emits a development
warning. Read through the `State` argument, or through the same `UI.State`
reference — both are tracked.

## Everything is very slow with hundreds of controls

State updates are synchronous: when `Set` returns, every watcher has already
run. A slow watcher blocks whoever called it. Move real work onto a task, and
wrap bulk changes so watchers fire once rather than per key:

```lua
UI.State:Batch(function()
    UI.State:Set("A", 1)
    UI.State:Set("B", 2)
end)
```

Scroll virtualization for very large pages is deliberately not implemented; see
the exclusions section of the README.

## Reporting something else

Open an issue at <https://github.com/bobloscript/BobloUI/issues> with the
executor name, whether it happens in Studio, and the output of
`print(BobloUI.Icon.GetStatus().State)` if it involves icons.
