--!nonstrict
--[[ Util — dependency-free helpers. Level 0: requires nothing. ]]

local Util = {}

-- ===== tables =====================================================

function Util.assign(target: { [any]: any }, ...): { [any]: any }
	for index = 1, select("#", ...) do
		local source = select(index, ...)
		if source then
			for key, value in source do
				target[key] = value
			end
		end
	end
	return target
end

function Util.copy(source: { [any]: any }): { [any]: any }
	return table.clone(source)
end

function Util.deepCopy(source: any, seen: { [any]: any }?): any
	if type(source) ~= "table" then
		return source
	end
	seen = seen or {}
	if seen[source] ~= nil then
		return seen[source]
	end
	local out = {}
	seen[source] = out
	for key, value in source do
		out[key] = Util.deepCopy(value, seen)
	end
	return out
end

function Util.keys(source: { [any]: any }): { any }
	local out = {}
	for key in source do
		table.insert(out, key)
	end
	return out
end

-- ===== numbers ====================================================

function Util.lerp(from: number, to: number, alpha: number): number
	return from + (to - from) * alpha
end

function Util.round(value: number, step: number?): number
	local increment = step or 1
	return math.round(value / increment) * increment
end

-- ===== strings ====================================================

function Util.trim(text: string): string
	local trimmed = text:gsub("^%s+", "")
	trimmed = trimmed:gsub("%s+$", "")
	return trimmed
end

function Util.startsWith(text: string, prefix: string): boolean
	return text:sub(1, #prefix) == prefix
end

--- Normalises free text into a safe Id: lowercase, [a-z0-9._-], no repeats.
function Util.slug(text: string): string
	local out = text:lower()
	out = out:gsub("[^%w%.%-_]+", "-")
	out = out:gsub("%-+", "-")
	out = out:gsub("^%-+", "")
	out = out:gsub("%-+$", "")
	return out ~= "" and out or "untitled"
end

function Util.levenshtein(a: string, b: string): number
	if a == b then
		return 0
	end
	local lenA, lenB = #a, #b
	if lenA == 0 then
		return lenB
	end
	if lenB == 0 then
		return lenA
	end

	local previous = table.create(lenB + 1)
	for j = 0, lenB do
		previous[j + 1] = j
	end

	for i = 1, lenA do
		local current = table.create(lenB + 1)
		current[1] = i
		local charA = a:byte(i)
		for j = 1, lenB do
			local cost = if charA == b:byte(j) then 0 else 1
			current[j + 1] = math.min(current[j] + 1, previous[j + 1] + 1, previous[j] + cost)
		end
		previous = current
	end

	return previous[lenB + 1]
end

--[[
	Best "did you mean" candidate, or nil when nothing is close enough.
	Feeds the learning error messages described in the architecture doc (G.2).
]]
function Util.suggest(word: string, candidates: { string }): string?
	local lowered = word:lower()
	local best, bestDistance = nil, math.huge
	local limit = math.max(2, math.floor(#word / 3))

	for _, candidate in candidates do
		local distance = Util.levenshtein(lowered, candidate:lower())
		if distance < bestDistance then
			best, bestDistance = candidate, distance
		end
	end

	if best and bestDistance <= limit then
		return best
	end
	return nil
end

-- ===== colour =====================================================

function Util.hex(value: string): Color3
	return Color3.fromHex(value)
end

function Util.toHex(colour: Color3): string
	return "#" .. colour:ToHex()
end

function Util.mix(from: Color3, to: Color3, alpha: number): Color3
	return from:Lerp(to, alpha)
end

function Util.lighten(colour: Color3, amount: number): Color3
	return colour:Lerp(Color3.new(1, 1, 1), amount)
end

function Util.darken(colour: Color3, amount: number): Color3
	return colour:Lerp(Color3.new(0, 0, 0), amount)
end

local function linearChannel(channel: number): number
	if channel <= 0.04045 then
		return channel / 12.92
	end
	return ((channel + 0.055) / 1.055) ^ 2.4
end

--- WCAG relative luminance (sRGB channels are linearised before weighting).
function Util.luminance(colour: Color3): number
	return 0.2126 * linearChannel(colour.R) + 0.7152 * linearChannel(colour.G) + 0.0722 * linearChannel(colour.B)
end

function Util.contrastRatio(first: Color3, second: Color3): number
	local a = Util.luminance(first)
	local b = Util.luminance(second)
	local lighter = math.max(a, b)
	local darker = math.min(a, b)
	return (lighter + 0.05) / (darker + 0.05)
end

--- Choose the more readable standard foreground for an arbitrary background.
function Util.contrastText(background: Color3): Color3
	-- Pure endpoints guarantee that at least one candidate reaches WCAG AA for
	-- normal text on every possible sRGB background.
	local dark = Color3.new(0, 0, 0)
	local light = Color3.new(1, 1, 1)
	return if Util.contrastRatio(background, dark) >= Util.contrastRatio(background, light) then dark else light
end

-- ===== misc =======================================================

function Util.now(): number
	return os.clock()
end

return Util
