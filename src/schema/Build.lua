--!nonstrict
local Manifest = require("@runtime/RuntimeManifest")
local Validate = require("@runtime/Validate")
local Build = {}
local Components = Manifest.Components or Manifest

local TAB_KEYS = {
	Id = true,
	Title = true,
	Description = true,
	Icon = true,
	Order = true,
	Badge = true,
	Group = true,
	Visible = true,
	VisibleWhen = true,
	EnabledWhen = true,
	Disabled = true,
	Locked = true,
	LockedReason = true,
	Sections = true,
	Controls = true,
}
local SECTION_KEYS = {
	Id = true,
	Title = true,
	Description = true,
	Icon = true,
	Collapsible = true,
	Collapsed = true,
	Column = true,
	Span = true,
	Layout = true,
	Visible = true,
	Controls = true,
}
local function unknownKeys(value, allowed, path, errors)
	for key in value do
		if not allowed[key] then
			table.insert(errors, `{path}.{tostring(key)}: unknown field`)
		end
	end
end
local function validateControl(control, path, errors)
	if type(control) ~= "table" then
		table.insert(errors, path .. " must be a table")
		return
	end
	if type(control.Type) ~= "string" or not Components[control.Type] then
		table.insert(errors, path .. `.Type "{tostring(control.Type)}" is unknown`)
		return
	end
	local options = {}
	for k, v in control do
		if k ~= "Type" then
			options[k] = v
		end
	end
	for _, err in Validate.Collect(control.Type, options, path) do
		table.insert(errors, err)
	end
end
local function validate(schema)
	local errors = {}
	if type(schema) ~= "table" then
		return { "schema must be a table" }
	end
	unknownKeys(schema, { Tabs = true }, "schema", errors)
	if type(schema.Tabs) ~= "table" then
		table.insert(errors, "schema.Tabs must be an array")
		return errors
	end
	for ti, tab in schema.Tabs do
		local tp = `Tabs[{ti}]`
		if type(tab) ~= "table" then
			table.insert(errors, tp .. " must be a table")
			continue
		end
		unknownKeys(tab, TAB_KEYS, tp, errors)
		if type(tab.Title) ~= "string" then
			table.insert(errors, tp .. ".Title must be a string")
		end
		if tab.Id ~= nil and type(tab.Id) ~= "string" then
			table.insert(errors, tp .. ".Id must be a string")
		end
		if tab.Controls ~= nil and type(tab.Controls) ~= "table" then
			table.insert(errors, tp .. ".Controls must be an array")
		else
			for ci, control in tab.Controls or {} do
				validateControl(control, `{tp}.Controls[{ci}]`, errors)
			end
		end
		if tab.Sections ~= nil and type(tab.Sections) ~= "table" then
			table.insert(errors, tp .. ".Sections must be an array")
		else
			for si, section in tab.Sections or {} do
				local sp = `{tp}.Sections[{si}]`
				if type(section) ~= "table" then
					table.insert(errors, sp .. " must be a table")
					continue
				end
				unknownKeys(section, SECTION_KEYS, sp, errors)
				if section.Column ~= nil and section.Column ~= 1 and section.Column ~= 2 then
					table.insert(errors, sp .. ".Column must be 1 or 2")
				end
				if section.Span ~= nil and section.Span ~= "Auto" and section.Span ~= 1 and section.Span ~= 2 then
					table.insert(errors, sp .. ".Span must be Auto, 1, or 2")
				end
				if
					section.Layout ~= nil
					and section.Layout ~= "Stack"
					and section.Layout ~= "Grid"
					and section.Layout ~= "Auto"
				then
					table.insert(errors, sp .. ".Layout must be Stack, Grid, or Auto")
				end
				if section.Controls ~= nil and type(section.Controls) ~= "table" then
					table.insert(errors, sp .. ".Controls must be an array")
				else
					for ci, control in section.Controls or {} do
						validateControl(control, `{sp}.Controls[{ci}]`, errors)
					end
				end
			end
		end
	end
	return errors
end

function Build.Validate(schema)
	return validate(schema)
end
function Build.Run(window, schema)
	local errors = validate(schema)
	if #errors > 0 then
		error("[BobloUI] UI:Build validation failed:\n - " .. table.concat(errors, "\n - "), 2)
	end
	local handles = {}
	local function createControl(container, desc)
		local spec = Components[desc.Type]
		local method = spec.Method
		local options = {}
		for k, v in desc do
			if k ~= "Type" then
				options[k] = v
			end
		end
		local h = container[method](container, options)
		if h.Id then
			handles[h.Id] = h
		end
		return h
	end
	for _, td in schema.Tabs do
		local tab = window:AddTab({
			Id = td.Id,
			Title = td.Title,
			Description = td.Description,
			Icon = td.Icon,
			Order = td.Order,
			Badge = td.Badge,
			Group = td.Group,
			Visible = td.Visible,
			Locked = td.Locked,
			LockedReason = td.LockedReason,
		})
		if tab.Id then
			handles[tab.Id] = tab
		end
		for _, cd in td.Controls or {} do
			createControl(tab, cd)
		end
		for _, sd in td.Sections or {} do
			local section = tab:AddSection({
				Id = sd.Id,
				Title = sd.Title,
				Description = sd.Description,
				Icon = sd.Icon,
				Collapsible = sd.Collapsible,
				Collapsed = sd.Collapsed,
				Column = sd.Column,
				Span = sd.Span,
				Layout = sd.Layout,
				Visible = sd.Visible,
				VisibleWhen = sd.VisibleWhen,
				EnabledWhen = sd.EnabledWhen,
				Disabled = sd.Disabled,
			})
			if section.Id then
				handles[section.Id] = section
			end
			for _, cd in sd.Controls or {} do
				createControl(section, cd)
			end
		end
	end
	return handles
end
return Build
