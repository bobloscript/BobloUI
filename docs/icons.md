# Icons

BobloUI bundles a pinned Lucide mapping with 1,756 names. The mapping and
loader are part of `BobloUI.lua`; two PNG atlases live beside it in the
BobloScript GitHub repository. The icon provider uses no Roblox asset IDs and
never downloads or executes remote Lua code.

```lua
local UI = BobloUI:CreateWindow({
    Title = "Combat Hub",
    Icon = "swords",
})

local Combat = UI:AddTab({Title = "Combat", Icon = "crosshair"})
local Targeting = Combat:AddSection({Title = "Targeting", Icon = "scan-search"})

Targeting:AddToggle({
    Id = "AutoTarget",
    Title = "Auto target",
    Icon = "locate-fixed",
})
```

Names are case-insensitive. Spaces and underscores are normalized to hyphens, so `settings_2`, `Settings 2`, and `settings-2` resolve to the same icon.

```lua
print(BobloUI.Icon.Count) -- 1756
print(BobloUI.Icon.Has("sword")) -- true

BobloUI.Icon.Prepare()
local status = BobloUI.Icon.GetStatus()
print(status.State, status.Provider, status.Error)

if status.Ready then
    local asset = BobloUI.Icon.Resolve("sword")
    print(asset.Url, asset.ImageRectOffset, asset.ImageRectSize)
end
```

The complete alphabetic list is generated at `dist/LUCIDE_ICON_INDEX.txt`.

## GitHub assets and local cache

Publish the generated files with this exact repository layout:

```text
dist/
  BobloUI.lua
  assets/
    bobloui/
      lucide-1.png
      lucide-2.png
```

An `ImageLabel` cannot use the raw HTTPS URL directly. BobloUI downloads the
two PNGs, validates their signature, exact byte length and dimensions, caches
them under `BobloUI/assets/`, and passes the local files to the executor's
custom-asset API. No executable content is loaded from the icon URLs.

The default URLs target `bobloscript/BobloUI`. A fork can override them before
creating any windows:

```lua
BobloUI.Icon.SetAtlasUrls(
    "https://raw.githubusercontent.com/OWNER/REPO/main/dist/assets/bobloui/lucide-1.png",
    "https://raw.githubusercontent.com/OWNER/REPO/main/dist/assets/bobloui/lucide-2.png"
)
```

Use `BobloUI.Icon.Retry()` after a temporary network error. Executors without
HTTP, filesystem, or custom-asset support automatically render the built-in
asset-free GuiObject fallback instead; control behavior is unaffected.

## Licences

The icon artwork is distributed under the Lucide ISC licence, with
Feather-derived icons covered by MIT. The atlas port is also MIT. These
permissive licences allow redistribution and modification when their copyright
and permission notices stay with the redistributed material. BobloUI preserves
them in `vendor/lucide/`, `dist/THIRD_PARTY_LICENSES.txt`, and the header of
every generated bundle.
