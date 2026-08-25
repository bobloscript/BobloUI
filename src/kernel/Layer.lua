--!nonstrict
--[[
	Layer — ScreenGui layers and the modal stack.

	Three ScreenGuis, not one:

	  Root     100  window chrome and content
	  Overlay  200  popovers, sheets, dialogs, context menus, the palette
	  Toast    300  notifications, which must survive on top of a dialog

	This is the fix for the single most common bug in Roblox UI libraries: a
	dropdown rendered inside a ScrollingFrame gets clipped by ClipsDescendants.
	Anything transient renders into Overlay with absolute coordinates instead.

	Click-outside is handled with a full-screen transparent catcher Frame placed
	UNDER the transient content, not by hit-testing every input against every
	open popup.
]]

local CollectionService = game:GetService("CollectionService")
local Create = require("@runtime/Create")
local Janitor = require("@runtime/Janitor")
local Signal = require("@runtime/Signal")
local Env = require("@runtime/Env")

local Layer = {}
Layer.__index = Layer

--- Every root ScreenGui carries this tag so a failed :Unload() in an older
--- bundle can still be swept up by a newer one (architecture doc A.9).
Layer.Tag = "BobloUI"

local ORDER = {
	Root = 100,
	Overlay = 200,
	Toast = 300,
}

function Layer.new(windowId: string, input, theme)
	local self = setmetatable({
		DismissedTop = Signal.new("Layer.DismissedTop"),
		_janitor = Janitor.new("Layer"),
		_windowId = windowId,
		_theme = theme,
		_stack = {},
		_guis = {},
	}, Layer)

	local parent = Env.GetGuiParent()

	for name, order in ORDER do
		local gui = Create.New("ScreenGui", {
			Name = `BobloUI.{name}.{windowId}`,
			DisplayOrder = order,
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			AutoLocalize = false,
		})
		gui:SetAttribute("BobloWindowId", windowId)
		CollectionService:AddTag(gui, Layer.Tag)
		Env.Protect(gui)
		gui.Parent = parent

		self[name] = gui
		self._guis[name] = gui
		self._janitor:Add(gui)
	end

	-- Escape closes the topmost transient surface through the shared input dispatcher.
	if input then
		self._janitor:Add(input.Began:Connect(function(key, processed)
			if key.KeyCode == Enum.KeyCode.Escape and #self._stack > 0 then
				self:DismissTop()
			end
		end))
	end

	return self
end

--[[
	Push(options) -> handle

	options.Scrim      dim everything below (dialogs); default false
	options.OnDismiss  called when the surface is dismissed for any reason
	options.Modal      swallow clicks outside instead of dismissing; default false

	handle.Container   Frame to build into
	handle:Dismiss()
]]
function Layer:Push(options)
	options = options or {}

	local depth = #self._stack + 1
	local baseZ = depth * 10

	local janitor = Janitor.new(`Layer.Push[{depth}]`)
	local handle = {
		Depth = depth,
		_janitor = janitor,
		_layer = self,
		_dismissed = false,
		_onDismiss = options.OnDismiss,
	}

	local scrimColour = options.ScrimColour or (if self._theme then self._theme:Get("Scrim") else Color3.new(0, 0, 0))
	local scrimTransparency = 1
	if options.Scrim then
		if options.ScrimTransparency ~= nil then
			scrimTransparency = math.clamp(options.ScrimTransparency, 0, 1)
		elseif self._theme then
			scrimTransparency = self._theme:Get("ScrimTransparency")
		else
			scrimTransparency = 0.5
		end
	end
	local catcher = Create.New("TextButton", {
		Name = "Catcher",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = scrimColour,
		BackgroundTransparency = scrimTransparency,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = baseZ,
		Parent = self.Overlay,
	})
	janitor:Add(catcher)
	if options.Scrim and self._theme then
		if options.ScrimColour == nil then
			local colourBinding = self._theme:Bind(catcher, "BackgroundColor3", "Scrim")
			janitor:Add(function()
				self._theme:Unbind(colourBinding)
			end)
		end
		if options.ScrimTransparency == nil then
			local alphaBinding = self._theme:Bind(catcher, "BackgroundTransparency", "ScrimTransparency")
			janitor:Add(function()
				self._theme:Unbind(alphaBinding)
			end)
		end
	end

	janitor:Add(catcher.MouseButton1Click:Connect(function()
		if not options.Modal then
			handle:Dismiss()
		end
	end))

	local container = Create.New("Frame", {
		Name = "Container",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = baseZ + 1,
		Parent = self.Overlay,
	})
	janitor:Add(container)

	handle.Catcher = catcher
	handle.Container = container

	function handle:Dismiss()
		if self._dismissed then
			return
		end
		self._dismissed = true

		local stack = self._layer._stack
		local position = table.find(stack, self)
		if position then
			table.remove(stack, position)
		end

		if self._onDismiss then
			local ok, err = pcall(self._onDismiss)
			if not ok then
				warn(`[BobloUI] Layer OnDismiss failed: {err}`)
			end
		end

		self._janitor:Destroy()
	end

	function handle:IsOpen(): boolean
		return not self._dismissed
	end

	table.insert(self._stack, handle)
	return handle
end

function Layer:DismissTop()
	local top = self._stack[#self._stack]
	if top then
		top:Dismiss()
		self.DismissedTop:Fire(top)
	end
end

function Layer:DismissAll()
	for index = #self._stack, 1, -1 do
		self._stack[index]:Dismiss()
	end
	self._stack = {}
end

function Layer:StackDepth(): number
	return #self._stack
end

--- Emergency sweep. Used when an older bundle's :Unload() errored and its
--- ScreenGuis are still on screen (architecture doc A.9).
function Layer.SweepOrphans(windowId: string?)
	local removed = 0
	for _, gui in CollectionService:GetTagged(Layer.Tag) do
		if not windowId or gui:GetAttribute("BobloWindowId") == windowId then
			pcall(function()
				gui:Destroy()
			end)
			removed += 1
		end
	end
	return removed
end

function Layer:Destroy()
	self:DismissAll()
	self._janitor:Destroy()
	self.DismissedTop:Destroy()
end

return Layer
