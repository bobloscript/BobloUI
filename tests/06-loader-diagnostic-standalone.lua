-- BobloUI 0.11.5 loader diagnostic
local URL = "https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.lua?cb=" .. tostring(os.time())

print("[BobloUI diagnostic] URL:", URL)

local okHttp, source = pcall(function()
	return game:HttpGet(URL)
end)
assert(okHttp, "[BobloUI diagnostic] HttpGet failed: " .. tostring(source))

local chunk, compileError = loadstring(source)
assert(chunk, "[BobloUI diagnostic] COMPILE FAILED:\n" .. tostring(compileError))

local okRun, BobloUI = pcall(chunk)
assert(okRun, "[BobloUI diagnostic] RUNTIME FAILED:\n" .. tostring(BobloUI))
assert(type(BobloUI) == "table", "[BobloUI diagnostic] bundle returned " .. typeof(BobloUI))
local actualVersion = tostring(BobloUI.Version)
assert(
	actualVersion == "0.11.5-beta.1",
	string.format("[BobloUI diagnostic] wrong version: %q (length %d)", actualVersion, #actualVersion)
)

print("[BobloUI diagnostic] PASS", BobloUI.Version, BobloUI.ApiLevel)
