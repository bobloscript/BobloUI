--!nonstrict
local Create = require("@runtime/Create")
local Surface = require("@primitives/Surface")
local Sheet = {}

function Sheet.open(window, height, options)
	options = options or {}
	local requestedHeight = height
	local handle = window.Layers:Push({
		Scrim = true,
		ScrimTransparency = options.ScrimTransparency,
		Modal = options.Modal == true,
		OnDismiss = options.OnDismiss,
	})
	local function metrics()
		local safePos, safeSize = window.Device:SafeArea()
		local keyboard = window.Device.KeyboardHeight or 0
		local usableH = math.max(120, safeSize.Y - keyboard)
		local h = math.min(requestedHeight or math.floor(usableH * 0.6), math.floor(usableH * 0.82))
		return safePos, safeSize, usableH, h
	end
	local safePos, safeSize, usableH, h = metrics()
	local frame = Surface.new(window, {
		Name = "Sheet",
		Size = UDim2.fromOffset(math.max(1, safeSize.X - 12), h),
		Position = UDim2.fromOffset(safePos.X + 6, safePos.Y + usableH - 6),
		AnchorPoint = Vector2.new(0, 1),
		BorderSizePixel = 0,
		Parent = handle.Container,
	}, {
		Token = "SurfaceRaised",
		StrokeToken = "Border",
		StrokeTransparency = 0.42,
		Corner = window.Tokens:Get("CornerLg"),
	})
	frame.ZIndex = handle.Depth * 10 + 2
	local grab = Create.New("TextButton", {
		Size = UDim2.fromOffset(64, 22),
		Position = UDim2.new(0.5, 0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		Parent = frame,
	})
	local bar = Create.New("Frame", {
		Size = UDim2.fromOffset(32, 3),
		Position = UDim2.new(0.5, 0, 0, 7),
		AnchorPoint = Vector2.new(0.5, 0),
		BorderSizePixel = 0,
		Parent = grab,
	})
	Create.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bar })
	window:_bind(bar, { BackgroundColor3 = "Border" })
	local function layout()
		if not frame.Parent then
			return
		end
		local p, s, u, hh = metrics()
		frame.Size = UDim2.fromOffset(math.max(1, s.X - 12), hh)
		frame.Position = UDim2.fromOffset(p.X + 6, p.Y + u - 6)
	end
	local conn = window.Device.Changed:Connect(layout)
	local oldDismiss = handle.Dismiss
	local dragStart
	local dragConn = grab.InputBegan:Connect(function(input)
		if
			input.UserInputType ~= Enum.UserInputType.Touch
			and input.UserInputType ~= Enum.UserInputType.MouseButton1
		then
			return
		end
		dragStart = input.Position
		window.Input:CapturePointer(handle, input, function(move)
			local dy = math.max(0, move.Position.Y - dragStart.Y)
			local p, s, u = metrics()
			frame.Position = UDim2.fromOffset(p.X + 6, p.Y + u - 6 + dy)
		end, function(move, cancelled)
			local dy = move and math.max(0, move.Position.Y - dragStart.Y) or 0
			if not cancelled and dy > 60 then
				handle:Dismiss()
			else
				layout()
			end
		end)
	end)
	function handle:SetHeight(newHeight)
		requestedHeight = newHeight
		layout()
		return self
	end
	function handle:Dismiss()
		if self._dismissed then
			return
		end
		window.Input:CancelCapture(self)
		conn:Disconnect()
		dragConn:Disconnect()
		oldDismiss(self)
	end
	handle.Frame = frame
	return handle
end
return Sheet
