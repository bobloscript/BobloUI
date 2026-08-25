--!nonstrict
local Create = require("@runtime/Create")
local Base = require("@controls/Base")
local Env = require("@runtime/Env")
local Code = setmetatable({}, { __index = Base })
Code.__index = Code
function Code.new(section, options)
	options = options or {}
	local self = setmetatable({}, Code)
	self.Code = tostring(options.Code or options.Content or "")
	self.Height = math.max(72, tonumber(options.Height) or 150)
	self.Copy = options.Copy ~= false
	self.Language = options.Language or "lua"
	Base.init(self, section, "Code", options, { Stateful = false, Default = nil, Layout = "Stacked" })
	return Base.finish(self)
end
function Code:_measure()
	local t = self._window.Tokens
	return t:Get("ControlHeight") + self.Height + 12 + (self.Description and 12 or 0)
end
function Code:_mountValue(host)
	local w = self._window
	local t = w.Tokens
	self._box = Create.New("TextBox", {
		Size = UDim2.new(1, 0, 0, self.Height),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		MultiLine = true,
		TextEditable = false,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Code,
		TextSize = 12,
		Text = self.Code,
		Parent = host,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, t:Get("FieldRadius")), Parent = self._box })
	Create.New("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = self._box,
	})
	local s = Create.New("UIStroke", { Thickness = 1, Transparency = 0.58, Parent = self._box })
	w:_bind(s, { Color = "BorderSubtle" })
	w:_bind(self._box, { BackgroundColor3 = "ControlInset", TextColor3 = "TextSecondary" })
	if self.Copy then
		self._copy = Create.New("TextButton", {
			Size = UDim2.fromOffset(48, 24),
			Position = UDim2.new(1, -8, 0, 8),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Text = "Copy",
			Font = w.Fonts.Medium,
			TextSize = t:Get("FontCaption"),
			Parent = self._box,
		})
		Create.New("UICorner", { CornerRadius = UDim.new(0, 6), Parent = self._copy })
		local copyStroke = Create.New("UIStroke", {
			Thickness = 1,
			Transparency = 0.42,
			LineJoinMode = Enum.LineJoinMode.Round,
			Parent = self._copy,
		})
		w:_bind(self._copy, { BackgroundColor3 = "SurfaceRaised", TextColor3 = "TextSecondary" })
		w:_bind(copyStroke, { Color = "Border" })
		self._janitor:Add(self._copy.MouseButton1Click:Connect(function()
			Env.SetClipboard(self.Code)
			if w.Notify then
				w.Notify:Push({ Title = "Code copied", Variant = "Success", Duration = 2 })
			end
		end))
	end
end
function Code:_applyValueTokens()
	if self._valueHost then
		self._valueHost.Size = UDim2.new(1, -self._window.Tokens:Get("ControlPadding") * 2, 0, self.Height)
	end
	if self._box then
		self._box.Size = UDim2.new(1, 0, 0, self.Height)
	end
end
function Code:SetCode(text)
	self.Code = tostring(text or "")
	if self._box then
		self._box.Text = self.Code
	end
	return self
end
function Code:GetCode()
	return self.Code
end
function Code:CopyCode()
	Env.SetClipboard(self.Code)
	return self.Code
end
return Code
