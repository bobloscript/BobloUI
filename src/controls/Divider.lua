--!nonstrict
local Create = require("@runtime/Create")
local Base = require("@controls/Base")
local Divider = setmetatable({}, { __index = Base })
Divider.__index = Divider

function Divider.new(section, options)
	options = options or {}
	if options.Title == nil and options.Text ~= nil then
		options = table.clone(options)
		options.Title = options.Text
	end
	local self = setmetatable({}, Divider)
	local margin = math.max(0, tonumber(options.Margin) or 0)
	self.MarginTop = math.max(0, tonumber(options.MarginTop) or margin)
	self.MarginBottom = math.max(0, tonumber(options.MarginBottom) or margin)
	Base.init(self, section, "Divider", options, { Stateful = false, Persist = false })
	self._window.Registry:Update(self, { Title = self:_resolve(self.Title or "Divider") })
	return Base.finish(self)
end
function Divider:_mount()
	if self._mounted or self._destroyed then
		return
	end
	self._mounted = true
	local w = self._window
	self._root = Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, 20 + self.MarginTop + self.MarginBottom),
		BackgroundTransparency = 1,
		LayoutOrder = self._order,
		Parent = self._section._content,
	})
	self._janitor:Add(self._root)
	self._line = Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromOffset(0, self.MarginTop + 10),
		BorderSizePixel = 0,
		Parent = self._root,
	})
	w:_bind(self._line, { BackgroundColor3 = "BorderSubtle" })
	if self.Title and self.Title ~= "" then
		self._titleLabel = Create.New("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, 20),
			Position = UDim2.new(0.5, 0, 0, self.MarginTop + 10),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 0,
			Font = w.Fonts.Regular,
			TextSize = w.Tokens:Get("FontSmall"),
			Text = "  " .. self:_resolve(self.Title) .. "  ",
			Parent = self._root,
		})
		w:_bind(self._titleLabel, { BackgroundColor3 = "Surface", TextColor3 = "TextTertiary" })
	end
	if w.Interactions and (self._tooltip or self._contextMenu or self.Id) then
		self._janitor:Add(w.Interactions:Attach(self, self._root, self._tooltip, self._contextMenu))
	end
	self:_applyVisible()
	self:_applyDisabled()
end
function Divider:SetTitle(t)
	self.Title = t
	if self._titleLabel then
		self._titleLabel.Text = "  " .. self:_resolve(t or "") .. "  "
	end
	self._window.Registry:Update(self, { Title = self:_resolve(t or "Divider") })
	return self
end
function Divider:_applyTokens()
	if self._titleLabel then
		self._titleLabel.TextSize = self._window.Tokens:Get("FontSmall")
	end
end
function Divider:SetMargins(top, bottom)
	if type(top) ~= "number" or (bottom ~= nil and type(bottom) ~= "number") then
		error("[BobloUI] Divider:SetMargins expects one or two numbers.", 2)
	end
	self.MarginTop = math.max(0, top)
	self.MarginBottom = math.max(0, if bottom == nil then top else bottom)
	if self._root then
		self._root.Size = UDim2.new(1, 0, 0, 20 + self.MarginTop + self.MarginBottom)
		self._line.Position = UDim2.fromOffset(0, self.MarginTop + 10)
		if self._titleLabel then
			self._titleLabel.Position = UDim2.new(0.5, 0, 0, self.MarginTop + 10)
		end
	end
	return self
end
function Divider:_refreshText()
	if self._titleLabel then
		self._titleLabel.Text = "  " .. self:_resolve(self.Title or "") .. "  "
	end
	self._window.Registry:Update(self, {
		Title = self:_resolve(self.Title or "Divider"),
		Path = `{self:_resolve(self._section._tab.Title)} -> {self:_resolve(self._section.Title or "Default")}`,
	})
end
return Divider
