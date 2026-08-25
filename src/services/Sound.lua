--!nonstrict
-- Optional UI sound registry. No copyrighted/default assets are bundled: hub authors
-- can register their own sound ids and users can disable the whole layer.
local SoundService = game:GetService("SoundService")
local Janitor = require("@runtime/Janitor")
local Sound = {}
Sound.__index = Sound

local function normalize(spec)
	if type(spec) == "string" or type(spec) == "number" then
		return { Id = tostring(spec), Volume = 0.35, PlaybackSpeed = 1 }
	end
	if type(spec) ~= "table" then
		return nil
	end
	return {
		Id = tostring(spec.Id or spec.SoundId or ""),
		Volume = math.clamp(tonumber(spec.Volume) or 0.35, 0, 10),
		PlaybackSpeed = math.clamp(tonumber(spec.PlaybackSpeed or spec.Speed) or 1, 0.1, 4),
	}
end
local function assetId(id)
	if id == "" then
		return ""
	end
	if string.match(id, "^rbxassetid://") or string.match(id, "^https?://") then
		return id
	end
	if tonumber(id) then
		return "rbxassetid://" .. id
	end
	return id
end

function Sound.new(window, options)
	local self = setmetatable({
		_window = window,
		_enabled = options.SoundEnabled ~= false,
		_volume = math.clamp(tonumber(options.SoundVolume) or 1, 0, 1),
		_sounds = {},
		_janitor = Janitor.new("Sound"),
	}, Sound)
	for name, spec in options.Sounds or {} do
		self:Register(name, spec)
	end
	return self
end
function Sound:Register(name, spec)
	if type(name) ~= "string" or name == "" then
		error("[BobloUI] Sound:Register requires a non-empty name.", 2)
	end
	local normalized = normalize(spec)
	if not normalized or normalized.Id == "" then
		error(`[BobloUI] Sound:Register "{name}" requires Id/SoundId.`, 2)
	end
	self._sounds[name] = normalized
	return self
end
function Sound:Unregister(name)
	self._sounds[name] = nil
	return self
end
function Sound:SetEnabled(enabled)
	self._enabled = enabled ~= false
	return self
end
function Sound:IsEnabled()
	return self._enabled
end
function Sound:SetVolume(volume)
	self._volume = math.clamp(tonumber(volume) or 1, 0, 1)
	return self
end
function Sound:GetVolume()
	return self._volume
end
function Sound:Play(name, override)
	if not self._enabled then
		return nil
	end
	local base = self._sounds[name]
	if
		not base
		and (
			type(name) == "number"
			or (
				type(name) == "string"
				and (
					tonumber(name) ~= nil
					or string.match(name, "^rbxassetid://") ~= nil
					or string.match(name, "^https?://") ~= nil
				)
			)
		)
	then
		base = normalize(name)
	end
	if not base then
		return nil
	end
	local spec = { Id = base.Id, Volume = base.Volume, PlaybackSpeed = base.PlaybackSpeed }
	if type(override) == "table" then
		if override.Volume ~= nil then
			spec.Volume = math.clamp(tonumber(override.Volume) or spec.Volume, 0, 10)
		end
		if override.PlaybackSpeed ~= nil then
			spec.PlaybackSpeed = math.clamp(tonumber(override.PlaybackSpeed) or spec.PlaybackSpeed, 0.1, 4)
		end
	end
	local s = Instance.new("Sound")
	s.Name = "BobloUI_" .. name
	s.SoundId = assetId(spec.Id)
	s.Volume = spec.Volume * self._volume
	s.PlaybackSpeed = spec.PlaybackSpeed
	s.Parent = SoundService
	local conn
	conn = s.Ended:Connect(function()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		if s.Parent then
			s:Destroy()
		end
	end)
	self._janitor:Add(s)
	local ok = pcall(function()
		s:Play()
	end)
	if not ok then
		s:Destroy()
		return nil
	end
	task.delay(12, function()
		if s.Parent and not s.IsPlaying then
			s:Destroy()
		end
	end)
	return s
end
function Sound:Destroy()
	self._sounds = {}
	self._janitor:Destroy()
end
return Sound
