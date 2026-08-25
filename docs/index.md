# BobloUI documentation

Version `0.11.5-beta.1`.

BobloUI has three kinds of reader, and the guides are split accordingly.

## I am writing a hub

Start at **[getting-started.md](getting-started.md)** — a working hub from an
empty file, with the shape of the API explained as it appears. It takes about
ten minutes end to end.

Then use **[controls.md](controls.md)** as the working reference: every one of
the sixteen constructors with a real example, the options that matter, and the
mistakes each one invites. The generated per-control pages
(`button.md`, `toggle.md`, …) hold the exhaustive option tables; they are
produced from `build/manifest.json` and are always in sync with runtime
validation, but they contain no prose.

Deeper topics have their own pages: [themes.md](themes.md) for the palette
contract, [icons.md](icons.md) for the Lucide atlases,
[p1-p2-services.md](p1-p2-services.md) and
[p3-controls-window.md](p3-controls-window.md) for the service and window
options added after 0.10.

## I am the person using a hub

**[end-user.md](end-user.md)** documents everything reachable without writing
code: the keyboard shortcuts, the Settings centre, config profiles, Favorites,
the search palette, the keybind manager, and how the UI behaves on a phone.

Worth reading even if you only write hubs — every one of these surfaces is
enabled by default, so your users get them whether or not you planned for it.

## I am changing BobloUI itself

**[extending.md](extending.md)** covers the build pipeline, the layer rules the
bundler enforces, how to add an option or a whole control, and what the test
suite actually checks. Read it before touching `src/` — several files there are
generated, and editing them by hand is wasted work.

**[publishing.md](publishing.md)** covers releasing a fork with its own hosted
distribution.

## Something is broken

**[troubleshooting.md](troubleshooting.md)** — icons missing, configs not
persisting, the window not appearing, executors with reduced capabilities.

## For AI assistants

`llms.txt` and `llms-full.txt` in the repository root are written to be pasted
into a model's context; `api.json` and `schema.json` carry the same information
in machine-readable form. All four are generated from `build/manifest.json`, so
they cannot drift from what the library actually validates at runtime.
