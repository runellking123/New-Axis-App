# What's New — Overnight UI Overhaul

This document lists every visible change so you can find things that moved.

## Bottom Tab Bar
- Labels now scale with Dynamic Type (respect accessibility font size) and no
  longer clip at large sizes. `AppView.swift:329+`

## Design System (new)
A new shared design system lives in:

- `Axis/Shared/Theme/AxisTheme.swift` — **main file**. Holds spacing tokens,
  radius tokens, button styles, card modifiers, section header, and empty state.
- `Axis/Shared/Extensions/Color+Axis.swift` — semantic color roles
  (`axisAccent`, `axisSuccess`, `axisWarning`, `axisDanger`, `axisInfo`,
  `axisSurface`, `axisBackground`, `axisDivider`).
- `Axis/Shared/Extensions/Font+Axis.swift` — Dynamic Type-aware semantic fonts
  (`axisDisplay`, `axisScreenTitle`, `axisSectionTitle`, `axisBodyDynamic`,
  `axisSubheadline`, `axisMeta`, `axisNumeric`).

### How to use

```swift
// Spacing — stop using magic numbers. Use AxisSpacing.
.padding(.horizontal, AxisSpacing.lg)   // 16
.padding(.vertical, AxisSpacing.sm)     // 8

// Cards — stop hand-rolling backgrounds.
VStack { ... }
    .axisCard()              // neutral elevated card
VStack { ... }
    .axisAccentCard()        // highlighted card — reserve for ONE per screen

// Buttons — reserve gold for THE primary action.
Button("Save", action: save).buttonStyle(.axisPrimary)
Button("Cancel", action: cancel).buttonStyle(.axisSecondary)
Button("More", action: more).buttonStyle(.axisGhost)

// Empty states — consistent across features.
AxisEmptyState(
    icon: "tray",
    title: "Nothing here yet",
    message: "Add your first task to see it in the timeline.",
    actionTitle: "Add Task",
    action: { ... }
)

// Section headers
AxisSectionHeader("Today", subtitle: "Your focus for now")
```

## Color discipline
Gold was used 263+ times across the app. New rule: **`Color.axisGold` / `Color.axisAccent` is reserved for the ONE most important element on a screen.** Everything else uses `.primary` / `.secondary` / `.tertiary` or `Color.axisSurface` for elevated backgrounds.

## Where to find things after the redesign
See sections below as they are populated per phase.
