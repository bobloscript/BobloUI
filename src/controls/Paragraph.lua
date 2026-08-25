--!nonstrict
local Create = require("@runtime/Create")
local Base = require("@controls/Base")
local Paragraph = setmetatable({}, { __index = Base })
Paragraph.__index = Paragraph

function Paragraph.new(section, options)
	options = options or {}
	local self = setmetatable({}, Paragraph)
	self.Content = options.Content or ""
	self.Variant = options.Variant or "Default"
	self.RichText = options.RichText == true
	self.DoesWrap = if options.DoesWrap ~= nil then options.DoesWrap ~= false else options.Wrap ~= false
	self.TextSize = tonumber(options.Size)
	Base.init(self, section, "Paragraph", options, { Stateful = false, Persist = false })
	self._window.Registry:Update(self, {
		Title = self:_resolve((self.Title and self.Title ~= "") and self.Title or self.Content),
		Description = self:_resolve(self.Content),
	})
	return Base.finish(self)
end
function Paragraph:_mount()
	if self._mounted or self._destroyed then
		return
	end
	self._mounted = true
	local w = self._window
	self._root = Create.New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = if self.Variant == "Default" then 1 else 0,
		BorderSizePixel = 0,
		LayoutOrder = self._order,
		Parent = self._section._content,
	})
	self._janitor:Add(self._root)
	if self.Variant ~= "Default" then
		Create.New("UICorner", { CornerRadius = UDim.new(0, w.Tokens:Get("ControlRadius")), Parent = self._root })
		local token = if self.Variant == "Info"
			then "AccentSoft"
			elseif self.Variant == "Warning" then "SurfaceHover"
			elseif self.Variant == "Danger" then "SurfaceHover"
			else "Control"
		w:_bind(self._root, { BackgroundColor3 = token })
		local stripe = Create.New("Frame", {
			Size = UDim2.fromOffset(3, 18),
			Position = UDim2.new(0, 0, 0, 10),
			BorderSizePixel = 0,
			Parent = self._root,
		})
		Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = stripe })
		w:_bind(stripe, {
			BackgroundColor3 = if self.Variant == "Info"
				then "Info"
				elseif self.Variant == "Warning" then "Warning"
				else "Error",
		})
	end
	self._padding = Create.New("UIPadding", { Parent = self._root })
	self._layout = Create.List(3)
	self._layout.Parent = self._root
	if self.Title and self.Title ~= "" then
		self._titleLabel = Create.New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Font = w.Fonts.Medium,
			TextSize = w.Tokens:Get("FontBody"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = self:_resolve(self.Title),
			RichText = self.RichText,
			Parent = self._root,
		})
		w:_bind(self._titleLabel, { TextColor3 = "Text" })
	end
	self._content = Create.New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = w.Fonts.Regular,
		TextSize = self.TextSize or w.Tokens:Get("FontSmall"),
		TextWrapped = self.DoesWrap,
		RichText = self.RichText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = self:_resolve(self.Content),
		Parent = self._root,
	})
	w:_bind(self._content, { TextColor3 = "TextSecondary" })
	if w.Interactions and (self._tooltip or self._contextMenu or self.Id) then
		self._janitor:Add(w.Interactions:Attach(self, self._root, self._tooltip, self._contextMenu))
	end
	self:_applyTokens()
	self:_applyVisible()
	self:_applyDisabled()
end
function Paragraph:_applyTokens()
	if not self._root then
		return
	end
	local t = self._window.Tokens
	if self._padding then
		local p = math.max(6, t:Get("SectionPadding") - 4)
		self._padding.PaddingTop = UDim.new(0, p)
		self._padding.PaddingBottom = UDim.new(0, p)
		self._padding.PaddingLeft = UDim.new(0, p)
		self._padding.PaddingRight = UDim.new(0, p)
	end
	if self._titleLabel then
		self._titleLabel.TextSize = t:Get("FontBody")
	end
	if self._content then
		self._content.TextSize = self.TextSize or t:Get("FontSmall")
	end
end
function Paragraph:_refreshText()
	if self._titleLabel then
		self._titleLabel.Text = self:_resolve(self.Title or "")
	end
	if self._content then
		self._content.Text = self:_resolve(self.Content)
	end
	self._window.Registry:Update(self, {
		Title = self:_resolve((self.Title and self.Title ~= "") and self.Title or self.Content),
		Description = self:_resolve(self.Content),
		Path = `{self:_resolve(self._section._tab.Title)} -> {self:_resolve(self._section.Title or "Default")}`,
	})
end
function Paragraph:SetContent(v)
	self.Content = v or ""
	if self._content then
		self._content.Text = self:_resolve(self.Content)
	end
	local fields = { Description = self:_resolve(self.Content) }
	if not self.Title or self.Title == "" then
		fields.Title = self:_resolve(self.Content)
	end
	self._window.Registry:Update(self, fields)
	return self
end
function Paragraph:SetRichText(enabled)
	self.RichText = enabled == true
	if self._titleLabel then
		self._titleLabel.RichText = self.RichText
	end
	if self._content then
		self._content.RichText = self.RichText
	end
	return self
end
function Paragraph:SetWrap(enabled)
	self.DoesWrap = enabled ~= false
	if self._content then
		self._content.TextWrapped = self.DoesWrap
	end
	return self
end
function Paragraph:SetSize(size)
	if size ~= nil and type(size) ~= "number" then
		error("[BobloUI] Paragraph:SetSize expects number or nil.", 2)
	end
	self.TextSize = size
	if self._content then
		self._content.TextSize = size or self._window.Tokens:Get("FontSmall")
	end
	return self
end
return Paragraph
