--!nonstrict
--[[
	Create — Instance construction.

	`New(className, props, children)` sets Parent LAST. Parenting an Instance
	before its properties are assigned makes Roblox render and lay out a
	half-configured object; at 200 controls that is measurable.
]]

local Create = {}

function Create.Apply(instance: Instance, props: { [string]: any }?): Instance
	if not props then
		return instance
	end
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	return instance
end

function Create.New(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)

	Create.Apply(instance, props)

	if children then
		for _, child in children do
			child.Parent = instance
		end
	end

	if props and props.Parent then
		instance.Parent = props.Parent
	end

	return instance
end

-- ===== common modifiers ==========================================
-- Small enough to inline everywhere, common enough that inlining them
-- everywhere is how a 400-line component happens.

function Create.Corner(radius: number): UICorner
	return Create.New("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function Create.Stroke(thickness: number, transparency: number?): UIStroke
	return Create.New("UIStroke", {
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Create.Padding(top: number, right: number?, bottom: number?, left: number?): UIPadding
	local r = right or top
	local b = bottom or top
	local l = left or r
	return Create.New("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, r),
		PaddingBottom = UDim.new(0, b),
		PaddingLeft = UDim.new(0, l),
	})
end

function Create.List(gap: number, direction: Enum.FillDirection?, props: { [string]: any }?): UIListLayout
	local layout = Create.New("UIListLayout", {
		Padding = UDim.new(0, gap),
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	return Create.Apply(layout, props) :: any
end

function Create.SizeConstraint(min: Vector2?, max: Vector2?): UISizeConstraint
	return Create.New("UISizeConstraint", {
		MinSize = min or Vector2.zero,
		MaxSize = max or Vector2.new(math.huge, math.huge),
	})
end

function Create.Scale(scale: number): UIScale
	return Create.New("UIScale", { Scale = scale })
end

return Create
