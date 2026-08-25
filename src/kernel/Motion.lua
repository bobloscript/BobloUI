--!nonstrict
local TweenService = game:GetService("TweenService")
local Janitor = require("@runtime/Janitor")
local Motion = {}
Motion.__index = Motion
function Motion.new()
	return setmetatable({
		Enabled = true,
		_categories = { Window = true, Tabs = true, Controls = true },
		_active = setmetatable({}, { __mode = "k" }),
		_janitor = Janitor.new("Motion"),
	}, Motion)
end
Motion.Presets = {
	Fast = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Normal = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Slow = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}
function Motion:SetEnabled(v)
	self.Enabled = v == true
	return self
end
function Motion:SetCategory(category, enabled)
	if self._categories[category] == nil then
		error(`[BobloUI] unknown motion category "{category}".`, 2)
	end
	self._categories[category] = enabled ~= false
	return self
end
function Motion:IsEnabled(category)
	return self.Enabled and (category == nil or self._categories[category] ~= false)
end
function Motion:Tween(instance, info, props, category)
	local old = self._active[instance]
	if old then
		pcall(function()
			old:Cancel()
		end)
	end
	if not self:IsEnabled(category or "Controls") then
		for k, v in props do
			instance[k] = v
		end
		return nil
	end
	if type(info) == "string" then
		info = Motion.Presets[info] or Motion.Presets.Normal
	end
	info = info or Motion.Presets.Normal
	local tween = TweenService:Create(instance, info, props)
	self._active[instance] = tween
	tween.Completed:Once(function()
		if self._active[instance] == tween then
			self._active[instance] = nil
		end
	end)
	tween:Play()
	return tween
end
function Motion:Destroy()
	for _, t in self._active do
		pcall(function()
			t:Cancel()
		end)
	end
	self._active = {}
	self._janitor:Destroy()
end
return Motion
