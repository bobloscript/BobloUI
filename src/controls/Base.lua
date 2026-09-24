--!nonstrict
local Create = require("@runtime/Create")
local Janitor = require("@runtime/Janitor")
local Signal = require("@runtime/Signal")
local Validate = require("@runtime/Validate")
local Icon = require("@primitives/Icon")
local Base = {}
Base.__index = Base

local function originSource(origin)
	return type(origin) == "table" and origin.Source or nil
end
local function isSilent(origin)
	return type(origin) == "table" and origin.Silent == true
end

function Base.init(self, section, typeName, options, config)
	options = options or {}
	config = config or {}
	Validate.Control(typeName, options)
	if options.Id then
		if not string.match(options.Id, "^[A-Za-z0-9_.%-]+$") then
			error(`[BobloUI] invalid Id "{options.Id}". Use A-Z, a-z, 0-9, _, ., - only.`, 3)
		end
		section._window.Registry:AssertAvailable(options.Id, 3)
	end
	self.Type = typeName
	self.Id = options.Id
	self.Title = options.Title or ""
	self.Description = options.Description
	self.Keywords = options.Keywords or {}
	self.Callback = options.Callback
	self.Icon = options.Icon
	self.IconColor = options.IconColor
	self._section = section
	self._window = section._window
	self._janitor = Janitor.new(`{typeName}[{self.Id or self.Title}]`)
	self._destroyed = false
	self._mounted = false
	self._order = options.Order or 0
	self._manualVisible = options.Visible ~= false
	self._dependencyVisible = true
	self._manualDisabled = (options.Disabled == true or type(options.Disabled) == "string")
	self._dependencyEnabled = true
	self._containerEnabled = true
	self._disabled = self._manualDisabled
	self._disabledReason = type(options.Disabled) == "string" and options.Disabled or nil
	self._loading = false
	self._tooltip = options.Tooltip
	self._contextMenu = options.ContextMenu
	self._stateful = config.Stateful == true
	self._persist = config.Persist ~= false and self._stateful and options.IgnoreConfig ~= true
	self._value = config.Default
	self._default = config.Default
	self._baseLayoutStyle = config.Layout or "Inline"
	self._layoutStyle = self._baseLayoutStyle
	self._adaptive = config.Adaptive == true or options.Adaptive == true
	self.Changed = Signal.new(`{typeName}.Changed`)
	section._janitor:Add(self, "Destroy", self)
	if self.Id then
		if self._stateful then
			self._window.State:SetDefault(self.Id, config.Default)
		end
		self._window.Registry:Add(self, {
			Id = self.Id,
			Type = typeName,
			Title = self:_resolve(self.Title),
			Description = self:_resolve(self.Description or ""),
			Keywords = self.Keywords,
			Tab = section._tab.Id,
			Section = section.Title,
			Path = `{self:_resolve(section._tab.Title)} -> {self:_resolve(section.Title or "Default")}`,
			Persist = self._persist,
		})
	else
		self._window.Registry:Add(self, {
			Type = typeName,
			Title = self:_resolve(self.Title),
			Description = self:_resolve(self.Description or ""),
			Keywords = self.Keywords,
			Tab = section._tab.Id,
			Section = section.Title,
			Path = `{self:_resolve(section._tab.Title)} -> {self:_resolve(section.Title or "Default")}`,
			Persist = false,
		})
	end
	if self.Id and self._stateful then
		self._janitor:Add(self._window.State:Watch(self.Id, function(value, old, id, origin)
			if self._destroyed then
				return
			end
			self._value = value
			if self._mounted then
				self:_render(value)
			end
			if not isSilent(origin) then
				if self.Callback then
					local ok, err = xpcall(self.Callback, debug.traceback, value)
					if not ok then
						warn(`[BobloUI] {self.Type} "{self.Id}" callback failed:\n{err}`)
					end
				end
				self.Changed:Fire(value, old, originSource(origin))
			end
		end, self))
	end
	self._janitor:Add(self._window.Theme.Changed:Connect(function()
		if self._mounted then
			self:_render(self:GetValue())
			self:_applyDisabled()
			self:_applyHoverVisual(false)
			if self._controlIcon then
				local c = self.IconColor
				if typeof(c) == "Color3" then
					Icon.setColor(self._controlIcon, c)
				elseif type(c) == "string" then
					Icon.setColor(self._controlIcon, self._window.Theme:Get(c))
				else
					Icon.setColor(self._controlIcon, self._window.Theme:Get("TextSecondary"))
				end
			end
		end
	end))
	self._janitor:Add(self._window.Tokens.Changed:Connect(function()
		if self._mounted then
			self:_applyTokens()
		end
	end))
	self:_bindDependency(options.VisibleWhen, "visible")
	self:_bindDependency(options.EnabledWhen, "enabled")
end

function Base.finish(self)
	self._section:_registerControl(self)
	if self._section._mounted then
		self:_mount()
	end
	return self
end

function Base:_bindDependency(spec, kind)
	if spec == nil then
		return
	end
	local slot = `dep_{kind}`
	local function apply(result)
		local enabled = result == true
		if kind == "visible" then
			if self._dependencyVisible == enabled then
				return
			end
			self._dependencyVisible = enabled
			self:_applyVisible()
		else
			if self._dependencyEnabled == enabled then
				return
			end
			self._dependencyEnabled = enabled
			self:_applyDisabled()
		end
	end
	if type(spec) == "table" then
		local ids = {}
		local req = {}
		for id, wanted in spec do
			table.insert(ids, id)
			table.insert(req, id .. " = " .. tostring(wanted))
		end
		self._dependencyIds = ids
		self._window.Registry:Update(self, { DependencyIds = ids, Requirement = table.concat(req, ", ") })
		local function eval()
			for id, wanted in spec do
				if self._window.State:Get(id) ~= wanted then
					apply(false)
					return
				end
			end
			apply(true)
		end
		self._janitor:Add(self._window.State:WatchMany(ids, eval), nil, slot)
		eval()
	elseif type(spec) == "function" then
		local function retrack()
			self._janitor:Remove(slot)
			local ids, result = self._window.State:Track(spec)
			self._dependencyIds = ids
			self._window.Registry:Update(
				self,
				{ DependencyIds = ids, Requirement = (#ids > 0 and table.concat(ids, ", ") or nil) }
			)
			if #ids == 0 then
				warn(
					`[BobloUI] {self.Type} "{self.Id or self.Title}" dependency tracked 0 State:Get calls. The predicate must read at least one value from this Store.`
				)
			end
			local unsubs = {}
			for _, id in ids do
				table.insert(
					unsubs,
					self._window.State:Watch(id, function()
						retrack()
					end)
				)
			end
			self._janitor:Add(function()
				for _, u in unsubs do
					u()
				end
			end, nil, slot)
			apply(result == true)
		end
		retrack()
	else
		error(`[BobloUI] {kind} dependency must be a table or function.`, 3)
	end
end

function Base:_effectiveLayout()
	if self._baseLayoutStyle == "Stacked" then
		return "Stacked"
	end
	if self._adaptive and self._section and self._section._controlLayout then
		return self._section:_controlLayout()
	end
	return "Inline"
end
function Base:_measure()
	local t = self._window.Tokens
	local style = self._layoutStyle or self._baseLayoutStyle
	if style == "Stacked" then
		return t:Get("ControlHeight") + t:Get("FieldHeight") + 10 + (self.Description and 12 or 0)
	end
	return t:Get("ControlHeight") + (self.Description and 14 or 0)
end
function Base:_updateResponsiveLayout()
	if not self._root then
		return
	end
	local nextStyle = self:_effectiveLayout()
	if nextStyle == self._layoutStyle then
		return
	end
	self._layoutStyle = nextStyle
	self:_applyTokens()
end

function Base:_mount()
	if self._mounted or self._destroyed then
		return
	end
	self._mounted = true
	local w = self._window
	local t = w.Tokens
	local h = self:_measure()
	local pad = t:Get("ControlPadding")
	self._root = Create.New("Frame", {
		Name = self.Type .. "_" .. (self.Id or "Anonymous"),
		Size = UDim2.new(1, 0, 0, h),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = self._order or 0,
		Parent = self._section:_controlParent(self),
	})
	if w._minimal then
		self._root.BackgroundTransparency = 0.78
	end
	self._janitor:Add(self._root)
	Create.New("UICorner", { CornerRadius = UDim.new(0, t:Get("ControlRadius")), Parent = self._root })
	w:_bind(self._root, { BackgroundColor3 = "ControlHover" })
	self._hoverRail = Create.New("Frame", {
		Name = "HoverRail",
		Size = UDim2.fromOffset(2, 18),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Parent = self._root,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self._hoverRail })
	w:_bind(self._hoverRail, { BackgroundColor3 = "Accent" })
	self._separator = Create.New("Frame", {
		Name = "Separator",
		Size = UDim2.new(1, -pad * 2, 0, 1),
		Position = UDim2.new(0, pad, 1, -1),
		BorderSizePixel = 0,
		BackgroundTransparency = 0.72,
		Parent = self._root,
	})
	w:_bind(self._separator, { BackgroundColor3 = "BorderSubtle" })

	local iconOffset = if self.Icon then 22 else 0
	if self.Icon then
		self._controlIcon = Icon.new(w, self.Icon, {
			Size = UDim2.fromOffset(t:Get("IconSm"), t:Get("IconSm")),
			Position = UDim2.fromOffset(pad, math.floor((t:Get("ControlHeight") - t:Get("IconSm")) / 2)),
			Parent = self._root,
		})
		local c = self.IconColor
		if typeof(c) == "Color3" then
			Icon.setColor(self._controlIcon, c)
		elseif type(c) == "string" then
			Icon.setColor(self._controlIcon, w.Theme:Get(c))
		else
			Icon.setColor(self._controlIcon, w.Theme:Get("TextSecondary"))
		end
	end
	local titleWidth = if self._layoutStyle == "Stacked"
		then UDim2.new(1, -pad * 2 - 76 - iconOffset, 0, t:Get("ControlHeight"))
		else UDim2.new(0.48, -pad - iconOffset, 0, t:Get("ControlHeight"))
	self._titleLabel = Create.New("TextLabel", {
		Size = titleWidth,
		Position = UDim2.fromOffset(pad + iconOffset, 0),
		BackgroundTransparency = 1,
		Font = w.Fonts.Medium,
		TextSize = t:Get("FontBody"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = self:_resolve(self.Title),
		Parent = self._root,
	})
	w:_bind(self._titleLabel, { TextColor3 = "Text" })
	if self.Description then
		self._descLabel = Create.New("TextLabel", {
			Size = UDim2.new(if self._layoutStyle == "Stacked" then 1 else 0.74, -pad * 2, 0, 15),
			Position = UDim2.fromOffset(pad, t:Get("ControlHeight") - 10),
			BackgroundTransparency = 1,
			Font = w.Fonts.Regular,
			TextSize = t:Get("FontSmall"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = self:_resolve(self.Description),
			Parent = self._root,
		})
		w:_bind(self._descLabel, { TextColor3 = "TextTertiary" })
	end
	if self._layoutStyle == "Stacked" then
		local y = t:Get("ControlHeight") + (self.Description and 11 or 0)
		self._valueHost = Create.New("Frame", {
			Size = UDim2.new(1, -pad * 2, 0, t:Get("FieldHeight")),
			Position = UDim2.fromOffset(pad, y),
			BackgroundTransparency = 1,
			Parent = self._root,
		})
	else
		self._valueHost = Create.New("Frame", {
			Size = UDim2.new(0.52, -pad, 0, t:Get("ControlHeight")),
			Position = UDim2.new(0.48, 0, 0, 0),
			BackgroundTransparency = 1,
			Parent = self._root,
		})
	end
	if self._mountValue then
		self:_mountValue(self._valueHost)
	end
	if self._applyValueTokens then
		self:_applyValueTokens()
	end
	self._disabledOverlay = Create.New("Frame", {
		Name = "DisabledOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0.58,
		BorderSizePixel = 0,
		Active = true,
		Visible = false,
		ZIndex = 50,
		Parent = self._root,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(0, t:Get("ControlRadius")), Parent = self._disabledOverlay })
	w:_bind(self._disabledOverlay, { BackgroundColor3 = "Canvas" })

	self._janitor:Add(self._root.MouseEnter:Connect(function()
		self:_applyHoverVisual(true)
	end))
	self._janitor:Add(self._root.MouseLeave:Connect(function()
		self:_applyHoverVisual(false)
	end))
	if w.Interactions and (self._tooltip or self._contextMenu or self.Id or self._disabledReason) then
		self._janitor:Add(w.Interactions:Attach(self, self._root, function()
			return self._tooltip or self._disabledReason
		end, self._contextMenu))
	end
	self:_applyVisible()
	self:_applyDisabled()
	self:_render(self:GetValue())
	self._section:_refreshSeparators()
end

function Base:_applyHoverVisual(hover)
	if not self._root then
		return
	end
	self._root.BackgroundColor3 = self._window.Theme:Get("ControlHover")
	local active = hover and not self._disabled
	self._window.Motion:Tween(self._root, "Fast", {
		BackgroundTransparency = if active
			then (if self._window._minimal then 0.54 else 0.74)
			else (if self._window._minimal then 0.78 else 1),
	})
	if self._hoverRail then
		self._window.Motion:Tween(self._hoverRail, "Fast", { BackgroundTransparency = if active then 0.16 else 1 })
	end
end
function Base:_resolve(v)
	return self._window.Locale and self._window.Locale:Resolve(v) or v
end
function Base:_refreshText()
	local title = self:_resolve(self.Title)
	local desc = self:_resolve(self.Description or "")
	if self._titleLabel then
		self._titleLabel.Text = title
	end
	if self._descLabel then
		self._descLabel.Text = desc
	end
	self._window.Registry:Update(self, {
		Title = title,
		Description = desc,
		Path = `{self:_resolve(self._section._tab.Title)} -> {self:_resolve(self._section.Title or "Default")}`,
	})
end
function Base:_applyTokens()
	if not self._root then
		return
	end
	local t = self._window.Tokens
	self._layoutStyle = self:_effectiveLayout()
	local h = self:_measure()
	local pad = t:Get("ControlPadding")
	self._root.Size = UDim2.new(1, 0, 0, h)
	local corner = self._root:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0, t:Get("ControlRadius"))
	end
	if self._disabledOverlay then
		local disabledCorner = self._disabledOverlay:FindFirstChildOfClass("UICorner")
		if disabledCorner then
			disabledCorner.CornerRadius = UDim.new(0, t:Get("ControlRadius"))
		end
	end
	local iconOffset = if self.Icon then 22 else 0
	if self._controlIcon then
		self._controlIcon.Size = UDim2.fromOffset(t:Get("IconSm"), t:Get("IconSm"))
		self._controlIcon.Position = UDim2.fromOffset(pad, math.floor((t:Get("ControlHeight") - t:Get("IconSm")) / 2))
	end
	if self._titleLabel then
		self._titleLabel.Position = UDim2.fromOffset(pad + iconOffset, 0)
		self._titleLabel.TextSize = t:Get("FontBody")
		self._titleLabel.Size = if self._layoutStyle == "Stacked"
			then UDim2.new(1, -pad * 2 - 76 - iconOffset, 0, t:Get("ControlHeight"))
			else UDim2.new(0.48, -pad - iconOffset, 0, t:Get("ControlHeight"))
	end
	if self._descLabel then
		self._descLabel.Position = UDim2.fromOffset(pad, t:Get("ControlHeight") - 10)
		self._descLabel.TextSize = t:Get("FontSmall")
	end
	if self._separator then
		self._separator.Size = UDim2.new(1, -pad * 2, 0, 1)
		self._separator.Position = UDim2.new(0, pad, 1, -1)
	end
	if self._valueHost then
		if self._layoutStyle == "Stacked" then
			self._valueHost.Size = UDim2.new(1, -pad * 2, 0, t:Get("FieldHeight"))
			self._valueHost.Position = UDim2.fromOffset(pad, t:Get("ControlHeight") + (self.Description and 11 or 0))
		else
			self._valueHost.Size = UDim2.new(0.52, -pad, 0, t:Get("ControlHeight"))
			self._valueHost.Position = UDim2.new(0.48, 0, 0, 0)
		end
	end
	if self._applyValueTokens then
		self:_applyValueTokens()
	end
end
function Base:_render(value) end
function Base:GetValue()
	if self.Id and self._stateful then
		return self._window.State:Get(self.Id)
	end
	return self._value
end
function Base:_commitOwnState(old, silent)
	local value = self._window.State:Get(self.Id)
	self._value = value
	if self._mounted then
		self:_render(value)
	end
	if not silent then
		if self.Callback then
			local ok, err = xpcall(self.Callback, debug.traceback, value)
			if not ok then
				warn(`[BobloUI] {self.Type} "{self.Id}" callback failed:\n{err}`)
			end
		end
		self.Changed:Fire(value, old, self)
	end
end
function Base:SetValue(value, silent)
	if not self._stateful then
		self._value = value
		if self._mounted then
			self:_render(value)
		end
		if not silent then
			self.Changed:Fire(value, nil, self)
		end
		return self
	end
	if self.Id then
		local old = self._window.State:Get(self.Id)
		local changed = self._window.State:Set(self.Id, value, { Source = self, Silent = silent == true })
		if changed then
			self:_commitOwnState(old, silent == true)
		end
	else
		local old = self._value
		self._value = value
		if self._mounted then
			self:_render(value)
		end
		if not silent then
			if self.Callback then
				self.Callback(value)
			end
			self.Changed:Fire(value, old, self)
		end
	end
	return self
end
function Base:SetTitle(text)
	self.Title = text
	if self._titleLabel then
		self._titleLabel.Text = self:_resolve(text)
	end
	self._window.Registry:Update(self, { Title = text })
	return self
end
function Base:SetDescription(text)
	self.Description = text
	if self._descLabel then
		self._descLabel.Text = self:_resolve(text or "")
	end
	self._window.Registry:Update(self, { Description = text or "" })
	if self._mounted then
		self:_applyTokens()
	end
	return self
end
function Base:SetKeywords(words)
	self.Keywords = words or {}
	self._window.Registry:Update(self, { Keywords = self.Keywords })
	return self
end
function Base:SetIcon(icon, color)
	self.Icon = icon
	if color ~= nil then
		self.IconColor = color
	end
	if self._controlIcon then
		self._controlIcon:Destroy()
		self._controlIcon = nil
	end
	if self._root and icon then
		local t = self._window.Tokens
		local pad = t:Get("ControlPadding")
		self._controlIcon = Icon.new(self._window, icon, {
			Size = UDim2.fromOffset(t:Get("IconSm"), t:Get("IconSm")),
			Position = UDim2.fromOffset(pad, math.floor((t:Get("ControlHeight") - t:Get("IconSm")) / 2)),
			Parent = self._root,
		})
		local c = self.IconColor
		if typeof(c) == "Color3" then
			Icon.setColor(self._controlIcon, c)
		elseif type(c) == "string" then
			Icon.setColor(self._controlIcon, self._window.Theme:Get(c))
		else
			Icon.setColor(self._controlIcon, self._window.Theme:Get("TextSecondary"))
		end
		self:_applyTokens()
	end
	return self
end
function Base:_applyVisible()
	local visible = self._manualVisible and self._dependencyVisible
	if self._root then
		self._root.Visible = visible
	end
	self._window.Registry:Update(self, { Hidden = not visible })
	if self._section and self._section._mounted then
		self._section:_refreshSeparators()
	end
end
function Base:SetVisible(v)
	self._manualVisible = v == true
	self:_applyVisible()
	return self
end
function Base:IsVisible()
	return self._manualVisible and self._dependencyVisible
end
function Base:_applyDisabled()
	self._disabled = self._manualDisabled or not self._dependencyEnabled or not self._containerEnabled
	if self._disabledOverlay then
		self._disabledOverlay.Visible = self._disabled
	end
	if self._root then
		self:_applyHoverVisual(false)
	end
end
function Base:SetDisabled(v, reason)
	self._manualDisabled = v == true
	self._disabledReason = reason
	self:_applyDisabled()
	return self
end
function Base:IsDisabled()
	return self._manualDisabled or not self._dependencyEnabled or not self._containerEnabled
end
function Base:_setContainerEnabled(enabled)
	self._containerEnabled = enabled ~= false
	self:_applyDisabled()
	return self
end
function Base:SetLoading(v)
	self._loading = v == true
	if self._setLoadingVisual then
		self:_setLoadingVisual(self._loading)
	end
	return self
end
function Base:SetBadge(text, style)
	if self._badge then
		self._badge:Destroy()
		self._badge = nil
	end
	if text and self._root then
		local Badge = require("@primitives/Badge")
		self._badge = Badge.new(self._window, text, style or "Neutral", self._root)
		self._badge.Position = UDim2.new(0.57, -6, 0, 13)
		self._badge.AnchorPoint = Vector2.new(1, 0)
	end
	return self
end
function Base:Reset(silent)
	if self.Id and self._stateful then
		local old = self._window.State:Get(self.Id)
		local changed = self._window.State:Reset(self.Id, { Source = self, Silent = silent == true })
		if changed then
			self:_commitOwnState(old, silent == true)
		end
	elseif self._stateful then
		self:SetValue(self._default, silent)
	end
	return self
end
function Base:CopyValue()
	local value = self:GetValue()
	local text
	if typeof(value) == "Color3" then
		text = "#" .. value:ToHex()
	elseif type(value) == "table" then
		local parts = {}
		for k, v in value do
			table.insert(parts, tostring(k) .. "=" .. tostring(v))
		end
		text = table.concat(parts, ", ")
	else
		text = tostring(value)
	end
	local Env = require("@runtime/Env")
	Env.SetClipboard(text)
	return text
end
function Base:PasteValue()
	if not self._stateful then
		return false, "not stateful"
	end
	local Env = require("@runtime/Env")
	local raw = Env.GetClipboard()
	if raw == nil then
		return false, "clipboard read unavailable"
	end
	local current = self:GetValue()
	local value = raw
	local kind = typeof(current)
	if kind == "Color3" then
		local hex = string.gsub(raw, "#", "")
		local ok, c = pcall(Color3.fromHex, hex)
		if not ok then
			return false, "invalid color"
		end
		value = c
	elseif type(current) == "number" then
		value = tonumber(raw)
		if value == nil then
			return false, "invalid number"
		end
	elseif type(current) == "boolean" then
		local v = string.lower(string.gsub(raw, "%s+", ""))
		if v == "true" or v == "1" or v == "on" then
			value = true
		elseif v == "false" or v == "0" or v == "off" then
			value = false
		else
			return false, "invalid boolean"
		end
	elseif type(current) == "string" or current == nil then
		value = raw
	else
		return false, "value type is not pasteable"
	end
	self:SetValue(value)
	return true
end
function Base:Highlight(duration)
	if not self._root then
		return self
	end
	local stroke = Create.New("UIStroke", { Thickness = 1.5, Transparency = 0.05, Parent = self._root })
	self._window:_bind(stroke, { Color = "Accent" })
	task.delay(duration or 0.9, function()
		if stroke.Parent then
			stroke:Destroy()
		end
	end)
	return self
end
function Base:Reveal()
	self._section._tab:Select()
	self._section:SetCollapsed(false)
	task.defer(function()
		if self._root and self._root.Parent then
			local page = self._section._tab._page
			local top = self._root.AbsolutePosition.Y - page.AbsolutePosition.Y + page.CanvasPosition.Y
			self._window.Motion:Tween(page, "Normal", { CanvasPosition = Vector2.new(0, math.max(0, top - 24)) })
			self:Highlight()
		end
	end)
	return self
end
function Base:OnChanged(fn)
	return self.Changed:Connect(fn)
end
function Base:GetInstance()
	return self._root
end
function Base:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._section._janitor:Release(self)
	self._window.Registry:Remove(self)
	self.Changed:Destroy()
	self._janitor:Destroy()
	self._section:_removeControl(self)
end
return Base
