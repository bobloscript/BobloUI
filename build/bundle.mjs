#!/usr/bin/env node
/**
 * BobloUI bundler.
 *
 * Roblox script hubs load through `loadstring(game:HttpGet(url))()`. There is
 * no `require()` for remote modules, so a modular `src/` can never be the thing
 * a user loads. This turns it into one file.
 *
 * Source convention:
 *     local Signal = require("@runtime/Signal")
 *
 * The `@` sigil makes module requires unmistakable and greppable, and keeps
 * them from colliding with Roblox's own Instance-based `require`.
 *
 * The bundler is also the enforcement point for two architectural rules:
 *   1. no cyclic requires  - lazy __require would still work, but a cycle means
 *      two modules that should be one, and it breaks initialisation order
 *   2. no upward layer requires - runtime <- kernel <- primitives <- controls
 *      <- shell <- services <- schema <- init
 *
 * Usage:
 *   node build/bundle.mjs            build dist/BobloUI.lua
 *   node build/bundle.mjs --min      also build dist/BobloUI.min.lua
 *   node build/bundle.mjs --check    validate only, write nothing
 */

import { readFileSync, writeFileSync, readdirSync, statSync, mkdirSync } from "node:fs";
import { join, relative, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const SRC = join(ROOT, "src");
const DIST = join(ROOT, "dist");
const ENTRY = "init";

const LAYERS = {
  runtime: 0,
  themes: 0,
  kernel: 1,
  primitives: 2,
  controls: 3,
  shell: 4,
  services: 5,
  schema: 6,
  "": 7, // src/init.lua
};

const REQUIRE_RE = /require\(\s*"@([A-Za-z0-9_./-]+)"\s*\)/g;

// ---------------------------------------------------------------- lexing

/** Matches a Lua long bracket `[==[ ... ]==]` starting at `i`, or null. */
function matchLongBracket(src, i) {
  if (src[i] !== "[") return null;
  let j = i + 1;
  let level = 0;
  while (src[j] === "=") {
    level++;
    j++;
  }
  if (src[j] !== "[") return null;
  const close = "]" + "=".repeat(level) + "]";
  const end = src.indexOf(close, j + 1);
  return { end: end === -1 ? src.length : end + close.length };
}

/**
 * Removes comments while respecting strings. A naive regex would eat `--` that
 * lives inside a string literal, which is exactly the kind of bug that only
 * shows up in production minified builds.
 */
function stripComments(src) {
  let out = "";
  let i = 0;
  const n = src.length;

  while (i < n) {
    const c = src[i];

    if (c === "-" && src[i + 1] === "-") {
      const long = matchLongBracket(src, i + 2);
      if (long) {
        i = long.end;
        continue;
      }
      let j = i + 2;
      while (j < n && src[j] !== "\n") j++;
      i = j;
      continue;
    }

    if (c === '"' || c === "'" || c === "`") {
      let j = i + 1;
      while (j < n) {
        if (src[j] === "\\") {
          j += 2;
          continue;
        }
        if (src[j] === c) {
          j++;
          break;
        }
        j++;
      }
      out += src.slice(i, j);
      i = j;
      continue;
    }

    if (c === "[") {
      const long = matchLongBracket(src, i);
      if (long) {
        out += src.slice(i, long.end);
        i = long.end;
        continue;
      }
    }

    out += c;
    i++;
  }

  return out;
}

/**
 * Conservative minification: comments out, blank lines out, indentation out.
 * Lines are NOT joined - Lua has no statement terminator, and joining is how
 * a minifier silently changes semantics.
 */
function minify(src) {
  return stripComments(src)
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .join("\n");
}

// ---------------------------------------------------------------- discovery

function walk(dir, out = []) {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) walk(full, out);
    else if (entry.endsWith(".lua")) out.push(full);
  }
  return out;
}

function moduleId(file) {
  return relative(SRC, file).replace(/\\/g, "/").replace(/\.lua$/, "");
}

function layerOf(id) {
  const folder = id.includes("/") ? id.split("/")[0] : "";
  const layer = LAYERS[folder];
  if (layer === undefined) {
    throw new Error(
      `Unknown source folder "${folder}" (module ${id}). ` +
        `Add it to LAYERS in build/bundle.mjs with an explicit position.`
    );
  }
  return layer;
}

function collect() {
  const modules = new Map();
  for (const file of walk(SRC)) {
    const id = moduleId(file);
    const source = readFileSync(file, "utf8");
    const deps = [];
    for (const match of stripComments(source).matchAll(REQUIRE_RE)) {
      deps.push(match[1]);
    }
    modules.set(id, { id, file, source, deps, layer: layerOf(id) });
  }
  return modules;
}

// ---------------------------------------------------------------- validation

function validate(modules) {
  const errors = [];

  for (const mod of modules.values()) {
    for (const dep of mod.deps) {
      if (!modules.has(dep)) {
        errors.push(`${mod.id}: requires "@${dep}", which does not exist in src/`);
        continue;
      }
      const depLayer = modules.get(dep).layer;
      if (depLayer > mod.layer) {
        errors.push(
          `${mod.id} (layer ${mod.layer}) requires ${dep} (layer ${depLayer}). ` +
            `Dependencies must point downward; inject upward dependencies at init instead.`
        );
      }
    }
  }

  // Cycle detection, reporting the actual path rather than just "cycle found".
  const WHITE = 0;
  const GREY = 1;
  const BLACK = 2;
  const colour = new Map([...modules.keys()].map((id) => [id, WHITE]));
  const stack = [];

  function visit(id) {
    colour.set(id, GREY);
    stack.push(id);
    for (const dep of modules.get(id)?.deps ?? []) {
      if (!modules.has(dep)) continue;
      const state = colour.get(dep);
      if (state === GREY) {
        const start = stack.indexOf(dep);
        errors.push(`Cyclic require: ${[...stack.slice(start), dep].join(" -> ")}`);
      } else if (state === WHITE) {
        visit(dep);
      }
    }
    stack.pop();
    colour.set(id, BLACK);
  }

  for (const id of modules.keys()) {
    if (colour.get(id) === WHITE) visit(id);
  }

  if (!modules.has(ENTRY)) errors.push(`Missing entry module src/${ENTRY}.lua`);

  return errors;
}


function reachableFromEntry(modules) {
  const keep = new Set();
  function visit(id) {
    if (keep.has(id) || !modules.has(id)) return;
    keep.add(id);
    for (const dep of modules.get(id).deps) visit(dep);
  }
  visit(ENTRY);
  const out = new Map();
  for (const [id, mod] of modules) if (keep.has(id)) out.set(id, mod);
  return out;
}

// ---------------------------------------------------------------- emit

function version() {
  try {
    return JSON.parse(readFileSync(join(ROOT, "package.json"), "utf8")).version;
  } catch {
    return "0.0.0";
  }
}

function thirdPartyNotice() {
  const lucide = readFileSync(join(ROOT, "vendor", "lucide", "LUCIDE-LICENSE"), "utf8").trim();
  const port = readFileSync(join(ROOT, "vendor", "lucide", "ROBLOX-PORT-LICENSE"), "utf8").trim();
  return [
    "THIRD-PARTY LICENSE NOTICES",
    "",
    "Lucide Icons:",
    lucide,
    "",
    "---",
    "",
    "lucide-roblox-direct:",
    port,
  ].join("\n");
}

function emit(modules, { min }) {
  const ids = [...modules.keys()].sort();
  const lines = [];
  const map = {};

  lines.push(`--[[`);
  lines.push(`\tBobloUI v${version()} - generated bundle, do not edit.`);
  lines.push(`\tSource: https://github.com/bobloscript/BobloUI/blob/main/dist/BobloUI.lua`);
  lines.push(`\tModules: ${ids.length}`);
  lines.push("");
  lines.push(thirdPartyNotice());
  lines.push(`]]`);
  lines.push(`local __modules = {}`);
  lines.push(`local __cache = {}`);
  lines.push(`local function __require(id)`);
  lines.push(`\tlocal cached = __cache[id]`);
  lines.push(`\tif cached then return cached[1] end`);
  lines.push(`\tlocal loader = __modules[id]`);
  lines.push(`\tif not loader then error("[BobloUI] missing bundled module: " .. id, 2) end`);
  lines.push(`\tlocal result = loader()`);
  lines.push(`\t__cache[id] = { result }`);
  lines.push(`\treturn result`);
  lines.push(`end`);
  lines.push("");

  for (const id of ids) {
    const mod = modules.get(id);
    let body = mod.source.replace(REQUIRE_RE, (_, dep) => `__require("${dep}")`);
    if (min) body = minify(body);

    map[id] = lines.length + 2;
    lines.push(`__modules["${id}"] = function()`);
    lines.push(body);
    lines.push(`end`);
    lines.push("");
  }

  lines.push(`return __require("${ENTRY}")`);

  return { code: lines.join("\n"), map };
}

// ---------------------------------------------------------------- main

const args = new Set(process.argv.slice(2));
const modules = collect();
const errors = validate(modules);

if (errors.length > 0) {
  console.error("Build failed:\n");
  for (const error of errors) console.error(`  - ${error}`);
  process.exit(1);
}

const bundledModules = reachableFromEntry(modules);
console.log(`ok: ${modules.size} source modules, ${bundledModules.size} reachable, no cycles, no upward layer requires`);

if (args.has("--check")) process.exit(0);

mkdirSync(DIST, { recursive: true });
const DIST_ASSETS = join(DIST, "assets", "bobloui");
mkdirSync(DIST_ASSETS, { recursive: true });
writeFileSync(join(DIST_ASSETS, "lucide-1.png"), readFileSync(join(ROOT, "vendor", "lucide", "spritesheets", "1.png")));
writeFileSync(join(DIST_ASSETS, "lucide-2.png"), readFileSync(join(ROOT, "vendor", "lucide", "spritesheets", "2.png")));
writeFileSync(join(DIST, "THIRD_PARTY_LICENSES.txt"), `${thirdPartyNotice()}\n`);
writeFileSync(
  join(DIST, "LUCIDE_ICON_INDEX.txt"),
  readFileSync(join(ROOT, "vendor", "lucide", "icon-index.txt"), "utf8"),
);

const full = emit(bundledModules, { min: false });
writeFileSync(join(DIST, "BobloUI.lua"), full.code);
writeFileSync(join(DIST, "BobloUI.map.json"), JSON.stringify(full.map, null, 2));
console.log(`wrote dist/BobloUI.lua (${(full.code.length / 1024).toFixed(1)} KB)`);

if (args.has("--min")) {
  const small = emit(bundledModules, { min: true });
  writeFileSync(join(DIST, "BobloUI.min.lua"), small.code);
  console.log(`wrote dist/BobloUI.min.lua (${(small.code.length / 1024).toFixed(1)} KB)`);
}
