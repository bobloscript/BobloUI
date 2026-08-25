--!nonstrict
-- Shared reactive VisibleWhen / EnabledWhen evaluator for controls and containers.
local Dependency = {}

local function updateRegistry(owner, ids, requirement)
	if owner.Id and owner._window and owner._window.Registry then
		owner._window.Registry:Update(owner, {
			DependencyIds = ids,
			Requirement = requirement,
		})
	end
end

function Dependency.Bind(owner, spec, kind)
	if spec == nil then
		return
	end
	local window = owner._window
	local janitor = owner._janitor
	local slot = `container_dependency_{kind}`
	local function apply(result)
		local enabled = result == true
		if kind == "visible" then
			owner._dependencyVisible = enabled
			owner:_applyContainerState()
		else
			owner._dependencyEnabled = enabled
			owner:_applyContainerState()
		end
	end
	if type(spec) == "table" then
		local ids = {}
		local requirements = {}
		for id, wanted in spec do
			table.insert(ids, id)
			table.insert(requirements, id .. " = " .. tostring(wanted))
		end
		updateRegistry(owner, ids, table.concat(requirements, ", "))
		local function evaluate()
			for id, wanted in spec do
				if window.State:Get(id) ~= wanted then
					apply(false)
					return
				end
			end
			apply(true)
		end
		janitor:Add(window.State:WatchMany(ids, evaluate), nil, slot)
		evaluate()
	elseif type(spec) == "function" then
		local function retrack()
			janitor:Remove(slot)
			local ids, result = window.State:Track(spec)
			updateRegistry(owner, ids, #ids > 0 and table.concat(ids, ", ") or nil)
			if #ids == 0 then
				warn(
					`[BobloUI] {owner.Type or "container"} "{owner.Id or owner.Title or "anonymous"}" dependency tracked 0 State:Get calls. The predicate must read at least one value from this Store.`
				)
			end
			local unsubscribe = {}
			for _, id in ids do
				table.insert(unsubscribe, window.State:Watch(id, retrack, owner))
			end
			janitor:Add(function()
				for _, callback in unsubscribe do
					callback()
				end
			end, nil, slot)
			apply(result == true)
		end
		retrack()
	else
		error(`[BobloUI] {kind} dependency must be a table or function.`, 3)
	end
end

return Dependency
