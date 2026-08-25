--!nonstrict
local Surface = require("@primitives/Surface")
local Popover = {}

function Popover.open(window, anchor, size, options)
	options = options or {}
	local handle = window.Layers:Push({ Scrim = false, Modal = false, OnDismiss = options.OnDismiss })
	local currentSize = Vector2.new(math.max(1, size.X), math.max(1, size.Y))
	local frame = Surface.new(window, {
		Name = "Popover",
		Size = UDim2.fromOffset(currentSize.X, currentSize.Y),
		BorderSizePixel = 0,
		Parent = handle.Container,
	}, {
		Token = "SurfaceRaised",
		StrokeToken = "Border",
		StrokeTransparency = 0.42,
		Corner = options.Corner or window.Tokens:Get("CornerMd"),
	})
	frame.ZIndex = handle.Depth * 10 + 2

	local function place()
		if not anchor or not anchor.Parent then
			handle:Dismiss()
			return
		end
		local pos, asz = anchor.AbsolutePosition, anchor.AbsoluteSize
		local safePos, safeSize = window.Device:SafeArea()
		local minX = safePos.X + 8
		local maxX = math.max(minX, safePos.X + safeSize.X - currentSize.X - 8)
		local minY = safePos.Y + 8
		local maxY = safePos.Y + safeSize.Y - currentSize.Y - 8
		local x = math.clamp(pos.X, minX, maxX)
		local below = pos.Y + asz.Y + 5
		local y
		if below + currentSize.Y <= safePos.Y + safeSize.Y - 8 then
			y = below
		else
			y = math.max(minY, pos.Y - currentSize.Y - 5)
		end
		frame.Position = UDim2.fromOffset(x, math.min(y, maxY))
	end

	place()
	local c1 = anchor:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
	local c2 = anchor:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	local c3 = window.Device.Changed:Connect(place)
	local oldDismiss = handle.Dismiss

	function handle:SetSize(newSize)
		if self._dismissed then
			return self
		end
		currentSize = Vector2.new(math.max(1, newSize.X), math.max(1, newSize.Y))
		frame.Size = UDim2.fromOffset(currentSize.X, currentSize.Y)
		place()
		return self
	end
	function handle:Reposition()
		if not self._dismissed then
			place()
		end
		return self
	end
	function handle:GetSize()
		return currentSize
	end
	function handle:Dismiss()
		if self._dismissed then
			return
		end
		c1:Disconnect()
		c2:Disconnect()
		c3:Disconnect()
		oldDismiss(self)
	end

	handle.Frame = frame
	return handle
end
return Popover
