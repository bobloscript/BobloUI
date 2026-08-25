--!nonstrict
local Env = require("@runtime/Env")
local Storage = {}
Storage.__index = Storage
local MEMORY = {}
local function ensure(path)
	if not Env.FS then
		return
	end
	local acc = ""
	for part in string.gmatch(path, "[^/]+") do
		acc = if acc == "" then part else acc .. "/" .. part
		if not Env.FS.IsFolder(acc) then
			Env.FS.MakeFolder(acc)
		end
	end
end
function Storage.new(folder)
	local root = `BobloUI/{folder or "Default"}`
	ensure(root)
	return setmetatable({ Root = root, Memory = not Env.FS }, Storage)
end
function Storage:_path(name)
	return self.Root .. "/" .. name
end
function Storage:Read(name)
	local p = self:_path(name)
	if Env.FS then
		return Env.FS.Read(p)
	end
	return MEMORY[p]
end
function Storage:Write(name, data)
	local p = self:_path(name)
	if Env.FS then
		ensure(self.Root)
		return Env.FS.Write(p, data)
	end
	MEMORY[p] = data
	return true
end
function Storage:Delete(name)
	local p = self:_path(name)
	if Env.FS then
		return Env.FS.Delete(p)
	end
	MEMORY[p] = nil
	return true
end
function Storage:Exists(name)
	local p = self:_path(name)
	return Env.FS and Env.FS.IsFile(p) or MEMORY[p] ~= nil
end
function Storage:List()
	local out = {}
	if Env.FS then
		for _, p in Env.FS.List(self.Root) do
			local n = string.match(p, "([^/\\]+)$")
			if n then
				table.insert(out, n)
			end
		end
	else
		local prefix = self.Root .. "/"
		for p in MEMORY do
			if string.sub(p, 1, #prefix) == prefix then
				table.insert(out, string.sub(p, #prefix + 1))
			end
		end
	end
	table.sort(out)
	return out
end
return Storage
