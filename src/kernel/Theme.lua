--!nonstrict
--[[
	Theme — palette registry + binding registry.

	The binding registry is the point of this module. Every coloured property is
	registered once at creation:

		theme:Bind(frame, "BackgroundColor3", "Surface")

	A theme change is then a single pass over one flat array, instead of walking
	the Instance tree with a pcall per property. At 200 controls that is roughly
	2000 assignments — fine as a one-off, catastrophic as a tree walk.

	Deliberately NOT tweened. 2000 concurrent tweens is the single most
	expensive thing a Roblox UI can do; Window covers the swap with one short
	fade instead.
]]

local Signal = require("@runtime/Signal")
local Util = require("@runtime/Util")

local Theme = {}
Theme.__index = Theme

function Theme.new(options)
	options = options or {}

	local self = setmetatable({
		Changed = Signal.new("Theme.Changed"),

		_palettes = {},
		_meta = {},
		_recent = {},
		_name = nil,
		_base = nil,
		_resolved = nil,
		_accent = options.Accent,
		_overrides = {},
		_highContrast = false,

		_bindings = {},
		_free = {},
		_dropped = 0,
	}, Theme)

	if options.Palettes then
		for name, palette in options.Palettes do
			self:Register(name, palette)
		end
	end

	return self
end

-- ===== palettes ===================================================

function Theme:Register(name: string, palette)
	palette = table.clone(palette)
	if palette.ScrimTransparency == nil then
		-- Compatibility for custom themes saved before the alpha token existed.
		palette.ScrimTransparency = 0.52
	end
	-- Appearance/Pair describe the palette, they are not colour tokens. Keeping
	-- them out of the palette means _resolve never sees a string where it
	-- expects a Color3, and SetToken cannot be aimed at them.
	self._meta[name] = {
		Appearance = (palette.Appearance == "Dark" or palette.Appearance == "Light") and palette.Appearance or nil,
		Pair = type(palette.Pair) == "string" and palette.Pair or nil,
	}
	palette.Appearance = nil
	palette.Pair = nil
	self._palettes[name] = palette
	if self._name == name then
		self:_resolve()
		self:_apply()
	end
end
function Theme:GetRegistered(name)
	local palette = self._palettes[name]
	return palette and table.clone(palette) or nil
end
function Theme:Unregister(name)
	if name == self._name then
		error("[BobloUI] cannot unregister the active theme.", 2)
	end
	self._palettes[name] = nil
	self._meta[name] = nil
	for polarity, remembered in self._recent do
		if remembered == name then
			self._recent[polarity] = nil
		end
	end
	return self
end

function Theme:List(): { string }
	local names = Util.keys(self._palettes)
	table.sort(names)
	return names
end

function Theme:Current(): string?
	return self._name
end

-- ===== light/dark polarity ========================================
--
-- "Dark" and "Light" are the two built-in themes AND the two appearance
-- polarities. Every registered palette belongs to one of them, so a custom
-- theme takes part in light/dark switching without being named Dark or Light.
--
-- Polarity is derived from Canvas luminance — the same test _resolve uses for
-- high contrast. A palette can override the guess with Appearance = "Dark" |
-- "Light", which matters for saturated palettes sitting near the midpoint.

function Theme:Polarity(name: string?): string?
	local key = name or self._name
	local palette = self._palettes[key]
	if not palette then
		return nil
	end
	local meta = self._meta[key]
	if meta and meta.Appearance then
		return meta.Appearance
	end
	return if Util.luminance(palette.Canvas) < 0.5 then "Dark" else "Light"
end

--[[
	The theme a light/dark toggle should switch to, in priority order:

	  1. the counterpart this theme declares via Pair
	  2. the last theme the user actually used at that polarity
	  3. the built-in Dark/Light
	  4. any registered theme of that polarity

	Rule 2 is what makes the toggle feel right. A user on their own dark theme
	toggles to Light and back, and lands on *their* theme rather than the
	built-in Dark. Once they have themes on both sides, the toggle moves between
	those two and never shows a built-in again.

	Returns the current theme when nothing of the opposite polarity exists, so
	callers can always feed the result straight into Set.
]]
function Theme:Counterpart(): string?
	local current = self._name
	if not current then
		return nil
	end
	local target = if self:Polarity(current) == "Dark" then "Light" else "Dark"

	local meta = self._meta[current]
	if meta and meta.Pair and self._palettes[meta.Pair] and self:Polarity(meta.Pair) == target then
		return meta.Pair
	end

	local remembered = self._recent[target]
	if remembered and self._palettes[remembered] and self:Polarity(remembered) == target then
		return remembered
	end

	if self._palettes[target] and self:Polarity(target) == target then
		return target
	end

	for _, candidate in self:List() do
		if self:Polarity(candidate) == target then
			return candidate
		end
	end
	return current
end

-- Persistence hooks: ThemeManager restores these at startup so the toggle
-- remembers across sessions instead of falling back to a built-in once.
function Theme:RecentByPolarity(): { [string]: string }
	return table.clone(self._recent)
end

function Theme:RememberPolarity(polarity: string, name: string)
	if polarity ~= "Dark" and polarity ~= "Light" then
		return self
	end
	if self._palettes[name] and self:Polarity(name) == polarity then
		self._recent[polarity] = name
	end
	return self
end

-- Interaction and foreground tokens are derived once per theme application.
-- Authors only need the 26 base colours plus ScrimTransparency, while advanced
-- themes may explicitly override any derived token.
function Theme:_resolve()
	local base = self._palettes[self._name]
	if not base then
		error(`[BobloUI] theme "{tostring(self._name)}" is not registered`, 2)
	end

	local palette = table.clone(base)

	if self._accent ~= nil then
		palette.Accent = self._accent
	end

	-- Apply base-token overrides before computing semantic derivatives so a
	-- custom Surface/Border immediately influences AccentSoft/Button/etc.
	for token, value in self._overrides do
		if value ~= nil then
			palette[token] = value
		end
	end

	palette.ScrimTransparency = math.clamp(tonumber(palette.ScrimTransparency) or 0.52, 0, 1)

	if self._highContrast then
		local dark = Util.luminance(palette.Canvas) < 0.5
		if dark then
			palette.Text = Color3.new(1, 1, 1)
			palette.TextSecondary = Color3.fromRGB(214, 218, 225)
			palette.BorderSubtle = Color3.fromRGB(58, 64, 74)
			palette.Border = Color3.fromRGB(78, 85, 97)
		else
			palette.Text = Color3.new(0, 0, 0)
			palette.TextSecondary = Color3.fromRGB(48, 54, 64)
			palette.BorderSubtle = Color3.fromRGB(190, 196, 205)
			palette.Border = Color3.fromRGB(160, 168, 179)
		end
	end

	local accentChanged = self._accent ~= nil or self._overrides.Accent ~= nil
	local surfaceChanged = self._overrides.Surface ~= nil or self._overrides.Background ~= nil
	local function derived(name, fallback, force)
		if self._overrides[name] ~= nil then
			return self._overrides[name]
		end
		if not force and base[name] ~= nil then
			return base[name]
		end
		return fallback
	end

	local mixBase = palette.Surface or palette.Background
	palette.AccentHover = derived("AccentHover", Util.lighten(palette.Accent, 0.12), accentChanged)
	palette.AccentPressed = derived("AccentPressed", Util.darken(palette.Accent, 0.12), accentChanged)
	palette.AccentSoft = derived("AccentSoft", palette.Accent:Lerp(mixBase, 0.90), accentChanged or surfaceChanged)
	palette.AccentMuted = derived("AccentMuted", palette.Accent:Lerp(mixBase, 0.72), accentChanged or surfaceChanged)
	palette.AccentBorder = derived(
		"AccentBorder",
		palette.Accent:Lerp(palette.Border or mixBase, 0.48),
		accentChanged or self._overrides.Border ~= nil or self._highContrast
	)
	palette.AccentGlow = derived(
		"AccentGlow",
		palette.Accent:Lerp(palette.Canvas or mixBase, 0.58),
		accentChanged or self._overrides.Canvas ~= nil
	)
	palette.SurfaceSheen = derived(
		"SurfaceSheen",
		mixBase:Lerp(palette.Text, 0.07),
		surfaceChanged or self._overrides.Text ~= nil or self._highContrast
	)

	-- Primary actions stay recognisable without becoming a flat neon slab.
	palette.AccentButton = derived("AccentButton", palette.Accent:Lerp(mixBase, 0.50), accentChanged or surfaceChanged)
	palette.AccentButtonHover =
		derived("AccentButtonHover", palette.Accent:Lerp(mixBase, 0.40), accentChanged or surfaceChanged)
	palette.AccentButtonPressed =
		derived("AccentButtonPressed", palette.Accent:Lerp(mixBase, 0.58), accentChanged or surfaceChanged)
	palette.ErrorHover = derived("ErrorHover", Util.lighten(palette.Error, 0.08), self._overrides.Error ~= nil)
	palette.ErrorPressed = derived("ErrorPressed", Util.darken(palette.Error, 0.05), self._overrides.Error ~= nil)

	local compatibilityAccentText = self._overrides.AccentText
		or (if not accentChanged then base.TextOnAccent or base.AccentText else nil)
	palette.TextOnAccent =
		derived("TextOnAccent", compatibilityAccentText or Util.contrastText(palette.Accent), accentChanged)
	palette.TextOnAccentButton =
		derived("TextOnAccentButton", Util.contrastText(palette.AccentButton), accentChanged or surfaceChanged)
	palette.TextOnSuccess = derived("TextOnSuccess", Util.contrastText(palette.Success), self._overrides.Success ~= nil)
	palette.TextOnWarning = derived("TextOnWarning", Util.contrastText(palette.Warning), self._overrides.Warning ~= nil)
	palette.TextOnError = derived("TextOnError", Util.contrastText(palette.Error), self._overrides.Error ~= nil)
	palette.TextOnInfo = derived("TextOnInfo", Util.contrastText(palette.Info), self._overrides.Info ~= nil)
	-- Deprecated compatibility alias. Components use the exact TextOn* token.
	palette.AccentText = palette.TextOnAccent

	self._base = base
	self._resolved = palette
end

function Theme:Palette()
	return table.clone(self._resolved)
end

function Theme:Get(token): any
	if type(token) == "function" then
		return token(self._resolved)
	end
	local value = self._resolved[token]
	if value == nil then
		local suggestion = Util.suggest(token, Util.keys(self._resolved))
		local hint = if suggestion then ` Did you mean "{suggestion}"?` else ""
		error(`[BobloUI] unknown theme token "{token}".{hint}`, 2)
	end
	return value
end

function Theme:Set(name: string)
	if not self._palettes[name] then
		local suggestion = Util.suggest(name, self:List())
		local hint = if suggestion then ` Did you mean "{suggestion}"?` else ""
		error(`[BobloUI] theme "{name}" is not registered.{hint}`, 2)
	end
	if self._name == name then
		return
	end
	self._name = name
	local polarity = self:Polarity(name)
	if polarity then
		self._recent[polarity] = name
	end
	self:_resolve()
	self:_apply()
	self.Changed:Fire(name)
end

function Theme:SetAccent(colour: Color3?)
	self._accent = colour
	self:_resolve()
	self:_apply()
	self.Changed:Fire(self._name)
end

function Theme:SetToken(token, value)
	if self._resolved and self._resolved[token] == nil then
		error(`[BobloUI] cannot override unknown theme token "{tostring(token)}".`, 2)
	end
	local expected = self._resolved and typeof(self._resolved[token])
	if value ~= nil and typeof(value) ~= expected then
		error(`[BobloUI] Theme:SetToken expects {tostring(expected)} or nil for "{tostring(token)}".`, 2)
	end
	if token == "ScrimTransparency" and value ~= nil then
		value = math.clamp(value, 0, 1)
	end
	self._overrides[token] = value
	self:_resolve()
	self:_apply()
	self.Changed:Fire(self._name)
	return self
end
function Theme:GetOverrides()
	return table.clone(self._overrides)
end
function Theme:ResetToken(token)
	return self:SetToken(token, nil)
end
function Theme:ResetOverrides()
	self._overrides = {}
	self:_resolve()
	self:_apply()
	self.Changed:Fire(self._name)
	return self
end
function Theme:SetHighContrast(enabled)
	enabled = enabled == true
	if self._highContrast == enabled then
		return self
	end
	self._highContrast = enabled
	self:_resolve()
	self:_apply()
	self.Changed:Fire(self._name)
	return self
end
function Theme:IsHighContrast()
	return self._highContrast
end
function Theme:Export()
	local data = { Theme = self._name, HighContrast = self._highContrast, Overrides = {} }
	if self._accent then
		data.Accent = "#" .. self._accent:ToHex()
	end
	for token, value in self._overrides do
		if typeof(value) == "Color3" then
			data.Overrides[token] = "#" .. value:ToHex()
		elseif type(value) == "number" then
			data.Overrides[token] = value
		end
	end
	return data
end
function Theme:Import(data)
	if type(data) ~= "table" then
		return false, "theme import expects table"
	end
	if data.Theme and self._palettes[data.Theme] then
		self._name = data.Theme
	end
	self._accent = nil
	if type(data.Accent) == "string" then
		local ok, c = pcall(Color3.fromHex, string.gsub(data.Accent, "#", ""))
		if ok then
			self._accent = c
		end
	end
	self._overrides = {}
	for token, value in data.Overrides or {} do
		if self._resolved[token] ~= nil and type(value) == "string" and typeof(self._resolved[token]) == "Color3" then
			local ok, c = pcall(Color3.fromHex, string.gsub(value, "#", ""))
			if ok then
				self._overrides[token] = c
			end
		elseif self._resolved[token] ~= nil and type(value) == "number" and type(self._resolved[token]) == "number" then
			self._overrides[token] = if token == "ScrimTransparency" then math.clamp(value, 0, 1) else value
		end
	end
	self._highContrast = data.HighContrast == true
	self:_resolve()
	self:_apply()
	self.Changed:Fire(self._name)
	return true
end

-- ===== bindings ===================================================

--[[
	Bind(instance, property, token) -> handle

	The handle must be stored in the owner's Janitor. BaseControl does this
	automatically (step 7); shell code does it explicitly.
]]
function Theme:Bind(instance: Instance, property: string, token): number
	local binding = { instance = instance, property = property, token = token }

	local slot = table.remove(self._free)
	if slot then
		self._bindings[slot] = binding
	else
		table.insert(self._bindings, binding)
		slot = #self._bindings
	end

	if self._resolved then
		instance[property] = self:Get(token)
	end

	return slot
end

--- Bind several properties of one instance. Returns a single handle.
function Theme:BindMany(instance: Instance, map: { [string]: any }): { number }
	local handles = {}
	for property, token in map do
		table.insert(handles, self:Bind(instance, property, token))
	end
	return handles
end

function Theme:Unbind(handle)
	if type(handle) == "table" then
		for _, single in handle do
			self:Unbind(single)
		end
		return
	end
	if self._bindings[handle] then
		self._bindings[handle] = false
		table.insert(self._free, handle)
	end
end

function Theme:_apply()
	local bindings = self._bindings
	local dropped = 0

	for slot = 1, #bindings do
		local binding = bindings[slot]
		if binding then
			local ok = pcall(function()
				binding.instance[binding.property] = self:Get(binding.token)
			end)
			if not ok then
				-- Instance destroyed without unbinding. Reclaim the slot.
				bindings[slot] = false
				table.insert(self._free, slot)
				dropped += 1
			end
		end
	end

	self._dropped += dropped
	if dropped > 0 then
		-- Not fatal, but it means some owner forgot its Janitor entry.
		warn(`[BobloUI] Theme dropped {dropped} binding(s) to destroyed instances.`)
	end
end

function Theme:BindingCount(): number
	local n = 0
	for _, binding in self._bindings do
		if binding then
			n += 1
		end
	end
	return n
end

function Theme:Destroy()
	self._bindings = {}
	self._free = {}
	self.Changed:Destroy()
end

return Theme
