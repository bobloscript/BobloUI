--!nonstrict
--[[
	Env — executor / environment abstraction.

	Every executor-specific call in BobloUI goes through this module. Nothing
	else in the codebase is allowed to reference `gethui`, `writefile`,
	`syn.protect_gui` or any other injected global directly.

	Detection runs once, at load. In Studio every capability is simply false and
	the library degrades: config saves land in memory, the GUI goes to PlayerGui.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Env = {}

-- ===== global lookup ==============================================
-- Injected globals live in different places depending on the executor, so try
-- each source rather than assuming one.

local function tryGlobal(name: string): any?
	local sources = {}

	local ok, genv = pcall(function()
		return getgenv()
	end)
	if ok and type(genv) == "table" then
		table.insert(sources, genv)
	end

	local ok2, fenv = pcall(function()
		return getfenv(0)
	end)
	if ok2 and type(fenv) == "table" then
		table.insert(sources, fenv)
	end

	table.insert(sources, _G)

	for _, source in sources do
		local found, value = pcall(function()
			return source[name]
		end)
		if found and value ~= nil then
			return value
		end
	end
	return nil
end

Env.IsStudio = RunService:IsStudio()

--- Cross-script table. In Studio there is no getgenv, so this is bundle-local
--- and the window registry only spans one script — which is correct there.
do
	local ok, genv = pcall(function()
		return getgenv()
	end)
	Env.Globals = (ok and type(genv) == "table") and genv or {}
	Env.HasSharedGlobals = ok and type(genv) == "table"
end

-- ===== identity ===================================================

do
	local identify = tryGlobal("identifyexecutor") or tryGlobal("getexecutorname")
	local name = nil
	if identify then
		local ok, result = pcall(identify)
		if ok and type(result) == "string" then
			name = result
		end
	end
	Env.Executor = name or (Env.IsStudio and "Roblox Studio" or "Unknown")
end

-- ===== filesystem =================================================

local writefile = tryGlobal("writefile")
local readfile = tryGlobal("readfile")
local isfile = tryGlobal("isfile")
local isfolder = tryGlobal("isfolder")
local makefolder = tryGlobal("makefolder")
local listfiles = tryGlobal("listfiles")
local delfile = tryGlobal("delfile")

local hasFilesystem = writefile ~= nil and readfile ~= nil and isfile ~= nil and isfolder ~= nil and makefolder ~= nil

Env.FS = if hasFilesystem
	then {
		Read = function(path: string): string?
			local ok, contents = pcall(readfile, path)
			return if ok then contents else nil
		end,
		Write = function(path: string, contents: string): boolean
			return (pcall(writefile, path, contents))
		end,
		Delete = function(path: string): boolean
			if not delfile then
				return false
			end
			return (pcall(delfile, path))
		end,
		List = function(path: string): { string }
			if not listfiles then
				return {}
			end
			local ok, entries = pcall(listfiles, path)
			return if ok and type(entries) == "table" then entries else {}
		end,
		IsFile = function(path: string): boolean
			local ok, result = pcall(isfile, path)
			return ok and result == true
		end,
		IsFolder = function(path: string): boolean
			local ok, result = pcall(isfolder, path)
			return ok and result == true
		end,
		MakeFolder = function(path: string): boolean
			return (pcall(makefolder, path))
		end,
	}
	else nil

-- ===== clipboard / http ===========================================

local requestFunction = tryGlobal("request") or tryGlobal("http_request") or tryGlobal("httprequest")
if not requestFunction then
	local syn = tryGlobal("syn")
	if type(syn) == "table" then
		requestFunction = syn.request
	end
end
if not requestFunction then
	local http = tryGlobal("http")
	if type(http) == "table" then
		requestFunction = http.request
	end
end

local customAsset = tryGlobal("getcustomasset") or tryGlobal("getsynasset")
if not customAsset then
	local syn = tryGlobal("syn")
	if type(syn) == "table" then
		customAsset = syn.getcustomasset or syn.get_custom_asset
	end
end

function Env.HttpGet(url: string): (string?, string?)
	if type(requestFunction) == "function" then
		local ok, response = pcall(requestFunction, {
			Url = url,
			Method = "GET",
			Headers = {
				["Cache-Control"] = "no-cache",
			},
		})
		if ok and type(response) == "table" then
			local status = tonumber(response.StatusCode or response.Status)
			local body = response.Body or response.body
			if type(body) == "string" and (status == nil or (status >= 200 and status < 300)) then
				return body, nil
			end
			return nil, `HTTP {status or "request failed"}`
		end
	end

	local ok, body = pcall(function()
		return game:HttpGet(url, true)
	end)
	if ok and type(body) == "string" then
		return body, nil
	end

	local studioOk, studioBody = pcall(function()
		return HttpService:GetAsync(url, true)
	end)
	if studioOk and type(studioBody) == "string" then
		return studioBody, nil
	end
	local reason = if not studioOk then studioBody else body
	return nil, tostring(reason or "HTTP request failed")
end

function Env.GetCustomAsset(path: string): string?
	if type(customAsset) ~= "function" then
		return nil
	end
	local ok, result = pcall(customAsset, path)
	if not ok or type(result) ~= "string" or result == "" then
		return nil
	end
	return result
end

local setclipboard = tryGlobal("setclipboard") or tryGlobal("toclipboard")
local getclipboard = tryGlobal("getclipboard") or tryGlobal("fromclipboard")

function Env.SetClipboard(text: string): boolean
	if not setclipboard then
		return false
	end
	return (pcall(setclipboard, text))
end
function Env.GetClipboard(): string?
	if not getclipboard then
		return nil
	end
	local ok, value = pcall(getclipboard)
	if not ok or value == nil then
		return nil
	end
	return tostring(value)
end

-- ===== GUI parent =================================================
--[[
	Preference order, per the architecture doc (A.5):
	  gethui()  ->  CoreGui  ->  PlayerGui
	CoreGui is probed by actually parenting a throwaway Folder; asking for the
	service succeeds even when writing to it does not.
]]

local gethui = tryGlobal("gethui")
local protectGui = tryGlobal("protect_gui")
if not protectGui then
	local syn = tryGlobal("syn")
	if type(syn) == "table" then
		protectGui = syn.protect_gui
	end
end

local cachedParent: Instance? = nil

function Env.GetGuiParent(): Instance
	if cachedParent and cachedParent.Parent ~= nil then
		return cachedParent
	end

	if gethui then
		local ok, hidden = pcall(gethui)
		if ok and typeof(hidden) == "Instance" then
			cachedParent = hidden
			return hidden
		end
	end

	local ok, coreGui = pcall(function()
		local service = game:GetService("CoreGui")
		local probe = Instance.new("Folder")
		probe.Parent = service
		probe:Destroy()
		return service
	end)
	if ok and coreGui then
		cachedParent = coreGui
		return coreGui
	end

	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		or Players.LocalPlayer:WaitForChild("PlayerGui")
	cachedParent = playerGui
	return playerGui
end

function Env.Protect(gui: Instance)
	if protectGui then
		pcall(protectGui, gui)
	end
end

-- ===== capability summary =========================================

Env.Capabilities = {
	Filesystem = Env.FS ~= nil,
	Http = requestFunction ~= nil or not Env.IsStudio,
	CustomAsset = customAsset ~= nil,
	HiddenUI = gethui ~= nil,
	ProtectGui = protectGui ~= nil,
	Clipboard = setclipboard ~= nil,
	ClipboardRead = getclipboard ~= nil,
	SharedGlobals = Env.HasSharedGlobals,
}

function Env.Describe(): string
	local flags = {}
	for name, enabled in Env.Capabilities do
		if enabled then
			table.insert(flags, name)
		end
	end
	table.sort(flags)
	local list = if #flags > 0 then table.concat(flags, ", ") else "none"
	return `{Env.Executor} [{list}]`
end

return Env
