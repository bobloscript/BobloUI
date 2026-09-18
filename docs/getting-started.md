# Getting started

This builds a small but complete hub. Every step is runnable on its own, so you
can stop at any point and still have something that works.

## 1. Load the library

BobloUI ships as one file. Nothing else needs installing.

```lua
local BobloUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.min.lua"))()
```

`BobloUI.min.lua` has comments and indentation stripped; `BobloUI.lua` is the
readable build. They behave identically — use the minified one in production and
the readable one when you want to step through a bug.

That URL tracks `main`, which means your hub silently receives every future
change. Once a tagged release exists, pin to it instead:

```lua
local BobloUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/bobloscript/BobloUI/refs/tags/v0.11.5-beta.1/dist/BobloUI.min.lua"))()
```

## 2. Create a window

```lua
local UI = BobloUI:CreateWindow({
    Id = "my-hub",
    Title = "My Hub",
    Icon = "sword",
    Theme = "Dark",
    ConfigFolder = "MyHub",
    AutoLoad = true,
})
```

Two of these options do more than they look like they do.

`Id` is the identity of the window, not a label. Re-running your script replaces
only the window with that same `Id`, so a player who executes your hub twice
gets one window rather than two — and another hub that also uses BobloUI is left
alone. Pick something specific to your script and never change it between
versions, because config files are keyed against it.

`ConfigFolder` switches on the whole config subsystem. Without it, nothing is
saved between sessions. With it, `AutoLoad = true` restores the last profile the
player marked for autoload, before your callbacks fire.

For a script with only a few controls, set `Presentation = "Minimal"`. It uses
the same control methods in a small window; see [Minimal window](minimal.md).

## 3. Add a tab and some controls

Controls live in sections, and sections live in tabs.

```lua
local Farm = UI:AddTab({Id = "farm", Title = "Farm", Icon = "gamepad-2"})

local Automation = Farm:AddSection({
    Title = "Automation",
    Icon = "zap",
})

local AutoFarm = Automation:AddToggle({
    Id = "AutoFarm",
    Title = "Auto farm",
    Description = "Collects nearby drops automatically.",
    Default = false,
    Callback = function(enabled)
        print("auto farm:", enabled)
    end,
})

Automation:AddSlider({
    Id = "FarmRange",
    Title = "Range",
    Min = 10,
    Max = 250,
    Default = 75,
    Suffix = " studs",
})
```

Sections are optional. `Farm:AddToggle({...})` works directly and uses an
implicit section — reach for that on small hubs and add sections when the page
starts needing headings.

`Id` on a control is what binds it to the state store, the search index, the
config file and Favorites. A control without an `Id` still renders and still
fires its callback, but it is invisible to all four of those systems and will
not survive a save/load cycle. Give an `Id` to anything whose value matters.

## 4. React to values

The callback is the easy path, but it is not the only one, and for anything
beyond a single control it is the wrong one.

```lua
-- read and write from anywhere
UI.State:Set("AutoFarm", true)
print(UI.State:Get("FarmRange"))

-- watch one key
local stop = UI.State:Watch("AutoFarm", function(value, previous)
    print(value, previous)
end)

-- later
stop()
```

State updates are synchronous: after `Set` returns, every watcher has already
run. That makes ordering predictable, and it also means a slow watcher blocks
the caller — keep them cheap and push real work onto a task.

For a loop driven by several settings at once, read the store inside the loop
rather than mirroring values into upvalues:

```lua
task.spawn(function()
    while true do
        task.wait(0.1)
        if UI.State:Get("AutoFarm") then
            farmNearby(UI.State:Get("FarmRange"))
        end
    end
end)
```

## 5. Show and hide controls conditionally

A range slider is noise while auto farm is off. Say so declaratively instead of
wiring callbacks:

```lua
Automation:AddSlider({
    Id = "FarmRange",
    Title = "Range",
    Min = 10,
    Max = 250,
    Default = 75,
    VisibleWhen = {AutoFarm = true},
})
```

`EnabledWhen` is the same idea but greys the control out instead of removing it —
better when you want the player to see that an option exists. For conditions a
table cannot express, pass a function:

```lua
VisibleWhen = function(State)
    return State:Get("ESP") and State:Get("ESPMode") == "Advanced"
end
```

The store tracks which keys your function reads and re-evaluates only when those
change. A predicate that reads no state at all produces a development warning,
because it can never update and is almost always a bug.

Both options also work on `Section`, `Row` and `TabBox`, which is how you hide a
whole block at once. Disabling a container suppresses its children without
overwriting their own disabled state, so re-enabling it restores what was there
rather than turning everything on.

## 6. Save the player's settings

If you passed `ConfigFolder`, this already works from the Settings centre with
no code. To drive it yourself:

```lua
UI.Config:Save("Default")
UI.Config:Load("Default")
UI.Config:SetAutoLoad("Default")
```

Every stateful control with an `Id` is included. Exclude the volatile ones —
a dropdown of currently-online players has no business being restored:

```lua
Section:AddDropdown({
    Id = "TargetPlayer",
    Title = "Player",
    Source = BobloUI.Sources.Players(),
    IgnoreConfig = true,
})
```

## 7. Clean up

```lua
UI:Unload()
```

This destroys the ScreenGui layers, disconnects every input binding and clears
the window from the registry. If your script spawned loops, stop them here:

```lua
UI = BobloUI:CreateWindow({
    Id = "my-hub",
    Title = "My Hub",
    OnUnload = function()
        running = false
    end,
})
```

Skipping this is the most common source of "my hub gets slower every time I
re-execute it" — old loops keep running against a destroyed UI.

## Where to go next

[controls.md](controls.md) walks through all sixteen constructors.
[end-user.md](end-user.md) shows what your players can already do with the hub
you just built — the Settings centre, the search palette and the config manager
are on by default, so it is worth knowing what you shipped.
