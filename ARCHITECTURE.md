# AXIS - AI Executive Assistant

## Overview

AXIS is a comprehensive iOS executive assistant app built with **SwiftUI**, **SwiftData**, and **The Composable Architecture (TCA)**. It provides 14 feature modules spanning productivity, wellness, family, social, finance, and AI-powered planning.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **UI** | SwiftUI |
| **State Management** | The Composable Architecture (TCA) |
| **Persistence** | SwiftData (47 models) |
| **Concurrency** | Swift Concurrency (async/await) |
| **AI** | Claude API, Gemini API, on-device NLP (NaturalLanguage, CoreML) |
| **Health** | HealthKit |
| **Calendar** | EventKit |
| **Location** | CoreLocation, MapKit |
| **Notifications** | UserNotifications |
| **Audio** | AVFoundation, Speech |
| **Places** | Yelp Fusion API |
| **Weather** | Open-Meteo API |

---

## App Entry Point

**File**: `Axis/AxisApp.swift`

```
@main AxisApp
  └── ModelContainer (47 SwiftData models)
  └── PersistenceService.shared.configure(container:)
  └── WindowGroup
       └── AppView(store: Store(AppReducer))
```

---

## Navigation Architecture

**Files**: `App/AppView.swift`, `App/AppReducer.swift`

The app uses a standard iOS `TabView` with TCA state-driven tab selection.

### Primary Tabs (Bottom Bar)

| # | Tab | Icon | View | Reducer |
|---|-----|------|------|---------|
| 0 | **EA** | `brain.head.profile.fill` | EADashboardView | EADashboardReducer |
| 1 | **Calendar** | `calendar` | CalendarTabView | (EventKit direct) |
| 2 | **AI Chat** | `bubble.left.and.text.bubble.right` | AIChatView | AIChatReducer |
| 3 | **Notes** | `note.text` | QuickNotesView | QuickNotesReducer |
| 4 | **Tasks** | `checklist` | EATaskListView | EATaskReducer |

### Under "More" Tab

| # | Tab | Icon | View | Reducer |
|---|-----|------|------|---------|
| 5 | **Explore** | `map.fill` | ExploreView | ExploreReducer |
| 6 | **Planner** | `calendar.badge.clock` | EAPlannerView | EAPlannerReducer |
| 7 | **Projects** | `folder.fill` | EAProjectListView | EAProjectReducer |
| 8 | **Social** | `person.2.fill` | SocialCircleView | SocialCircleReducer |
| 9 | **FamilyHQ** | `house.and.flag.fill` | FamilyHQView | FamilyHQReducer |
| 10 | **Balance** | `heart.circle.fill` | BalanceView | BalanceReducer |
| 11 | **Budget** | `dollarsign.circle.fill` | BudgetView | BudgetReducer |
| 12 | **News** | `newspaper.fill` | TrendsView | TrendsReducer |
| 13 | **Settings** | `gearshape.fill` | SettingsView | SettingsReducer |

### Deep Linking

URI scheme `axis://` with paths: `planner`, `tasks`, `projects`, `dashboard`, `calendar`, `notes`

### Context Modes

Auto-switches based on time of day:
- **Work** — during work hours
- **Me** — before work
- **Dad** — after work

---

## Project Structure

```
Axis/
├── Axis.xcodeproj
├── ARCHITECTURE.md
├── .gitignore
│
├── Axis/
│   ├── AxisApp.swift                    # App entry point, SwiftData schema
│   │
│   ├── App/
│   │   ├── AppView.swift                # Root TabView with 14 tabs
│   │   ├── AppReducer.swift             # Global state, tab enum, dependency clients
│   │   └── ContextMode.swift            # Work/Me/Dad mode enum
│   │
│   ├── Features/
│   │   ├── EA/
│   │   │   ├── Dashboard/
│   │   │   │   ├── EADashboardReducer.swift
│   │   │   │   └── EADashboardView.swift
│   │   │   ├── Planner/
│   │   │   │   ├── EAPlannerReducer.swift
│   │   │   │   └── EAPlannerView.swift
│   │   │   ├── Tasks/
│   │   │   │   ├── EATaskReducer.swift
│   │   │   │   └── EATaskListView.swift
│   │   │   ├── Projects/
│   │   │   │   ├── EAProjectReducer.swift
│   │   │   │   └── EAProjectListView.swift
│   │   │   └── Capture/
│   │   │       ├── EACaptureResultSheet.swift
│   │   │       └── EAQuickCaptureOverlay.swift
│   │   │
│   │   ├── AIChat/
│   │   │   ├── AIChatReducer.swift
│   │   │   └── AIChatView.swift
│   │   │
│   │   ├── QuickNotes/
│   │   │   ├── QuickNotesReducer.swift
│   │   │   └── QuickNotesView.swift
│   │   │
│   │   ├── SocialCircle/
│   │   │   ├── SocialCircleReducer.swift
│   │   │   ├── SocialCircleView.swift
│   │   │   ├── ContactDetailView.swift
│   │   │   ├── InteractionLogView.swift
│   │   │   └── GroupManagementView.swift
│   │   │
│   │   ├── FamilyHQ/
│   │   │   ├── FamilyHQReducer.swift
│   │   │   ├── FamilyHQView.swift
│   │   │   ├── GoalDetailView.swift
│   │   │   └── EventDetailView.swift
│   │   │
│   │   ├── Balance/
│   │   │   ├── BalanceReducer.swift
│   │   │   ├── BalanceView.swift
│   │   │   ├── SleepDetailView.swift
│   │   │   └── StepsDetailView.swift
│   │   │
│   │   ├── Budget/
│   │   │   ├── BudgetReducer.swift
│   │   │   └── BudgetView.swift
│   │   │
│   │   ├── Explore/
│   │   │   ├── ExploreReducer.swift
│   │   │   ├── ExploreView.swift
│   │   │   └── PlaceDetailView.swift
│   │   │
│   │   ├── Trends/
│   │   │   ├── TrendsReducer.swift
│   │   │   ├── TrendsView.swift
│   │   │   └── MetricDetailView.swift
│   │   │
│   │   ├── Calendar/
│   │   │   └── CalendarTabView.swift
│   │   │
│   │   ├── Settings/
│   │   │   ├── SettingsReducer.swift
│   │   │   └── SettingsView.swift
│   │   │
│   │   ├── Onboarding/
│   │   │   └── OnboardingView.swift
│   │   │
│   │   ├── Intents/
│   │   │   └── AxisAppIntents.swift
│   │   │
│   │   ├── CommandCenter/              # Legacy
│   │   │   ├── CommandCenterReducer.swift
│   │   │   ├── CommandCenterView.swift
│   │   │   ├── PriorityDetailView.swift
│   │   │   ├── ContextModes/
│   │   │   ├── DayBrief/
│   │   │   ├── QuickCapture/
│   │   │   └── Widgets/
│   │   │
│   │   └── WorkSuite/                  # Legacy
│   │       ├── WorkSuiteReducer.swift
│   │       ├── WorkSuiteView.swift
│   │       ├── ProjectDetailView.swift
│   │       └── AmbientSoundMixerView.swift
│   │
│   ├── Models/                          # 47 SwiftData @Model classes
│   │   ├── UserProfile.swift
│   │   ├── EATask.swift
│   │   ├── EAProject.swift
│   │   ├── EAMilestone.swift
│   │   ├── EADailyPlan.swift
│   │   ├── EATimeBlock.swift
│   │   ├── EAInboxItem.swift
│   │   ├── CapturedNote.swift
│   │   ├── ChatMessage.swift
│   │   ├── ChatThread.swift
│   │   ├── Contact.swift
│   │   ├── ContactGroup.swift
│   │   ├── Interaction.swift
│   │   ├── FamilyMember.swift
│   │   ├── FamilyEvent.swift
│   │   ├── Goal.swift
│   │   ├── Milestone.swift
│   │   ├── Chore.swift
│   │   ├── ChoreCount.swift
│   │   ├── ShoppingList.swift
│   │   ├── ShoppingItem.swift
│   │   ├── BillEntry.swift
│   │   ├── MoodEntry.swift
│   │   ├── WaterEntry.swift
│   │   ├── JournalEntry.swift
│   │   ├── Habit.swift
│   │   ├── HabitCompletion.swift
│   │   ├── Routine.swift
│   │   ├── RoutineStep.swift
│   │   ├── RoutineCompletion.swift
│   │   ├── FocusSession.swift
│   │   ├── FocusProfile.swift
│   │   ├── SavedPlace.swift
│   │   ├── PlacePhoto.swift
│   │   ├── Trip.swift
│   │   ├── ItineraryDay.swift
│   │   ├── BucketListGoal.swift
│   │   ├── MealPlan.swift
│   │   ├── Recipe.swift
│   │   ├── WorkProject.swift
│   │   ├── Subtask.swift
│   │   ├── PriorityItem.swift
│   │   ├── DadWin.swift
│   │   ├── TrendSnapshot.swift
│   │   ├── WidgetLayoutConfig.swift
│   │   └── MealPlan.swift
│   │
│   ├── Services/                        # 14 service classes
│   │   ├── PersistenceService.swift     # Central SwiftData access (732 lines)
│   │   ├── AIService.swift              # On-device NLP, classification
│   │   ├── AIExecutiveService.swift     # Task parsing, plan generation
│   │   ├── MultiProviderChatService.swift # Claude + Gemini streaming
│   │   ├── CalendarService.swift        # EventKit wrapper
│   │   ├── HealthKitService.swift       # Health data aggregation
│   │   ├── WeatherService.swift         # Open-Meteo API
│   │   ├── LocationService.swift        # GPS + geocoding
│   │   ├── NotificationService.swift    # Local push notifications
│   │   ├── HapticService.swift          # Haptic feedback patterns
│   │   ├── YelpService.swift            # Yelp Fusion API
│   │   ├── TrendService.swift           # Analytics computation
│   │   ├── AudioService.swift           # Voice recording
│   │   └── SpeechService.swift          # Text-to-speech
│   │
│   └── Shared/
│       ├── Components/
│       │   ├── GlassCard.swift          # Frosted glass card
│       │   ├── ConfettiView.swift       # Celebration animation
│       │   ├── ShimmerModifier.swift    # Loading shimmer
│       │   ├── MiniChartView.swift      # Inline charts
│       │   └── ContactPickerView.swift  # Contact picker
│       │
│       ├── Extensions/
│       │   ├── Color+Axis.swift         # axisGold, brand palette
│       │   ├── Date+Axis.swift          # Date formatting helpers
│       │   └── Font+Axis.swift          # Custom typography
│       │
│       └── Theme/
│           └── AxisTheme.swift          # Spacing, radii, shadows
```

---

## Feature Modules

### EA Dashboard
Central hub showing weather, energy score, today's schedule, at-risk tasks, upcoming deadlines, quick stats (tasks completed, meetings remaining, deep work hours), streak count, and AI-powered next-best-action suggestions. Auto-refreshes on appear with data from calendar, health, and persistence services.

### AI Chat
Multi-provider AI chat supporting **Claude** (Sonnet 4, Haiku 4.5, Opus 4) and **Gemini** (2.5 Pro, 2.5 Flash). Features streaming responses, conversation threads, image/file attachments, voice recording with transcription, and suggested follow-ups. Messages persist via SwiftData.

### Quick Notes
Note capture with folder organization (**Work**, **Personal**, **Lagniappe**), color coding (7 colors), search, sort (newest/oldest/A-Z), pin-to-top, swipe actions (delete/pin), and auto-generated titles from first line. Folder tabs with note counts at the top.

### Tasks
EA task management with natural language parsing, inbox for unprocessed captures, priority levels (critical/high/medium/low), energy tags (deep work/light work), status tracking, category filters, deadline management, and project association. Supports multi-select batch operations.

### Planner
AI-generated daily and weekly schedules with time-blocked planning. Scaffolds blocks from calendar events, tasks, and energy preferences. Block types: task, meeting, focus block, break. Includes AI reasoning for block placement. Supports manual block add/edit/delete.

### Projects
Project management with milestones, status tracking (active/on-hold/completed/archived), category organization (university/consulting/personal), progress computation from milestone completion, and template support.

### Social Circle
Contact management with tier system (Inner Circle, Close Friends, Extended), interaction logging (call/text/coffee/meeting/email/FaceTime), group management, check-in reminders, birthday tracking, overdue contact alerts, and iOS Contacts import. Quick action buttons for Phone, Text, FaceTime.

### FamilyHQ
Family coordination hub with shared calendar (activity/appointment/school/meal/outing), meal planning by day and type, family goals with milestone tracking, chore counter, and shopping list with store grouping, category organization, and budget tracking.

### Balance
Wellness dashboard with HealthKit integration showing sleep hours, steps, active calories, heart rate, stand hours, and computed energy score. Includes mood logging, water tracking, stress level monitoring, work-life balance meter, and AI-generated weekly wellness reports.

### Budget
Monthly bill tracker with income tracking, categorized bills (housing, utilities, transportation, insurance, subscriptions, debt, food, childcare, phone, other), paid/unpaid toggle with color coding (green=paid, red=overdue, gold=upcoming), month navigation, running totals, and CSV export.

### Explore
Place discovery powered by Yelp Fusion API with category filters (dining/events/activities/travel/Black-owned/kids), location search, radius control, "Surprise Me" random picks, place details (hours, rating, reviews, price), favorites, and visited tracking.

### News/Trends
Two-part module: (1) Analytics dashboard with configurable windows (7/14/30/90 days) showing focus minutes, sessions, priorities completed, interactions, mood/energy trends, habits, and AI-generated insights. (2) RSS news feed with category filtering (Higher Ed, AI, HBCU, Athletics, Leadership, Policy, Data, HBCU Sports) and infinite scroll pagination.

### Settings
User preferences including name, wake/work times, context mode default, step goals, focus duration, notification toggles, haptic feedback, dark mode override, HealthKit connection, location settings, and EA-specific settings (quiet hours, plan generation time, energy preferences, task categories).

---

## Data Models (47 SwiftData Models)

### Core
| Model | Key Properties |
|-------|---------------|
| **UserProfile** | name, wakeTime, workStartTime, workEndTime, preferredContextMode, stepsGoal, defaultFocusMinutes, notificationsEnabled, hapticFeedbackEnabled, onboardingComplete |
| **PriorityItem** | uuid, title, sourceModule, timeEstimateMinutes, isCompleted, sortOrder, contextMode, dueDate, notes |
| **CapturedNote** | title, content, transcribedFromVoice, classifiedModule, isProcessed, isPinned, color, folder?, createdAt, updatedAt |
| **WidgetLayoutConfig** | widgetType, contextMode, size, sortOrder, isVisible |

### Executive Assistant
| Model | Key Properties |
|-------|---------------|
| **EATask** | uuid, title, taskDescription, deadline, priority, energyLevel, status, category, estimatedMinutes, scheduledStart/End, projectId, isRecurring, recurrenceRule, tags, aiReasoning |
| **EAProject** | uuid, title, projectDescription, status, category, isTemplate, templateName, deadline, statusNote |
| **EAMilestone** | uuid, title, dueDate, isCompleted, projectId, sortOrder |
| **EADailyPlan** | uuid, date, aiSummary, generatedAt |
| **EATimeBlock** | uuid, startTime, endTime, blockType, taskId, eventId, title, aiReasoning, planId |
| **EAInboxItem** | uuid, rawInput, classifiedType, confidence, parsedData (JSON), isReviewed |

### Chat
| Model | Key Properties |
|-------|---------------|
| **ChatMessage** | uuid, role, content, model, timestamp, threadId |
| **ChatThread** | uuid, title, createdAt, updatedAt, modelUsed |

### Social
| Model | Key Properties |
|-------|---------------|
| **Contact** | uuid, name, tier, phone, email, birthday, lastContacted, checkInDays, notes, relationship, richNotes, groupIds |
| **Interaction** | uuid, contactId, type, date, notes |
| **ContactGroup** | uuid, name, emoji, memberIds |

### Family
| Model | Key Properties |
|-------|---------------|
| **FamilyMember** | name, role, birthday, avatar |
| **FamilyEvent** | uuid, title, category, date, isAllDay, notes, isCompleted, assignedTo |
| **Goal** | uuid, title, category, targetDate, notes, completedAt, milestones relationship |
| **Chore** | name, assignedTo, frequency, lastCompleted |
| **ChoreCount** | name, count, date |
| **ShoppingList** | uuid, name, items, createdAt |
| **ShoppingItem** | uuid, name, quantity, budgetPrice, store, category, isBought |

### Wellness
| Model | Key Properties |
|-------|---------------|
| **MoodEntry** | uuid, mood, energyLevel, notes, date |
| **WaterEntry** | uuid, ounces, date |
| **JournalEntry** | uuid, content, date, mood |
| **Habit** | uuid, name, frequency, targetDaysPerWeek, specificDays, streakCurrent, streakBest, color, icon |
| **HabitCompletion** | uuid, habitId, date |
| **FocusSession** | uuid, title, durationMinutes, sessionType, completedAt |
| **FocusProfile** | uuid, name, defaultDuration, breakDuration |
| **Routine** | uuid, name, steps relationship |
| **RoutineStep** | uuid, title, durationMinutes, routineId |
| **RoutineCompletion** | uuid, routineId, date |

### Finance
| Model | Key Properties |
|-------|---------------|
| **BillEntry** | uuid, name, amount, dueDay, category, isPaid, month, year, notes |

### Explore
| Model | Key Properties |
|-------|---------------|
| **SavedPlace** | uuid, name, category, address, notes, rating, isVisited, isFavorite, phoneNumber, websiteURL, hoursOfOperation |
| **PlacePhoto** | uuid, placeId, photoURL, caption |
| **Trip** | uuid, name, startDate, endDate, destination, notes |
| **ItineraryDay** | uuid, tripId, day, activities, notes |
| **BucketListGoal** | uuid, description, category, targetDate, isCompleted |

### Work
| Model | Key Properties |
|-------|---------------|
| **WorkProject** | uuid, title, workspace, status, priority, notes, dueDate, estimatedPomodoros |
| **Subtask** | uuid, title, isCompleted, projectId |

### Misc
| Model | Key Properties |
|-------|---------------|
| **MealPlan** | dayOfWeek, mealType, mealName |
| **Recipe** | uuid, name, ingredients, instructions, category |
| **TrendSnapshot** | uuid, date, windowDays, focusMinutes, sessions, priorities, interactions, mood, energy, habits, places, dadWins |
| **DadWin** | uuid, title, details, mood, date, photoData (external storage) |
| **Milestone** | uuid, title, targetDate, isCompleted |

---

## Services Layer

### PersistenceService
Central SwiftData access layer. Singleton pattern with `@MainActor` configuration. Provides typed fetch/save/delete/update methods for all 47 models. Uses `FetchDescriptor` with `SortDescriptor` for queries and `#Predicate` for filtered lookups.

### AIService
On-device NLP using Apple's NaturalLanguage framework. Provides note classification (keyword-based module routing), sentiment analysis (NLTagger), weekly report generation, and contextual day brief summaries.

### AIExecutiveService
Advanced AI for EA features. Parses natural language into structured tasks (title, deadline, priority, duration). Scaffolds projects with auto-generated milestones. Generates daily plans with time-blocked schedules. Recommends next-best-action based on current energy and task urgency.

### MultiProviderChatService
Streaming AI chat supporting multiple providers:
- **Claude**: Sonnet 4, Haiku 4.5, Opus 4 (via Anthropic API)
- **Gemini**: 2.5 Pro, 2.5 Flash (via Google AI API)

Features model switching, streaming token delivery, conversation history, and configurable system prompts.

### CalendarService
EventKit wrapper providing calendar event access, reminder management, time block creation, and date-range queries. Handles permission requests and caches today's events.

### HealthKitService
HealthKit integration reading sleep analysis, step count, active energy, heart rate, and stand hours. Computes a composite energy score (1-10) from sleep quality and activity level.

### WeatherService
Fetches current weather from Open-Meteo API with location resolution via LocationService. 15-minute cache. Returns temperature, condition, humidity, feels-like, and actionable weather notes.

### LocationService
CLLocationManager delegate providing GPS coordinates, reverse geocoding, and forward city search. Supports custom location override for weather/explore features.

### NotificationService
Local notification scheduling for morning day briefs, deadline escalation alerts (72h/24h/2h), and configurable reminders. Supports cancellation by identifier prefix.

### HapticService
Static utility for UIKit haptic feedback patterns: impact (light/medium/heavy), notification (success/warning/error), selection, celebration (multi-tap), and mode switch.

### YelpService
Yelp Fusion API client for business search and detail retrieval. Returns structured business data including name, rating, reviews, hours, price, categories, and distance.

### TrendService
Analytics engine computing metrics over configurable time windows (7/14/30/90 days). Aggregates focus time, task completion, mood/energy averages, social interactions, habit streaks, and generates trend insights.

### AudioService
Voice recording and playback using AVFoundation. Captures audio for note transcription.

### SpeechService
Text-to-speech using AVSpeechSynthesizer with configurable rate, pitch, and volume.

---

## Dependency Injection

All service access is wrapped in TCA dependency clients defined in `AppReducer.swift`:

| Client | Purpose |
|--------|---------|
| **AxisPersistenceClient** | All SwiftData CRUD operations (35+ methods) |
| **AxisHapticsClient** | Haptic feedback patterns |
| **AxisWeatherClient** | Weather data fetching |
| **AxisCalendarClient** | Calendar/reminder access |
| **AxisAIClient** | Day brief and weekly report generation |
| **AxisHealthClient** | HealthKit data access |
| **AxisNotificationsClient** | Notification scheduling |

---

## Theme System

### Brand Colors
- **axisGold** — Primary accent (gold)
- **axisGoldLight** / **axisGoldDark** — Light/dark variants
- **axisDark** — Dark mode background accent

### Typography
- `axisTitle` — 28pt bold serif
- `axisHeadline` — 20pt semibold
- `axisBody` — 16pt regular
- `axisCaption` — 12pt medium
- Custom: `axisSerif(size:)`, `axisRounded(size:)`

### Design Tokens
- Card radius: 16pt
- Button radius: 12pt
- Chip radius: 8pt
- Card shadow: 0.08 opacity, 8pt radius
- Spacing: 8 / 16 / 24pt (small / medium / large)

### Shared Components
- **GlassCard** — Frosted glass material card
- **ConfettiView** — Celebration particle animation
- **ShimmerModifier** — Skeleton loading state
- **MiniChartView** — Inline data visualization
- **ContactPickerView** — iOS contact picker wrapper

---

## External Dependencies

| Package | Purpose |
|---------|---------|
| **ComposableArchitecture** | TCA state management framework |

### System Frameworks Used
SwiftUI, SwiftData, Combine, Foundation, EventKit, HealthKit, CoreLocation, MapKit, UserNotifications, AVFoundation, Speech, CoreML, NaturalLanguage, UIKit

---

## Build & Deploy

- **Platform**: iOS
- **Minimum Target**: iOS 17
- **Device**: iPhone
- **Signing**: Apple Development (runell_king@subr.edu)
- **Bundle ID**: com.runellking.axis
- **Architecture**: arm64
