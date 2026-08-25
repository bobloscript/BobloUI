--!nonstrict
-- BobloUI icon primitive.
-- Lucide sprites are the primary renderer when the executor can cache GitHub
-- PNGs as local custom assets. GuiObject glyphs remain the mandatory asset-free
-- fallback, so missing HTTP/filesystem capabilities never break the UI.
local Create = require("@runtime/Create")
local Lucide = require("@primitives/Lucide")

local Icon = {
	Registry = {},
	Aliases = {
		close = "x",
		dashboard = "layout-dashboard",
		home = "house",
		player = "user",
		visuals = "eye",
		reset = "rotate-ccw",
		shop = "shopping-cart",
		game = "gamepad-2",
		magic = "wand-sparkles",
	},
	FallbackAliases = {
		accessibility = "settings",
		["app-window"] = "panel",
		["audio-lines"] = "controls",
		blend = "palette",
		["chevron-down"] = "chevron_down",
		["chevron-right"] = "chevron_right",
		["chevron-up"] = "chevron_up",
		["circle-check"] = "check",
		["circle-question-mark"] = "info",
		["circle-x"] = "close",
		["file-pen"] = "edit",
		["folder-cog"] = "folder",
		["folder-open"] = "folder",
		languages = "globe",
		["layout-template"] = "layout",
		["list-check"] = "list",
		["loader-circle"] = "progress",
		["mouse-pointer-2"] = "controls",
		paintbrush = "palette",
		["panel-left"] = "panel",
		pipette = "palette",
		["rotate-ccw"] = "reset",
		["rows-3"] = "list",
		["settings-2"] = "settings",
		["square-round-corner"] = "panel",
		["sun-medium"] = "moon",
		["sun-moon"] = "moon",
		["swatch-book"] = "palette",
		["text-cursor-input"] = "edit",
		["triangle-alert"] = "info",
		["volume-2"] = "controls",
		x = "close",
		["zoom-in"] = "plus",
	},
	Count = Lucide.Count,
	Source = Lucide.Source,
}

local function normalizeName(name)
	if type(name) ~= "string" then
		return name
	end
	return string.gsub(string.lower(name), "[%s_]+", "-")
end

function Icon.Register(name, value)
	Icon.Registry[normalizeName(name)] = value
end

function Icon.RegisterAlias(alias, name)
	alias = normalizeName(alias)
	name = normalizeName(name)
	if type(alias) ~= "string" or type(name) ~= "string" then
		error("[BobloUI] Icon.RegisterAlias expects two strings.", 2)
	end
	Icon.Aliases[alias] = name
	return Icon
end

function Icon.SetSpritesheets(first, second)
	return Lucide.SetSpritesheets(first, second)
end

function Icon.SetAtlasUrls(first, second)
	return Lucide.SetAtlasUrls(first, second)
end

function Icon.GetAtlasUrls()
	return Lucide.GetAtlasUrls()
end

function Icon.Prepare()
	return Lucide.Prepare()
end

function Icon.Retry()
	return Lucide.Retry()
end

function Icon.GetStatus()
	return Lucide.GetStatus()
end

function Icon.GetSpritesheets()
	return Lucide.GetSpritesheets()
end

function Icon.ResetSpritesheets()
	return Lucide.ResetSpritesheets()
end

function Icon.List()
	return table.clone(Lucide.Icons)
end

function Icon.Has(name)
	local normalized = normalizeName(name)
	if type(normalized) ~= "string" then
		return false
	end
	if Icon.Registry[normalized] ~= nil then
		return true
	end
	return Lucide.Has(Icon.Aliases[normalized] or normalized)
end

local function copyLayoutProps(props)
	local allowed = {
		Name = true,
		Size = true,
		Position = true,
		AnchorPoint = true,
		Parent = true,
		LayoutOrder = true,
		ZIndex = true,
		Visible = true,
		Rotation = true,
	}
	local out = { BackgroundTransparency = 1, BorderSizePixel = 0 }
	for key, value in props or {} do
		if allowed[key] then
			out[key] = value
		end
	end
	return out
end

local function tag(instance)
	instance:SetAttribute("BobloIconPart", true)
	return instance
end

local function bindPart(window, instance, token)
	if instance:IsA("UIStroke") then
		window:_bind(instance, { Color = token or "TextSecondary" })
	elseif instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
		window:_bind(instance, { ImageColor3 = token or "TextSecondary" })
	elseif instance:IsA("TextLabel") or instance:IsA("TextButton") then
		window:_bind(instance, { TextColor3 = token or "TextSecondary" })
	else
		window:_bind(instance, { BackgroundColor3 = token or "TextSecondary" })
	end
end

local function part(window, parent, props, token)
	props = props or {}
	props.BorderSizePixel = 0
	props.Parent = parent
	local item = tag(Create.New("Frame", props))
	bindPart(window, item, token)
	return item
end

local function rounded(window, parent, props, radius, token)
	local item = part(window, parent, props, token)
	Create.New(
		"UICorner",
		{ CornerRadius = UDim.new(radius == 1 and 1 or 0, radius == 1 and 0 or (radius or 2)), Parent = item }
	)
	return item
end

local function line(window, parent, x, y, width, height, rotation, token)
	local item = rounded(window, parent, {
		Size = UDim2.fromOffset(width, height),
		Position = UDim2.new(0.5, x, 0.5, y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = rotation or 0,
	}, 1, token)
	return item
end

local function outline(window, parent, props, radius, token, thickness)
	props = props or {}
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.Parent = parent
	local item = tag(Create.New("Frame", props))
	Create.New(
		"UICorner",
		{ CornerRadius = UDim.new(radius == 1 and 1 or 0, radius == 1 and 0 or (radius or 2)), Parent = item }
	)
	local stroke = tag(Create.New("UIStroke", { Thickness = thickness or 1.3, Transparency = 0.04, Parent = item }))
	bindPart(window, stroke, token)
	return item
end

local function dot(window, parent, x, y, size, token)
	return rounded(window, parent, {
		Size = UDim2.fromOffset(size or 3, size or 3),
		Position = UDim2.new(0.5, x, 0.5, y),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, 1, token)
end

local Draw = {}

Draw.dashboard = function(window, root)
	for _, p in { { -4.5, -4.5 }, { 4.5, -4.5 }, { -4.5, 4.5 }, { 4.5, 4.5 } } do
		rounded(window, root, {
			Size = UDim2.fromOffset(6, 6),
			Position = UDim2.new(0.5, p[1], 0.5, p[2]),
			AnchorPoint = Vector2.new(0.5, 0.5),
		}, 2)
	end
end
Draw["layout-dashboard"] = Draw.dashboard
Draw.home = Draw.dashboard

Draw.user = function(window, root)
	rounded(
		window,
		root,
		{ Size = UDim2.fromOffset(7, 7), Position = UDim2.new(0.5, 0, 0.5, -4.5), AnchorPoint = Vector2.new(0.5, 0.5) },
		1
	)
	rounded(
		window,
		root,
		{ Size = UDim2.fromOffset(14, 7), Position = UDim2.new(0.5, 0, 0.5, 5), AnchorPoint = Vector2.new(0.5, 0.5) },
		4
	)
end
Draw.player = Draw.user

Draw.eye = function(window, root)
	local ring = tag(Create.New("Frame", {
		Size = UDim2.fromOffset(16, 10),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = root,
	}))
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
	local stroke = tag(Create.New("UIStroke", { Thickness = 1.4, Transparency = 0.05, Parent = ring }))
	bindPart(window, stroke)
	rounded(
		window,
		root,
		{ Size = UDim2.fromOffset(4.5, 4.5), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) },
		1
	)
end
Draw.visuals = Draw.eye

Draw.settings = function(window, root)
	local ring = tag(Create.New("Frame", {
		Size = UDim2.fromOffset(9, 9),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = root,
	}))
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
	local stroke = tag(Create.New("UIStroke", { Thickness = 1.5, Parent = ring }))
	bindPart(window, stroke)
	for _, r in { 0, 45, 90, 135 } do
		line(window, root, 0, 0, 16, 2, r)
	end
	-- redraw centre on top so the spokes read as a gear, not an asterisk
	local cover = rounded(
		window,
		root,
		{ Size = UDim2.fromOffset(7, 7), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) },
		1,
		"Sidebar"
	)
	cover:SetAttribute("BobloIconMask", true)
	local inner = rounded(
		window,
		root,
		{ Size = UDim2.fromOffset(3, 3), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) },
		1
	)
end

Draw.search = function(window, root)
	local ring = tag(Create.New("Frame", {
		Size = UDim2.fromOffset(10, 10),
		Position = UDim2.new(0.5, -2, 0.5, -2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = root,
	}))
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
	local stroke = tag(Create.New("UIStroke", { Thickness = 1.4, Transparency = 0.04, Parent = ring }))
	bindPart(window, stroke)
	line(window, root, 5, 5, 6, 1.5, 45)
end

Draw.close = function(window, root)
	line(window, root, 0, 0, 13, 1.6, 45)
	line(window, root, 0, 0, 13, 1.6, -45)
end

Draw.menu = function(window, root)
	for _, y in { -5, 0, 5 } do
		line(window, root, 0, y, 15, 1.6, 0)
	end
end

Draw.chevron_down = function(window, root)
	line(window, root, -3, 0, 7, 1.5, 45)
	line(window, root, 3, 0, 7, 1.5, -45)
end
Draw.chevron_right = function(window, root)
	line(window, root, 0, -3, 7, 1.5, 45)
	line(window, root, 0, 3, 7, 1.5, -45)
end
Draw.chevron_up = function(window, root)
	line(window, root, -3, 0, 7, 1.5, -45)
	line(window, root, 3, 0, 7, 1.5, 45)
end

Draw.check = function(window, root)
	line(window, root, -3, 1, 6, 1.6, 45)
	line(window, root, 3, -1, 10, 1.6, -45)
end

Draw.plus = function(window, root)
	line(window, root, 0, 0, 13, 1.5, 0)
	line(window, root, 0, 0, 13, 1.5, 90)
end
Draw.minus = function(window, root)
	line(window, root, 0, 0, 13, 1.5, 0)
end

Draw.moon = function(window, root)
	local ring = tag(Create.New("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = root,
	}))
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
	local stroke = tag(Create.New("UIStroke", { Thickness = 1.4, Transparency = 0.04, Parent = ring }))
	bindPart(window, stroke)
	local mask = rounded(
		window,
		root,
		{ Size = UDim2.fromOffset(11, 11), Position = UDim2.new(0.5, 3, 0.5, -3), AnchorPoint = Vector2.new(0.5, 0.5) },
		1,
		"Canvas"
	)
	mask:SetAttribute("BobloIconMask", true)
end
Draw.palette = Draw.moon

Draw.command = function(window, root)
	for _, p in { { -4, -4 }, { 4, -4 }, { -4, 4 }, { 4, 4 } } do
		local ring = tag(Create.New("Frame", {
			Size = UDim2.fromOffset(6, 6),
			Position = UDim2.new(0.5, p[1], 0.5, p[2]),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = root,
		}))
		Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
		local s = tag(Create.New("UIStroke", { Thickness = 1.2, Parent = ring }))
		bindPart(window, s)
	end
	line(window, root, 0, -4, 8, 1.2, 0)
	line(window, root, 0, 4, 8, 1.2, 0)
	line(window, root, -4, 0, 8, 1.2, 90)
	line(window, root, 4, 0, 8, 1.2, 90)
end

Draw.star = function(window, root)
	-- restrained sparkle, used as a generic fallback action icon
	line(window, root, 0, 0, 14, 1.4, 0)
	line(window, root, 0, 0, 14, 1.4, 90)
	line(window, root, 0, 0, 9, 1.2, 45)
	line(window, root, 0, 0, 9, 1.2, -45)
end

Draw.copy = function(window, root)
	local a = tag(Create.New("Frame", {
		Size = UDim2.fromOffset(10, 10),
		Position = UDim2.new(0.5, -2, 0.5, 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = root,
	}))
	Create.New("UICorner", { CornerRadius = UDim.new(0, 2), Parent = a })
	local sa = tag(Create.New("UIStroke", { Thickness = 1.2, Parent = a }))
	bindPart(window, sa)
	local b = tag(Create.New("Frame", {
		Size = UDim2.fromOffset(10, 10),
		Position = UDim2.new(0.5, 2, 0.5, -2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = root,
	}))
	Create.New("UICorner", { CornerRadius = UDim.new(0, 2), Parent = b })
	local sb = tag(Create.New("UIStroke", { Thickness = 1.2, Parent = b }))
	bindPart(window, sb)
end
Draw.reset = function(window, root)
	local ring = tag(Create.New("Frame", {
		Size = UDim2.fromOffset(13, 13),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = root,
	}))
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
	local st = tag(Create.New("UIStroke", { Thickness = 1.3, Transparency = 0.05, Parent = ring }))
	bindPart(window, st)
	local mask = rounded(
		window,
		root,
		{ Size = UDim2.fromOffset(7, 5), Position = UDim2.new(0.5, 5, 0.5, -5), AnchorPoint = Vector2.new(0.5, 0.5) },
		1,
		"SurfaceRaised"
	)
	mask:SetAttribute("BobloIconMask", true)
	line(window, root, 4, -5, 6, 1.4, 0)
	line(window, root, 2, -3, 5, 1.4, 90)
end

Draw.info = function(window, root)
	local ring = tag(Create.New("Frame", {
		Size = UDim2.fromOffset(15, 15),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = root,
	}))
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
	local s = tag(Create.New("UIStroke", { Thickness = 1.3, Parent = ring }))
	bindPart(window, s)
	rounded(
		window,
		root,
		{ Size = UDim2.fromOffset(1.8, 6), Position = UDim2.new(0.5, 0, 0.5, 2), AnchorPoint = Vector2.new(0.5, 0.5) },
		1
	)
	rounded(
		window,
		root,
		{ Size = UDim2.fromOffset(2, 2), Position = UDim2.new(0.5, 0, 0.5, -4), AnchorPoint = Vector2.new(0.5, 0.5) },
		1
	)
end

Draw.lock = function(window, root)
	local body = rounded(
		window,
		root,
		{ Size = UDim2.fromOffset(12, 9), Position = UDim2.new(0.5, 0, 0.5, 3), AnchorPoint = Vector2.new(0.5, 0.5) },
		2
	)
	local shackle = tag(Create.New("Frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.new(0.5, 0, 0.5, -3),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = root,
	}))
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = shackle })
	local st = tag(Create.New("UIStroke", { Thickness = 1.4, Parent = shackle }))
	bindPart(window, st)
	local mask = part(
		window,
		root,
		{ Size = UDim2.fromOffset(10, 5), Position = UDim2.new(0.5, 0, 0.5, 1), AnchorPoint = Vector2.new(0.5, 0.5) },
		"Canvas"
	)
	mask:SetAttribute("BobloIconMask", true)
end
Draw.image = function(window, root)
	local frame = tag(Create.New("Frame", {
		Size = UDim2.fromOffset(16, 13),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = root,
	}))
	Create.New("UICorner", { CornerRadius = UDim.new(0, 2), Parent = frame })
	local st = tag(Create.New("UIStroke", { Thickness = 1.2, Parent = frame }))
	bindPart(window, st)
	rounded(
		window,
		root,
		{ Size = UDim2.fromOffset(3, 3), Position = UDim2.new(0.5, 4, 0.5, -3), AnchorPoint = Vector2.new(0.5, 0.5) },
		1
	)
	line(window, root, -3, 3, 8, 1.3, -35)
	line(window, root, 3, 3, 7, 1.3, 35)
end
Draw.code = function(window, root)
	line(window, root, -4, 0, 7, 1.5, -45)
	line(window, root, -4, 0, 7, 1.5, 45)
	line(window, root, 4, 0, 7, 1.5, 45)
	line(window, root, 4, 0, 7, 1.5, -45)
end
Draw.progress = function(window, root)
	local track = rounded(
		window,
		root,
		{ Size = UDim2.fromOffset(16, 5), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) },
		1,
		"TextDisabled"
	)
	local fill = rounded(
		window,
		root,
		{ Size = UDim2.fromOffset(9, 5), Position = UDim2.new(0.5, -3.5, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5) },
		1,
		"TextSecondary"
	)
end

-- A broader offline icon set. These deliberately use the same 18x18 geometry
-- and stroke language as the core glyphs, so callers can add personality
-- without a runtime HTTP request or an external sprite sheet.
Draw.layout = function(window, root)
	outline(window, root, {
		Size = UDim2.fromOffset(16, 15),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, 2)
	line(window, root, -3.5, 0, 1.3, 13, 0)
	line(window, root, 3.5, -2.5, 6, 1.3, 0)
end
Draw.columns = Draw.layout
Draw.panel = Draw.layout

Draw["sliders-horizontal"] = function(window, root)
	for _, item in { { -5, -3 }, { 0, 3 }, { 5, -2 } } do
		line(window, root, 0, item[1], 16, 1.3, 0)
		dot(window, root, item[2], item[1], 4)
	end
end
Draw.sliders = Draw["sliders-horizontal"]
Draw.controls = Draw["sliders-horizontal"]

Draw["toggle-right"] = function(window, root)
	outline(window, root, {
		Size = UDim2.fromOffset(18, 10),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, 1)
	dot(window, root, 4, 0, 6, "Accent")
end
Draw.toggle = Draw["toggle-right"]

Draw.keyboard = function(window, root)
	outline(window, root, {
		Size = UDim2.fromOffset(17, 12),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, 3)
	for _, x in { -5, -1.7, 1.7, 5 } do
		dot(window, root, x, -2, 1.8)
	end
	line(window, root, 0, 3, 9, 1.5, 0)
end

Draw.bell = function(window, root)
	outline(window, root, {
		Size = UDim2.fromOffset(12, 13),
		Position = UDim2.new(0.5, 0, 0.5, -1),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, 6)
	line(window, root, 0, 5.5, 15, 1.4, 0)
	dot(window, root, 0, 8, 2.5)
end
Draw.notifications = Draw.bell

Draw.shield = function(window, root)
	line(window, root, -5, -5, 9, 1.4, -22)
	line(window, root, 5, -5, 9, 1.4, 22)
	line(window, root, -4, 3, 10, 1.4, 58)
	line(window, root, 4, 3, 10, 1.4, -58)
	line(window, root, 0, 7, 4, 1.4, 0)
end
Draw.security = Draw.shield

Draw["shopping-cart"] = function(window, root)
	line(window, root, -6, -5, 5, 1.4, 0)
	line(window, root, -5, -1, 11, 1.4, 76)
	line(window, root, 2, 1, 12, 1.4, 0)
	line(window, root, 7, -2, 7, 1.4, 74)
	dot(window, root, -1, 6, 3)
	dot(window, root, 6, 6, 3)
end
Draw.shop = Draw["shopping-cart"]
Draw.cart = Draw["shopping-cart"]

Draw.gamepad = function(window, root)
	outline(window, root, {
		Size = UDim2.fromOffset(18, 12),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, 6)
	line(window, root, -4, 0, 6, 1.4, 0)
	line(window, root, -4, 0, 6, 1.4, 90)
	dot(window, root, 4, -1.5, 2.5)
	dot(window, root, 6.5, 1.5, 2.5)
end
Draw.game = Draw.gamepad

Draw.users = function(window, root)
	dot(window, root, -2.5, -4, 6)
	dot(window, root, 5, -2.5, 4.5)
	rounded(window, root, {
		Size = UDim2.fromOffset(11, 6),
		Position = UDim2.new(0.5, -2.5, 0.5, 4.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, 4)
	rounded(window, root, {
		Size = UDim2.fromOffset(7, 4),
		Position = UDim2.new(0.5, 5, 0.5, 4),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, 3)
end
Draw.team = Draw.users

Draw.globe = function(window, root)
	outline(window, root, {
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, 1)
	line(window, root, 0, 0, 14, 1.2, 0)
	outline(window, root, {
		Size = UDim2.fromOffset(7, 16),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, 1, nil, 1.1)
end
Draw.world = Draw.globe

Draw.database = function(window, root)
	for _, y in { -5, 0, 5 } do
		outline(window, root, {
			Size = UDim2.fromOffset(15, 6),
			Position = UDim2.new(0.5, 0, 0.5, y),
			AnchorPoint = Vector2.new(0.5, 0.5),
		}, 1, nil, 1.2)
	end
end
Draw.storage = Draw.database

Draw.folder = function(window, root)
	outline(window, root, {
		Size = UDim2.fromOffset(17, 12),
		Position = UDim2.new(0.5, 0, 0.5, 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, 2)
	line(window, root, -4, -5.5, 7, 1.5, 0)
	line(window, root, -7, -3.5, 4, 1.4, 90)
end
Draw.files = Draw.folder

Draw.save = function(window, root)
	outline(window, root, {
		Size = UDim2.fromOffset(15, 16),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, 2)
	outline(window, root, {
		Size = UDim2.fromOffset(8, 5),
		Position = UDim2.new(0.5, 0, 0.5, -5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, 1, nil, 1.1)
	outline(window, root, {
		Size = UDim2.fromOffset(9, 6),
		Position = UDim2.new(0.5, 0, 0.5, 4),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, 1, nil, 1.1)
end

local function drawTransfer(window, root, direction)
	line(window, root, 0, direction * -2, 12, 1.5, 90)
	line(window, root, -2.5, direction * 2, 7, 1.5, direction == 1 and -45 or 45)
	line(window, root, 2.5, direction * 2, 7, 1.5, direction == 1 and 45 or -45)
	line(window, root, 0, direction * 7, 15, 1.4, 0)
end
Draw.download = function(window, root)
	drawTransfer(window, root, 1)
end
Draw.upload = function(window, root)
	drawTransfer(window, root, -1)
end

Draw.trash = function(window, root)
	outline(window, root, {
		Size = UDim2.fromOffset(11, 13),
		Position = UDim2.new(0.5, 0, 0.5, 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, 2)
	line(window, root, 0, -6, 16, 1.4, 0)
	line(window, root, 0, -8, 6, 1.4, 0)
	line(window, root, -2, 2, 7, 1.1, 90)
	line(window, root, 2, 2, 7, 1.1, 90)
end
Draw["trash-2"] = Draw.trash
Draw.delete = Draw.trash

Draw.pencil = function(window, root)
	line(window, root, 0, 0, 17, 2.1, -45)
	line(window, root, -6, 6, 5, 1.4, 45)
	line(window, root, 6, -6, 4, 1.4, 45)
end
Draw.edit = Draw.pencil

Draw.list = function(window, root)
	for _, y in { -5, 0, 5 } do
		dot(window, root, -6.5, y, 2.5)
		line(window, root, 2, y, 11, 1.4, 0)
	end
end
Draw.grid = Draw.dashboard

Draw.layers = function(window, root)
	for _, y in { -4, 0, 4 } do
		line(window, root, -4, y, 9, 1.3, -28)
		line(window, root, 4, y, 9, 1.3, 28)
	end
end
Draw.stack = Draw.layers

Draw.terminal = function(window, root)
	outline(window, root, {
		Size = UDim2.fromOffset(18, 14),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, 2)
	line(window, root, -4, -1, 6, 1.4, 45)
	line(window, root, -4, 3, 6, 1.4, -45)
	line(window, root, 3.5, 4, 6, 1.4, 0)
end
Draw.console = Draw.terminal

Draw.monitor = function(window, root)
	outline(window, root, {
		Size = UDim2.fromOffset(18, 12),
		Position = UDim2.new(0.5, 0, 0.5, -2),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, 2)
	line(window, root, 0, 5, 7, 1.4, 90)
	line(window, root, 0, 8, 10, 1.4, 0)
end
Draw.desktop = Draw.monitor

Draw.smartphone = function(window, root)
	outline(window, root, {
		Size = UDim2.fromOffset(10, 18),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, 2)
	dot(window, root, 0, 6, 1.8)
end
Draw.mobile = Draw.smartphone

Draw.package = function(window, root)
	line(window, root, -4, -5, 9, 1.4, -28)
	line(window, root, 4, -5, 9, 1.4, 28)
	line(window, root, -4, 0, 9, 1.4, 28)
	line(window, root, 4, 0, 9, 1.4, -28)
	line(window, root, -7, 1, 11, 1.4, 90)
	line(window, root, 7, 1, 11, 1.4, 90)
	line(window, root, 0, 4, 9, 1.4, 90)
end
Draw.box = Draw.package

Draw.wrench = function(window, root)
	line(window, root, 0, 1, 15, 2.3, -45)
	outline(window, root, {
		Size = UDim2.fromOffset(6, 6),
		Position = UDim2.new(0.5, 5, 0.5, -5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, 1, nil, 1.3)
	dot(window, root, -5.5, 6.5, 3)
end
Draw.tools = Draw.wrench

Draw.zap = function(window, root)
	line(window, root, 2, -5, 11, 1.7, -60)
	line(window, root, 0, 0, 8, 1.7, 0)
	line(window, root, -2, 5, 11, 1.7, -60)
end
Draw.lightning = Draw.zap

Draw.activity = function(window, root)
	line(window, root, -6, 1, 6, 1.4, 0)
	line(window, root, -3, -1, 7, 1.4, 62)
	line(window, root, 0, 0, 11, 1.4, -72)
	line(window, root, 4, 1, 8, 1.4, 55)
	line(window, root, 7, 1, 4, 1.4, 0)
end
Draw.pulse = Draw.activity

Draw.play = function(window, root)
	line(window, root, -3, -5, 12, 1.7, 90)
	line(window, root, 2, -2.5, 11, 1.7, 28)
	line(window, root, 2, 2.5, 11, 1.7, -28)
end
Draw.run = Draw.play

Draw.sparkles = Draw.star
Draw.magic = Draw.star
Draw["refresh-cw"] = Draw.reset
Draw.refresh = Draw.reset
Draw["shield-check"] = function(window, root)
	Draw.shield(window, root)
	line(window, root, -2, 1, 4, 1.4, 45, "Accent")
	line(window, root, 2, 0, 7, 1.4, -45, "Accent")
end
function Icon.setColor(instance, color)
	if not instance then
		return
	end
	local function apply(item)
		if item:GetAttribute("BobloIconMask") then
			return
		end
		if item:GetAttribute("BobloIconPart") then
			if item:IsA("UIStroke") then
				item.Color = color
			elseif item:IsA("ImageLabel") or item:IsA("ImageButton") then
				item.ImageColor3 = color
			elseif item:IsA("TextLabel") or item:IsA("TextButton") then
				item.TextColor3 = color
			elseif item:IsA("GuiObject") then
				item.BackgroundColor3 = color
			end
		end
	end
	apply(instance)
	for _, item in instance:GetDescendants() do
		apply(item)
	end
end

local function createImage(window, asset, name, props)
	local imageProps = table.clone(props)
	imageProps.BackgroundTransparency = 1
	imageProps.BorderSizePixel = 0
	imageProps.Image = if type(asset) == "table" then asset.Url or asset.Image else asset
	if type(asset) == "table" then
		imageProps.ImageRectOffset = asset.ImageRectOffset
		imageProps.ImageRectSize = asset.ImageRectSize
	end
	local image = tag(Create.New("ImageLabel", imageProps))
	image:SetAttribute("BobloIconName", name)
	image:SetAttribute("BobloIconSource", if type(asset) == "table" then "Lucide" else "Custom")
	bindPart(window, image)
	return image
end

function Icon.Resolve(name)
	local normalized = normalizeName(name)
	if type(normalized) ~= "string" then
		return nil
	end
	local resolved = Icon.Aliases[normalized] or normalized
	return Lucide.GetAsset(resolved)
end

function Icon.new(window, name, props)
	props = props or {}
	local normalized = normalizeName(name)
	local underscored = type(normalized) == "string" and string.gsub(normalized, "-", "_") or normalized
	local custom = Icon.Registry[name] or Icon.Registry[normalized] or Icon.Registry[underscored]
	if
		type(custom) == "string"
		and (string.find(custom, "rbxasset://", 1, true) or string.find(custom, "rbxassetid://", 1, true))
	then
		return createImage(window, custom, normalized, props)
	end
	if type(custom) == "table" and type(custom.Url or custom.Image) == "string" then
		return createImage(window, custom, normalized, props)
	end
	if type(custom) == "function" then
		local root = Create.New("Frame", copyLayoutProps(props))
		root:SetAttribute("BobloIconName", normalized)
		root:SetAttribute("BobloIconSource", "Custom")
		custom(window, root)
		return root
	end
	if type(custom) == "string" then
		local textProps = table.clone(props)
		textProps.BackgroundTransparency = 1
		textProps.Text = custom
		textProps.Font = window.Fonts.Medium
		textProps.TextSize = textProps.TextSize or window.Tokens:Get("FontTitle")
		local label = tag(Create.New("TextLabel", textProps))
		bindPart(window, label)
		return label
	end
	local asset = Icon.Resolve(normalized)
	if asset then
		return createImage(window, asset, asset.IconName, props)
	end
	local fallbackName = Icon.FallbackAliases[normalized] or normalized
	local fallbackUnderscored = type(fallbackName) == "string" and string.gsub(fallbackName, "-", "_") or fallbackName
	local drawer = Draw[name]
		or Draw[normalized]
		or Draw[underscored]
		or Draw[fallbackName]
		or Draw[fallbackUnderscored]
	if drawer then
		local root = Create.New("Frame", copyLayoutProps(props))
		root:SetAttribute("BobloIconName", normalized)
		root:SetAttribute("BobloIconSource", "Fallback")
		drawer(window, root)
		return root
	end
	-- Unknown names still look intentional and remain asset-independent.
	local root = Create.New("Frame", copyLayoutProps(props))
	root:SetAttribute("BobloIconName", normalized or "unknown")
	root:SetAttribute("BobloIconSource", "Fallback")
	Draw.star(window, root)
	return root
end

return Icon
