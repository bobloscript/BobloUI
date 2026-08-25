-- BobloUI development loader. Set getgenv().BOBLOUI_DEV_BASE to your raw src/ URL.
local BASE = (getgenv and getgenv().BOBLOUI_DEV_BASE) or "https://raw.githubusercontent.com/robscript/boblo-ui/main/src/"
local cache = {}
local loading = {}
local function devRequire(id)
	if cache[id] ~= nil then return cache[id] end
	if loading[id] then error("[BobloUI dev] cyclic require: " .. id, 2) end
	loading[id] = true
	local source = game:HttpGet(BASE .. id .. ".lua")
	source = source:gsub('require%(%s*"@([%w_./%-]+)"%s*%)', '__BOBLO_DEV_REQUIRE("%1")')
	local fn, err = loadstring(source, "@" .. id .. ".lua")
	if not fn then loading[id] = nil; error(err, 2) end
	local env = getfenv(fn)
	env.__BOBLO_DEV_REQUIRE = devRequire
	setfenv(fn, env)
	local result = fn()
	loading[id] = nil
	cache[id] = result
	return result
end
return devRequire("init")
