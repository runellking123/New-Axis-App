# What's New — Overnight UI Overhaul

This document lists every visible change so you can find things that moved.

## Where things moved

### Dashboard (EA tab — home screen)
**Timeline is now the hero.** Before: greeting → quick-add → weather → stats → timeline (buried). Now: greeting → **today's timeline** → next-best-action → at-risk tasks → quick-add → stats → weather. The most actionable information is now immediately visible without scrolling.

Toolbar icons have been de-golded. The settings, dark-mode toggle, and focus-mode buttons are now neutral `.secondary` color. **Only the `+` add button stays gold** — that's the one primary action on this screen.

### Chat
User messages now have a **gold gradient** background with black text (more premium feel). Assistant messages use `.ultraThinMaterial` with a hairline border — a clear at-a-glance visual distinction between "you asked" and "AI answered." Bubble width is no longer capped at 300pt, so text reads comfortably on modern iPhone widths. Message text is now selectable.

### Tasks (Workflow tab)
Filter chip strip is more compact (reduced vertical padding) so the task list itself dominates the viewport. Select and Sort toolbar items are neutral; **only the `+` Add Task button is gold.**

### Voice Memos
The "2 action items" indicator on each memo card now uses a single gold dot instead of double-gold treatment, so the indicator doesn't compete with actionable UI.

### Tab Bar (bottom)
Labels now scale with **Dynamic Type** (respects accessibility font size settings) and no longer clip at large sizes.

## New design system

A shared design system now lives in:

- **`Axis/Shared/Theme/AxisTheme.swift`** — spacing tokens (`AxisSpacing`), radius tokens (`AxisRadius`), button styles (`.axisPrimary`, `.axisSecondary`, `.axisGhost`), card modifiers (`.axisCard()`, `.axisAccentCard()`), `AxisSectionHeader`, `AxisEmptyState`
- **`Axis/Shared/Extensions/Color+Axis.swift`** — semantic color roles (`.axisAccent`, `.axisSuccess`, `.axisWarning`, `.axisDanger`, `.axisInfo`, `.axisSurface`, `.axisBackground`, `.axisDivider`)
- **`Axis/Shared/Extensions/Font+Axis.swift`** — Dynamic Type-aware semantic fonts (`.axisDisplay`, `.axisScreenTitle`, `.axisSectionTitle`, `.axisBodyDynamic`, `.axisSubheadline`, `.axisMeta`, `.axisNumeric`)

### How to use going forward

```swift
// Spacing — stop using magic numbers.
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
```

## Color discipline

Gold was used 263+ times across the app — so much that it lost meaning. **New rule: gold is reserved for the ONE most important element on each screen.** Supporting icons/text use `.primary`, `.secondary`, `.tertiary`. Elevated surfaces use `.axisSurface`.

## Accessibility (Dynamic Type)

Many hardcoded `.font(.system(size: X))` calls have been replaced with semantic font styles (`.title3`, `.headline`, `.body`, `.caption`, etc.) that scale with the user's accessibility font-size setting. Affected screens so far: tab bar, Dashboard toolbar + quote card + weather + energy, Chat (AXIS title, model badge), Balance (Balance title, Energy Level number), Explore title, Tasks toolbar.

## Code fixes

- Force-unwrapped URLs in `MultiProviderChatService.swift` (streaming and single-message paths) replaced with safe `guard let` — no more crash risk if Anthropic's endpoint ever changes.
- Anthropic API key now persists in `UserDefaults` when entered in Settings → AI Chat. The hardcoded `Secrets.anthropicAPIKey` is now just the fallback.
- Gemini support fully removed. AI Chat is Claude-only now.
- Voice memo transcription: real on-device → server fallback on transient errors, audio session deactivated after recording so speech recognition can run, diagnostic `[Transcribe]` logging in Xcode console for troubleshooting.
