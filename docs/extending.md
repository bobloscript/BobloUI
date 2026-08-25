# Changing BobloUI itself

This is for editing the library, not for using it. If you only want a reusable
component inside your own hub, `RegisterControl` in
[controls.md](controls.md#custom-controls) is the cheaper answer and requires no
build step at all.

## Do not edit the bundle

`dist/BobloUI.lua` and `dist/BobloUI.min.lua` are build outputs. Every change
belongs in `src/`, followed by a rebuild. Editing the bundle directly works
until the next build silently discards it.

Four files inside `src/` are also generated and must not be hand-edited:

```
src/runtime/RuntimeManifest.lua   compact validator data used in production
src/schema/Manifest.lua           full manifest, tree-shaken out of the bundle
src/runtime/Types.lua             Luau type exports
```

Their source of truth is `build/manifest.json`.

## Setup

Node 22 or newer, Python 3, a Lua 5.3 interpreter, and StyLua 2.5.2 on your
`PATH`. There are no npm dependencies to install.

```bash
npm run generate     # manifest -> generated Lua, JSON, docs, llms files
npm run check        # regenerate, then validate the module graph
npm run build        # regenerate and emit dist/
npm run format       # StyLua over src, tests, examples
npm run format:check # same, read-only
npm test             # syntax + store harness + static contract tests
```

`npm run build` is reproducible: the bundle carries no timestamp, so building
twice from the same source produces identical bytes and a clean `git status`.
`generate` runs StyLua over the files it writes, so a build never leaves your
tree failing the CI formatting gate — provided StyLua is installed. Without it
you get a warning and unformatted generated files, which CI will then reject.

## Layers

The bundler enforces a strict dependency direction:

```
runtime  <-  kernel  <-  primitives  <-  controls  <-  shell  <-  services  <-  schema  <-  init
```

A module may require anything at its own level or below, never above. `themes`
sits at the same level as `runtime`. Requires use an alias form the bundler
rewrites:

```lua
local Create = require("@runtime/Create")
local Base = require("@controls/Base")
```

Violations fail `npm run check` with the offending pair named, as do cycles and
requires of modules that do not exist. A new top-level folder must be added to
`LAYERS` in `build/bundle.mjs` with an explicit position — the bundler refuses to
guess.

Modules unreachable from `src/init.lua` are tree-shaken out. That is deliberate
for `schema/Manifest.lua`, which exists for tooling and would otherwise add a
hundred kilobytes of documentation data to every hub.

## Adding an option to an existing control

Three edits, in this order.

**1.** Declare it in `build/manifest.json`, under that component's `options`:

```json
"Toggle": {
  "method": "AddToggle",
  "summary": "Boolean switch bound to State.",
  "stateful": true,
  "options": {
    "Default": "boolean?",
    "Style": "string?",
    "Flash": "boolean?"
  },
  "methods": {"Flip": "Invert the current boolean value."},
  "required": ["Title"]
}
```

The type strings feed runtime validation, the Luau exports and the docs at once.
A trailing `?` marks the option optional; `boolean|string?` is a union.

**2.** Run `npm run generate`. Validation, `api.json`, `schema.json`,
`llms.txt`, `llms-full.txt`, `docs/toggle.md` and `Types.lua` all update
together. This is why the manifest comes first: skip it, and your option is
rejected by the validator as unknown before your code ever runs.

**3.** Implement the behaviour in `src/controls/Toggle.lua`.

## Adding a control

Same shape, more of it.

1. Add the component to `build/manifest.json` with its `method`, `summary`,
   `stateful` flag, `required` list, `options` and any specific `methods`.
2. Create `src/controls/YourControl.lua`, building on `controls/Base` for the
   lifecycle, state binding, dependency and cleanup contract. Copy the closest
   existing control rather than starting from an empty file — `Toggle` for
   stateful, `Divider` for presentation-only.
3. Wire the constructor into the section API in `src/shell/Section.lua`.
4. Run `npm run generate && npm test`.

Note that `tests/static.mjs` asserts there are exactly sixteen canonical
constructors and no aliases. A seventeenth control means updating that
assertion — a deliberate speed bump, because the constructor list is the part of
the API that is hardest to walk back later.

## Cleanup is not optional

Every control must release what it creates. `runtime/Janitor` does the work:
add connections, instances and tasks to the janitor, and destruction cascades
correctly when a tab, section or window goes away.

`tests/leak.lua` creates two hundred controls, unloads, and checks that the
ScreenGui layers and the window registry are empty afterwards. Run it in a real
executor when touching lifecycle code — the static tests cannot see leaks.

## What the tests actually cover

`npm test` runs three stages:

- `luaucheck.py` parses every file in `src/` with a Lua interpreter, catching
  syntax errors without Roblox.
- `harness.py tests/store.spec.lua` exercises the state store — batching,
  watcher fan-out, dependency tracking — outside Roblox.
- `tests/static.mjs` checks contracts on the built bundle: generated artifacts
  are current, no missing or cyclic requires, no upward layer dependencies,
  exactly sixteen constructors, the full manifest is tree-shaken out, the
  compact one is bundled.

None of this runs Roblox. The files in `tests/` numbered `00`–`06`, plus
`BobloUI-Full-Diagnostic.lua`, are the runtime suite and must be executed in
Studio or an executor by hand. CI cannot tell you the UI renders correctly; it
can only tell you the code is well-formed and wired together.

## CI

`.github/workflows/ci.yml` runs on every push and pull request: StyLua check,
then `npm run check`, then `npm test`, then uploads the built distribution as an
artifact. The formatting gate runs against committed files, so commit after
building, not before.
