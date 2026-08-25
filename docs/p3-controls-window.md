# P3 control and window options

P3 completes the option-level portion of the official Obsidian comparison while
keeping BobloUI's existing API compatible.

## Input

- `AllowEmpty` controls whether an empty string can be committed. It defaults to
  `true` for text and `false` for numeric inputs, preserving numeric `Clear()` as
  zero unless explicitly overridden.
- `EmptyReset` is used when empty input is rejected.
- `ClearTextOnBlur` clears the visible field after committing without discarding
  the stored value.
- `ClearTextOnFocus`, `VerifyValue` and `Finished` are compatibility aliases for
  `ClearOnFocus`, `Validate` and commit timing.

## Slider

- `Prefix` and `Suffix` decorate the displayed number.
- `HideMax=false` renders `value / max`; the backward-compatible default keeps
  the old value-only display.
- `FormatDisplayValue` aliases `Format`.
- `AllowRightClickInput` lets a non-editable value label enter numeric edit mode
  with the right mouse button.
- `Compact` uses the compact value presentation.

## Paragraph and Divider

Paragraph supports `RichText`, `DoesWrap`/`Wrap`, `Size`, `SetRichText`,
`SetWrap` and `SetSize`. Divider accepts `Text` as a title alias plus `Margin`,
`MarginTop`, `MarginBottom` and `SetMargins`.

## Dictionary multi-dropdowns

`Options={"A","B"}` keeps the historical ordered-array result. A dictionary
`Values={A="Alpha",B="Beta"}` automatically uses a selection map:

```lua
local picker = Section:AddDropdown({
    Id = "DictionaryModes",
    Title = "Modes",
    Values = {A = "Alpha", B = "Beta"},
    Multi = true,
    Default = {A = true},
})

picker:SetValue({B = true})
print(picker:GetActiveValues(true)) -- 1
```

Use `MultiValueMode="Array"` or `MultiValueMode="Map"` to override inference.
Loading an older config representation converts it to the selected mode.

## Window tuning

Constructor options:

- Search: `DisableSearch`, `SearchbarSize`, `GlobalSearch`.
- Mobile: `ShowMobileButtons`, `MobileButtonsSide`.
- Tab motion: `TabTransitionTime`, `TabSwipeOffset`, and `TabSwipeFrom` configure
  the distance and direction from which a newly selected tab animates.
- Responsive sidebar: `EnableCompacting`, `DisableCompactingSnap`,
  `SidebarCompacted`, `MinContainerWidth`, `MinSidebarWidth`,
  `SidebarCompactWidth`, `SidebarCollapseThreshold`, `CompactWidthActivation`.

Runtime methods are `SetSearchEnabled`, `SetGlobalSearch`, `SetSearchbarSize`,
`SetSidebarCompacted`, `IsSidebarCompacted`, `SetResponsiveThresholds` and
`SetTabSwipe`.
