local Theme = __require("kernel/Theme")

local function expect(actual, expected, label)
	if actual ~= expected then
		error(`{label}: expected {tostring(expected)}, got {tostring(actual)}`)
	end
end

-- Minimal palettes: Polarity only reads Canvas, and nothing here calls _apply
-- against real Instances, so the 26-colour contract is not needed to test the
-- light/dark selection logic.
local function palette(canvas, extra)
	local out = {
		Canvas = canvas,
		Accent = Color3.fromRGB(120, 140, 255),
		ScrimTransparency = 0.5,
	}
	for key, value in pairs(extra or {}) do
		out[key] = value
	end
	return out
end

local DARK = Color3.fromRGB(18, 20, 24)
local LIGHT = Color3.fromRGB(245, 246, 248)

local function newTheme(palettes)
	local theme = Theme.new()
	for name, p in pairs(palettes) do
		theme:Register(name, p)
	end
	-- _resolve/_apply need the full token set; the specs below only exercise
	-- registry-level selection, so drive _name directly where Set would resolve.
	return theme
end

local function activate(theme, name)
	theme._name = name
	theme._recent[theme:Polarity(name)] = name
end

do
	local theme = newTheme({
		Dark = palette(DARK),
		Light = palette(LIGHT),
		Midnight = palette(Color3.fromRGB(12, 14, 20)),
		Paper = palette(Color3.fromRGB(250, 250, 250)),
	})
	expect(theme:Polarity("Dark"), "Dark", "built-in Dark is dark")
	expect(theme:Polarity("Light"), "Light", "built-in Light is light")
	expect(theme:Polarity("Midnight"), "Dark", "dark custom palette detected by luminance")
	expect(theme:Polarity("Paper"), "Light", "light custom palette detected by luminance")
	expect(theme:Polarity("Nope"), nil, "unknown theme has no polarity")
end

do
	-- A saturated mid-luminance palette is exactly the case luminance gets
	-- wrong, so Appearance must win over the guess.
	local theme = newTheme({
		Ember = palette(Color3.fromRGB(140, 60, 30), { Appearance = "Dark" }),
	})
	expect(theme:Polarity("Ember"), "Dark", "declared Appearance overrides luminance")
	expect(theme._palettes.Ember.Appearance, nil, "metadata is kept out of the palette")
end

do
	-- The core promise: toggling away from a custom theme and back returns to
	-- that custom theme, not to the built-in.
	local theme = newTheme({
		Dark = palette(DARK),
		Light = palette(LIGHT),
		Midnight = palette(Color3.fromRGB(12, 14, 20)),
	})
	activate(theme, "Midnight")
	expect(theme:Counterpart(), "Light", "no light custom theme yet, so built-in Light")
	activate(theme, "Light")
	expect(theme:Counterpart(), "Midnight", "returns to the remembered custom dark theme")
end

do
	local theme = newTheme({
		Dark = palette(DARK),
		Light = palette(LIGHT),
		Midnight = palette(Color3.fromRGB(12, 14, 20)),
		Paper = palette(Color3.fromRGB(250, 250, 250)),
	})
	activate(theme, "Midnight")
	activate(theme, "Paper")
	expect(theme:Counterpart(), "Midnight", "toggle moves between the user's own pair")
	activate(theme, "Midnight")
	expect(theme:Counterpart(), "Paper", "and back again, never showing a built-in")
end

do
	-- An explicit Pair beats the remembered theme.
	local theme = newTheme({
		Dark = palette(DARK),
		Light = palette(LIGHT),
		Neon = palette(Color3.fromRGB(10, 12, 18), { Pair = "NeonDay" }),
		NeonDay = palette(Color3.fromRGB(248, 248, 252)),
		Paper = palette(Color3.fromRGB(250, 250, 250)),
	})
	activate(theme, "Paper")
	activate(theme, "Neon")
	expect(theme:Counterpart(), "NeonDay", "declared Pair wins over the remembered light theme")
end

do
	-- A Pair pointing at the same polarity is meaningless and must be ignored.
	local theme = newTheme({
		Dark = palette(DARK),
		Light = palette(LIGHT),
		Neon = palette(Color3.fromRGB(10, 12, 18), { Pair = "AlsoDark" }),
		AlsoDark = palette(Color3.fromRGB(16, 18, 22)),
	})
	activate(theme, "Neon")
	expect(theme:Counterpart(), "Light", "same-polarity Pair is ignored")
end

do
	-- Unregistering the remembered theme must not leave a dangling name.
	local theme = newTheme({
		Dark = palette(DARK),
		Light = palette(LIGHT),
		Midnight = palette(Color3.fromRGB(12, 14, 20)),
	})
	activate(theme, "Midnight")
	activate(theme, "Light")
	theme:Unregister("Midnight")
	expect(theme:Counterpart(), "Dark", "falls back to the built-in after the theme is removed")
	expect(theme:RecentByPolarity().Dark, nil, "stale memory is cleared on unregister")
end

do
	-- Restoring persisted memory only accepts themes that still exist and still
	-- have the polarity claimed for them.
	local theme = newTheme({
		Dark = palette(DARK),
		Light = palette(LIGHT),
		Midnight = palette(Color3.fromRGB(12, 14, 20)),
	})
	theme:RememberPolarity("Dark", "Midnight")
	theme:RememberPolarity("Light", "Gone")
	theme:RememberPolarity("Dark", "Light")
	expect(theme:RecentByPolarity().Dark, "Midnight", "valid restore is accepted")
	expect(theme:RecentByPolarity().Light, nil, "missing theme is rejected")
end

do
	-- Only one polarity registered: Counterpart must stay callable and return
	-- something Set will accept.
	local theme = newTheme({ Midnight = palette(Color3.fromRGB(12, 14, 20)) })
	activate(theme, "Midnight")
	expect(theme:Counterpart(), "Midnight", "no opposite polarity means no switch")
end

print("theme.spec.lua: ok")
