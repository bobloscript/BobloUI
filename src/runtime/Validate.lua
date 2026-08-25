--!nonstrict
local Manifest = require("@runtime/RuntimeManifest")
local Util = require("@runtime/Util")
local Validate = {}
local Components = Manifest.Components or Manifest
local Common = Manifest.Common or {}

local function optionsFor(spec)
	local options = {}
	for key, value in Common do
		options[key] = value
	end
	for key, value in spec.Options or {} do
		options[key] = value
	end
	return options
end

local function matches(value, spec)
	if value == nil then
		return string.find(spec, "?", 1, true) ~= nil or spec == "any?"
	end
	if string.find(spec, "any", 1, true) then
		return true
	end
	for part in string.gmatch(spec, "[^|]+") do
		part = string.gsub(part, "%?", "")
		if part == "string" and type(value) == "string" then
			return true
		elseif part == "number" and type(value) == "number" then
			return true
		elseif part == "boolean" and type(value) == "boolean" then
			return true
		elseif part == "function" and type(value) == "function" then
			return true
		elseif part == "table" and type(value) == "table" then
			return true
		elseif part == "Color3" and typeof(value) == "Color3" then
			return true
		elseif part == "Vector2" and typeof(value) == "Vector2" then
			return true
		elseif part == "Instance" and typeof(value) == "Instance" then
			return true
		elseif part == "EnumItem" and typeof(value) == "EnumItem" then
			return true
		end
	end
	return false
end

function Validate.Collect(typeName, options, path)
	local errors = {}
	local spec = Components[typeName]
	path = path or typeName
	if not spec then
		return { `{path}: unknown control type "{typeName}"` }
	end
	if type(options) ~= "table" then
		return { `{path}: expected an options table` }
	end
	if typeName == "Dropdown" and options.Options == nil and options.Values == nil and options.Source == nil then
		table.insert(errors, `{path}: requires Options, Values, or Source`)
	end
	local available = optionsFor(spec)
	local names = {}
	for k in available do
		table.insert(names, k)
	end
	table.sort(names)
	for _, key in spec.Required or {} do
		if options[key] == nil then
			table.insert(errors, `{path}.{key}: required option is missing`)
		end
	end
	for key, value in options do
		local expected = available[key]
		if not expected then
			local suggestion = Util.suggest(tostring(key), names)
			local hint = if suggestion then ` Did you mean "{suggestion}"?` else ""
			table.insert(errors, `{path}.{tostring(key)}: unknown option.{hint}`)
		elseif not matches(value, expected) then
			table.insert(errors, `{path}.{key}: expected {expected}, got {typeof(value)}`)
		end
	end
	return errors
end

function Validate.Control(typeName, options)
	local spec = Components[typeName]
	if not spec then
		error(`[BobloUI] unknown control type "{typeName}".`, 3)
	end
	if type(options) ~= "table" then
		error(`[BobloUI] {spec.Method} expects an options table.`, 3)
	end
	if typeName == "Dropdown" and options.Options == nil and options.Values == nil and options.Source == nil then
		error("[BobloUI] AddDropdown requires Options, Values, or Source.", 3)
	end
	for _, key in spec.Required or {} do
		if options[key] == nil then
			error(`[BobloUI] {spec.Method}: required option "{key}" is missing.`, 3)
		end
	end
	local available = optionsFor(spec)
	local names = {}
	for k in available do
		table.insert(names, k)
	end
	table.sort(names)
	for key, value in options do
		local expected = available[key]
		if not expected then
			local suggestion = Util.suggest(tostring(key), names)
			local hint = if suggestion then ' Did you mean "' .. suggestion .. '"?' else ""
			warn(`[BobloUI] {spec.Method}: unknown option "{key}".{hint}\nValid options: {table.concat(names, ", ")}`)
		elseif not matches(value, expected) then
			error(`[BobloUI] {spec.Method}: option "{key}" expected {expected}, got {typeof(value)}.`, 3)
		end
	end
	return options
end
return Validate
