--!nonstrict

local Search = {}
Search.__index = Search

local EXCLUDED_TYPES = {
	Section = true,
	Tab = true,
	Divider = true,
}

local function lower(value)
	return string.lower(tostring(value or ""))
end

local function subsequence(query, text)
	local queryIndex = 1
	for index = 1, #text do
		if string.sub(text, index, index) == string.sub(query, queryIndex, queryIndex) then
			queryIndex += 1
			if queryIndex > #query then
				return true
			end
		end
	end
	return false
end

function Search.new(window)
	local self = setmetatable({
		_window = window,
		_registry = window.Registry,
		_index = {},
		_byKey = {},
		_debounceGeneration = 0,
		_debounceThread = nil,
		_destroyed = false,
	}, Search)

	self._addedConnection = self._registry.Added:Connect(function(entry)
		self:_upsert(entry)
	end)
	self._updatedConnection = self._registry.Updated:Connect(function(entry)
		self:_upsert(entry)
	end)
	self._removedConnection = self._registry.Removed:Connect(function(entry)
		self:_remove(entry)
	end)
	self:Reindex()
	return self
end

function Search:_remove(entry)
	local key = entry and entry.Key
	local record = key and self._byKey[key]
	if not record then
		return
	end
	self._byKey[key] = nil
	local position = table.find(self._index, record)
	if position then
		table.remove(self._index, position)
	end
end

function Search:_upsert(entry)
	if not entry or EXCLUDED_TYPES[entry.Type] then
		self:_remove(entry)
		return
	end

	local record = self._byKey[entry.Key]
	if not record then
		record = { Key = entry.Key }
		self._byKey[entry.Key] = record
		table.insert(self._index, record)
	end

	record.Entry = entry
	record.Id = lower(entry.Id)
	record.Title = lower(entry.Title)
	record.Description = lower(entry.Description)
	record.Path = lower(entry.Path)
	record.Keywords = {}
	for _, keyword in entry.Keywords or {} do
		table.insert(record.Keywords, lower(keyword))
	end
end

function Search:_score(record, query)
	local entry = record.Entry
	local score = 0
	if record.Id == query then
		score = 1000
	elseif string.sub(record.Title, 1, #query) == query then
		score = 800
	elseif string.find(record.Title, query, 1, true) then
		score = 600
	end

	for _, keyword in record.Keywords do
		if keyword == query then
			score = math.max(score, 500)
		elseif string.sub(keyword, 1, #query) == query then
			score = math.max(score, 400)
		end
	end
	if string.find(record.Description, query, 1, true) then
		score = math.max(score, 200)
	end
	if string.find(record.Path, query, 1, true) then
		score = math.max(score, 150)
	end
	if score == 0 and #query > 1 and subsequence(query, record.Title) then
		score = 80
	end
	if self._window.Favorites and entry.Id and self._window.Favorites:Has(entry.Id) then
		score += 60
	end
	if entry.Hidden then
		score -= 200
	end
	return score
end

function Search:Query(text)
	local query = lower(text)
	local results = {}
	for _, record in self._index do
		local entry = record.Entry
		local handle = entry.Handle
		local activeOnly = self._window._globalSearch == false
		local tab = handle and handle._section and handle._section._tab
		if activeOnly and tab ~= nil and tab ~= self._window._active then
			continue
		end
		local score
		if query == "" then
			score = if self._window.Favorites and entry.Id and self._window.Favorites:Has(entry.Id) then 100 else 0
		else
			score = self:_score(record, query)
		end
		if score > 0 then
			table.insert(results, {
				Kind = "Control",
				Id = entry.Id,
				Title = entry.Title,
				Path = entry.Path or "",
				Description = entry.Description,
				Score = score,
				Hidden = entry.Hidden,
				Handle = entry.Handle,
				Type = entry.Type,
				DependencyIds = entry.DependencyIds,
				Requirement = entry.Requirement,
			})
		end
	end

	table.sort(results, function(a, b)
		if a.Score == b.Score then
			return tostring(a.Title) < tostring(b.Title)
		end
		return a.Score > b.Score
	end)
	local out = {}
	for index = 1, math.min(12, #results) do
		out[index] = results[index]
	end
	return out
end

function Search:QueryDebounced(text, callback, delay)
	if type(callback) ~= "function" then
		error("[BobloUI] Search:QueryDebounced expects a callback.", 2)
	end
	self:CancelPending()
	self._debounceGeneration += 1
	local generation = self._debounceGeneration
	self._debounceThread = task.delay(tonumber(delay) or 0.075, function()
		if self._destroyed or generation ~= self._debounceGeneration then
			return
		end
		self._debounceThread = nil
		callback(self:Query(text))
	end)
	return generation
end

function Search:CancelPending()
	self._debounceGeneration += 1
	if self._debounceThread then
		pcall(task.cancel, self._debounceThread)
		self._debounceThread = nil
	end
	return self
end

function Search:Reveal(id)
	local handle = self._registry:Get(id)
	if handle and handle.Reveal then
		handle:Reveal()
		return true
	end
	return false
end

function Search:Reindex()
	self._index = {}
	self._byKey = {}
	for _, entry in self._registry:Entries() do
		self:_upsert(entry)
	end
	return self
end

function Search:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self:CancelPending()
	for _, connection in { self._addedConnection, self._updatedConnection, self._removedConnection } do
		if connection then
			connection:Disconnect()
		end
	end
	self._index = {}
	self._byKey = {}
end

return Search
