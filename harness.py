#!/usr/bin/env python3
"""Execute pure BobloUI modules and a Luau spec in a headless Lua 5.3 shim."""

from __future__ import annotations

import pathlib
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import luaucheck

ROOT = pathlib.Path(__file__).parent
MODULES = ["runtime/Signal", "runtime/Util", "kernel/Store", "kernel/Theme"]

SHIMS = r"""
table.clone = table.clone or function(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end
table.find = table.find or function(t, v) for i = 1, #t do if t[i] == v then return i end end return nil end
table.clear = table.clear or function(t) for k in pairs(t) do t[k] = nil end end
table.create = table.create or function(n, v) local o = {} for i = 1, n do o[i] = v end return o end
local Color3Mt = {}
Color3Mt.__index = Color3Mt
function Color3Mt:Lerp(other, alpha)
  return Color3.new(
    self.R + (other.R - self.R) * alpha,
    self.G + (other.G - self.G) * alpha,
    self.B + (other.B - self.B) * alpha
  )
end
function Color3Mt:ToHex()
  return string.format("%02x%02x%02x",
    math.floor(self.R * 255 + 0.5), math.floor(self.G * 255 + 0.5), math.floor(self.B * 255 + 0.5))
end
Color3 = {
  new = function(r, g, b)
    return setmetatable({ R = r or 0, G = g or 0, B = b or 0, __color3 = true }, Color3Mt)
  end,
}
function Color3.fromRGB(r, g, b) return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
function Color3.fromHex(hex)
  hex = tostring(hex):gsub("#", "")
  return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
end

typeof = function(v)
  if type(v) == "table" and rawget(v, "__color3") then return "Color3" end
  return type(v)
end
math.round = math.round or function(x) return math.floor(x + 0.5) end

local deferred = {}
task = {
  defer = function(fn) deferred[#deferred + 1] = fn return fn end,
  delay = function(_, fn) deferred[#deferred + 1] = fn return fn end,
  spawn = function(fn, ...) fn(...) end,
  cancel = function() end,
}
function __drainDeferred()
  local queue = deferred
  deferred = {}
  for _, fn in ipairs(queue) do fn() end
end

__warnings = {}
function warn(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  __warnings[#__warnings + 1] = table.concat(parts, " ")
end

local modules, cache = {}, {}
function __define(id, factory) modules[id] = factory end
function __require(id)
  if cache[id] then return cache[id][1] end
  assert(modules[id], "unknown module " .. tostring(id))
  local result = modules[id]()
  cache[id] = { result }
  return result
end
"""


def main():
    spec_arg = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--lua=") else "tests/store.spec.lua"
    spec = (ROOT / spec_arg).resolve()
    if not spec.is_file():
        raise SystemExit(f"spec not found: {spec_arg}")

    parts = [SHIMS]
    for module in MODULES:
        source = (ROOT / "src" / (module + ".lua")).read_text(encoding="utf-8")
        source = re.sub(r'require\(\s*"@([A-Za-z0-9_./-]+)"\s*\)', r'__require("\1")', source)
        lowered = luaucheck.prepare(source, stub_requires=False)
        parts.append(f'__define("{module}", function()\n{lowered}\nend)\n')
    parts.append(luaucheck.prepare(spec.read_text(encoding="utf-8"), stub_requires=False))

    with tempfile.TemporaryDirectory(prefix="bobloui-harness-") as directory:
        bundle = pathlib.Path(directory) / "headless.lua"
        bundle.write_text("\n".join(parts), encoding="utf-8")
        result = subprocess.run([luaucheck.lua_binary(), str(bundle)], capture_output=True, text=True)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
