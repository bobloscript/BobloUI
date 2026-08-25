# Dropdown

Single or multi-select dropdown.

Constructor: `AddDropdown({...})`

Stateful: **yes**

## Options
- `Id`: string?
- `Title`: string? — required
- `Description`: string?
- `Keywords`: table?
- `Badge`: string?
- `Disabled`: boolean|string?
- `Visible`: boolean?
- `VisibleWhen`: table|function?
- `EnabledWhen`: table|function?
- `IgnoreConfig`: boolean?
- `Order`: number?
- `Callback`: function?
- `Tooltip`: string|function?
- `ContextMenu`: table?
- `Adaptive`: boolean?
- `Icon`: string?
- `IconColor`: string|Color3?
- `Options`: table?
- `Values`: table?
- `Default`: any?
- `Multi`: boolean?
- `MultiValueMode`: string?
- `Map`: boolean?
- `ReturnMap`: boolean?
- `Searchable`: boolean?
- `AllowNone`: boolean?
- `AllowNull`: boolean?
- `Max`: number?
- `Placeholder`: string?
- `Style`: string?
- `Source`: any?
- `MaxVisibleRows`: number?
- `MaxVisibleDropdownItems`: number?
- `DragSelect`: boolean?
- `DisabledValues`: table?
- `ValueImages`: table?
- `Images`: table?
- `FormatDisplayValue`: function?
- `FormatListValue`: function?
- `FormatValue`: function?
- `FormatOption`: function?

## Specific methods
- `SetOptions()` — Replace all choices.
- `SetValues()` — Replace all choices from an array or dictionary.
- `AddOption()` — Append one choice.
- `AddValues()` — Append or merge choices.
- `RemoveOption()` — Remove a choice by value.
- `Refresh()` — Refresh the open list or replace choices.
- `Open()` — Open the picker.
- `Close()` — Close the picker.
- `SetDisabledValues()` — Replace disabled value list.
- `AddDisabledValues()` — Append one or more disabled values.
- `SetValueDisabled()` — Disable or enable one value.
- `SetValueImage()` — Set one value image.
- `SetValueImages()` — Replace the value image map.
- `AddValueImages()` — Merge entries into the value image map.
- `SetDragSelect()` — Enable or disable multi-value drag selection.
- `GetActiveValues()` — Read the selected value set or its count.
- `SetMaxVisibleRows()` — Set popup row limit.
- `SetFormatters()` — Set display and list formatters.
