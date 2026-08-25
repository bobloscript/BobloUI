# Publish BobloUI in its own repository

Create an empty public repository named `bobloscript/BobloUI`, then put the
complete dev-pack project in its `main` branch. Keep the generated distribution
paths unchanged:

```text
dist/
  BobloUI.lua
  BobloUI.min.lua
  THIRD_PARTY_LICENSES.txt
  assets/
    bobloui/
      lucide-1.png
      lucide-2.png
```

No Roblox asset upload is required. BobloUI only downloads the two PNG atlases
from this repository; it never downloads or executes third-party Lua code.

## Git command line

Extract the dev-pack so that `package.json`, `src`, `dist`, `tests`, `vendor`
and `.github` are in one folder, then run:

```bash
git init
git branch -M main
git add .
git commit -m "Release BobloUI 0.11.5 beta.1"
git remote add origin https://github.com/bobloscript/BobloUI.git
git push -u origin main
```

After the push, verify these raw URLs:

- `https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.lua`
- `https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/assets/bobloui/lucide-1.png`
- `https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/assets/bobloui/lucide-2.png`

Then run `BobloUI-Full-Diagnostic.lua`. The test named `GitHub atlas
custom-asset rendering` should pass in an executor that provides HTTP,
filesystem, and `getcustomasset`/`getsynasset`. It is expected to skip in Studio
or a restricted executor; BobloUI will render its asset-free fallback there.

## Runtime behavior

BobloUI downloads only the two PNG files. It verifies the PNG signature, exact
byte length, and dimensions before caching them under `BobloUI/assets/`. It does
not download or execute Lua code from the icon URLs.

If GitHub was temporarily unavailable on the first attempt, retry without
reloading the library:

```lua
BobloUI.Icon.Retry()
print(BobloUI.Icon.GetStatus().State)
```
