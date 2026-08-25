local Store = __require("kernel/Store")

local function expect(actual, expected, label)
	if actual ~= expected then
		error(`{label}: expected {tostring(expected)}, got {tostring(actual)}`)
	end
end

local function contains(text, fragment, label)
	if not string.find(tostring(text), fragment, 1, true) then
		error(`{label}: expected "{fragment}" in "{tostring(text)}"`)
	end
end

do
	local state = Store.new()
	state:SetDefault("A", 0)
	state:SetDefault("B", 0)
	local order = {}
	state:Watch("A", function(value)
		table.insert(order, "A" .. value)
		if value == 1 then
			state:Set("B", 1)
		end
		table.insert(order, "A-done")
	end)
	state:Watch("B", function(value)
		table.insert(order, "B" .. value)
	end)
	state:Set("A", 1)
	expect(table.concat(order, ","), "A1,A-done,B1", "nested writes use FIFO order")
end

do
	local state = Store.new()
	state:SetDefault("A", 0)
	state:SetDefault("B", 0)
	local calls = 0
	local settled = nil
	state:WatchMany({ "A", "B" }, function(snapshot)
		calls += 1
		settled = snapshot
	end)
	state:Batch(function()
		state:Set("A", 1)
		state:Set("B", 2)
	end)
	expect(calls, 1, "WatchMany call count")
	expect(settled.A, 1, "WatchMany settled A")
	expect(settled.B, 2, "WatchMany settled B")
end

do
	local state = Store.new()
	state:SetDefault("A", 0)
	state:SetDefault("B", 0)
	state:Watch("A", function(value)
		state:Set("B", value + 1)
	end)
	local calls = 0
	local settled = nil
	state:WatchMany({ "A", "B" }, function(snapshot)
		calls += 1
		settled = snapshot
	end)
	state:Set("A", 1)
	expect(calls, 1, "WatchMany cascade call count")
	expect(settled.A, 1, "WatchMany cascade settled A")
	expect(settled.B, 2, "WatchMany cascade settled B")
end

do
	local state = Store.new()
	state:SetDefault("Selected", { "a" })
	local calls = 0
	state:Watch("Selected", function()
		calls += 1
	end)
	local value = state:Get("Selected")
	table.insert(value, "b")
	expect(state:Set("Selected", value), true, "in-place table mutation return")
	expect(calls, 1, "in-place table mutation notification")
end

do
	local state = Store.new()
	state:SetDefault("ESP", true)
	state:SetDefault("Mode", "Advanced")
	local ids, result = state:Track(function(State)
		return State:Get("ESP") and state:Get("Mode") == "Advanced"
	end)
	expect(result, true, "tracked predicate result")
	expect(table.concat(ids, ","), "ESP,Mode", "Store-level dependency tracking")
end

do
	local state = Store.new()
	state:SetDefault("A", 0)
	local owner = {}
	local ownCalls = 0
	local otherCalls = 0
	state:Watch("A", function()
		ownCalls += 1
	end, owner)
	state:Watch("A", function()
		otherCalls += 1
	end)
	state:Set("A", 1, { Source = owner })
	expect(ownCalls, 0, "origin owner suppression")
	expect(otherCalls, 1, "non-owner watcher delivery")
end

do
	local state = Store.new()
	local initial = {}
	initial.self = initial
	state:SetDefault("Cycle", initial)
	local value = state:Get("Cycle")
	value.changed = true
	expect(state:Set("Cycle", value), true, "cycle-safe equality")
end

do
	local state = Store.new()
	state:SetDefault("A", 0)
	state:SetDefault("B", 0)
	state:Watch("A", function(value)
		state:Set("B", value + 1)
	end)
	state:Watch("B", function(value)
		state:Set("A", value + 1)
	end)
	local ok, err = pcall(function()
		state:Set("A", 1)
	end)
	expect(ok, false, "cascade guard propagates")
	contains(err, "State cascade exceeded 64 updates", "cascade error message")
	contains(err, "A -> B -> A", "cascade key chain")
end

print("store.spec.lua: ok")
