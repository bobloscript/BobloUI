--!nonstrict
local Create = require("@runtime/Create")
local Base = require("@controls/Base")
local Video = setmetatable({}, { __index = Base })
Video.__index = Video

function Video.new(section, options)
	options = options or {}
	local self = setmetatable({}, Video)
	self.Video = options.Video or ""
	self.Looped = options.Looped == true
	self.Playing = options.Playing == true
	self.Volume = math.clamp(tonumber(options.Volume) or 0.5, 0, 1)
	self.Height = math.max(80, tonumber(options.Height) or 180)
	Base.init(self, section, "Video", options, { Stateful = false, Persist = false, Layout = "Stacked" })
	return Base.finish(self)
end

function Video:_measure()
	local t = self._window.Tokens
	return t:Get("ControlHeight") + self.Height + (self.Description and 12 or 0) + 10
end

function Video:_mountValue(host)
	local w = self._window
	self._video = Create.New("VideoFrame", {
		Size = UDim2.new(1, 0, 0, self.Height),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Video = self.Video,
		Looped = self.Looped,
		Playing = self.Playing,
		Volume = self.Volume,
		Parent = host,
	})
	Create.New("UICorner", {
		CornerRadius = UDim.new(0, w.Tokens:Get("FieldRadius")),
		Parent = self._video,
	})
	local stroke = Create.New("UIStroke", {
		Thickness = 1,
		Transparency = 0.5,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = self._video,
	})
	w:_bind(self._video, { BackgroundColor3 = "ControlInset" })
	w:_bind(stroke, { Color = "BorderSubtle" })
	self._janitor:Add(self._video.InputBegan:Connect(function(input)
		if
			not self:IsDisabled()
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			self:SetPlaying(not self._video.Playing)
		end
	end))
end

function Video:SetVideo(value)
	self.Video = value or ""
	if self._video then
		self._video.Video = self.Video
	end
	return self
end

function Video:SetLooped(looped)
	self.Looped = looped == true
	if self._video then
		self._video.Looped = self.Looped
	end
	return self
end

function Video:SetPlaying(playing)
	self.Playing = playing == true
	if self._video then
		self._video.Playing = self.Playing
	end
	return self
end

function Video:SetVolume(volume)
	self.Volume = math.clamp(tonumber(volume) or self.Volume, 0, 1)
	if self._video then
		self._video.Volume = self.Volume
	end
	return self
end

function Video:Play()
	return self:SetPlaying(true)
end

function Video:Pause()
	return self:SetPlaying(false)
end

function Video:SetHeight(height)
	self.Height = math.max(80, tonumber(height) or self.Height)
	if self._mounted then
		self:_applyTokens()
	end
	return self
end

function Video:_applyValueTokens()
	if self._valueHost then
		self._valueHost.Size = UDim2.new(1, -self._window.Tokens:Get("ControlPadding") * 2, 0, self.Height)
	end
	if self._video then
		self._video.Size = UDim2.new(1, 0, 0, self.Height)
	end
end

return Video
