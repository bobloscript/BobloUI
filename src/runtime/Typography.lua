--!nonstrict
--[[
	Typography — default Figtree family with a safe BuilderSans fallback.

	Figtree is not bundled with Roblox, so executor builds cache the four font
	faces from BobloUI's own GitHub repository and register a local .font family.
	Studio and executors without filesystem/custom-asset support keep working with
	the caller-provided fallback fonts.
]]

local HttpService = game:GetService("HttpService")
local Env = require("@runtime/Env")

local Typography = {}

local BASE_URL = "https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/assets/bobloui/fonts/"
local CACHE_ROOT = "BobloUI/assets/fonts"
local FAMILY_PATH = CACHE_ROOT .. "/Figtree.font"
local FACES = {
	{ Key = "Regular", File = "Figtree-Regular.ttf", Bytes = 57504, Weight = 400, Enum = Enum.FontWeight.Regular },
	{ Key = "Medium", File = "Figtree-Medium.ttf", Bytes = 57316, Weight = 500, Enum = Enum.FontWeight.Medium },
	{ Key = "Bold", File = "Figtree-Bold.ttf", Bytes = 57672, Weight = 700, Enum = Enum.FontWeight.Bold },
	{ Key = "Heavy", File = "Figtree-ExtraBold.ttf", Bytes = 57928, Weight = 800, Enum = Enum.FontWeight.ExtraBold },
}

local status = "Idle"
local lastError = nil
local preparedFonts = nil
local warned = false

local function fallback(fonts, message)
	status = "Fallback"
	lastError = message
	preparedFonts = table.clone(fonts)
	if not warned then
		warn(`[BobloUI] Figtree unavailable ({message}); using BuilderSans fallback.`)
		warned = true
	end
	return table.clone(preparedFonts)
end

local function ensureFolders()
	if not Env.FS then
		return false
	end
	for _, folder in { "BobloUI", "BobloUI/assets", CACHE_ROOT } do
		if not Env.FS.IsFolder(folder) and not Env.FS.MakeFolder(folder) then
			return false
		end
	end
	return true
end

local function validFont(data, expectedBytes)
	if type(data) ~= "string" or #data ~= expectedBytes then
		return false
	end
	local signature = string.sub(data, 1, 4)
	return signature == "\0\1\0\0" or signature == "OTTO"
end

local function loadFace(face)
	local path = CACHE_ROOT .. "/" .. face.File
	local contents = if Env.FS.IsFile(path) then Env.FS.Read(path) else nil
	if not validFont(contents, face.Bytes) then
		local downloaded, httpError = Env.HttpGet(BASE_URL .. face.File)
		if not validFont(downloaded, face.Bytes) then
			return nil, httpError or `{face.File} failed font validation`
		end
		if not Env.FS.Write(path, downloaded) then
			return nil, `cannot write {face.File} to the font cache`
		end
	end
	local asset = Env.GetCustomAsset(path)
	if not asset then
		return nil, `custom asset registration failed for {face.File}`
	end
	return asset, nil
end

function Typography.Prepare(fallbackFonts)
	if preparedFonts then
		return table.clone(preparedFonts)
	end
	if not Env.FS or not Env.Capabilities.CustomAsset then
		return fallback(fallbackFonts, "executor has no filesystem/custom-asset API")
	end
	if not ensureFolders() then
		return fallback(fallbackFonts, "cannot create the font cache folder")
	end

	status = "Preparing"
	local familyFaces = {}
	for _, face in FACES do
		local asset, loadError = loadFace(face)
		if not asset then
			return fallback(fallbackFonts, loadError or "font face preparation failed")
		end
		table.insert(familyFaces, {
			name = face.Key,
			weight = face.Weight,
			style = "normal",
			assetId = asset,
		})
	end

	local encoded = HttpService:JSONEncode({ name = "Figtree", faces = familyFaces })
	if not Env.FS.Write(FAMILY_PATH, encoded) then
		return fallback(fallbackFonts, "cannot write the Figtree family file")
	end
	local familyAsset = Env.GetCustomAsset(FAMILY_PATH)
	if not familyAsset then
		return fallback(fallbackFonts, "custom family registration failed")
	end

	local ok, fonts = pcall(function()
		local out = {}
		for _, face in FACES do
			out[face.Key] = Font.new(familyAsset, face.Enum, Enum.FontStyle.Normal)
		end
		return out
	end)
	if not ok then
		return fallback(fallbackFonts, tostring(fonts))
	end

	preparedFonts = fonts
	status = "Ready"
	lastError = nil
	return table.clone(preparedFonts)
end

function Typography.GetStatus()
	return status, lastError
end

return Typography
