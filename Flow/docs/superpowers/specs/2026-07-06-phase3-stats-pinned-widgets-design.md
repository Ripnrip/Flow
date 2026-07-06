# Phase 3 Design: Stats Widget + Pinned Tasks Widget

**Date:** 2026-07-06  
**Project:** Flow — Full Command Center  
**Scope:** WidgetKit extensions for daily focus stats and pinned-task quick actions.

---

## 1. Goal

Add two new widgets to the WidgetsExtension:

1. **StatsWidget** — surface today’s focus metrics at a glance.
2. **PinnedTasksWidget** — show pinned tasks with one-tap Focus and Done actions.

Both widgets must work without launching the app, using App Groups shared state and App Intents.

---

## 2. Supported Families

### StatsWidget
- `.systemSmall` — large focus-time number + streak indicator
- `.systemMedium` — 2×2 stat grid (focus time, sessions, completed, streak)
- `.systemLarge` — expanded stat grid + placeholder for future mini-chart

### PinnedTasksWidget
- `.systemMedium` — up to 2 pinned tasks
- `.systemLarge` — up to 4 pinned tasks

---

## 3. Data Model

### `PinnedTaskSnapshot`
A lightweight, Codable, Sendable mirror of a pinned `Item`.

```swift
struct PinnedTaskSnapshot: Sendable, Codable {
    var taskId: String
    var title: String
    var emoji: String
    var styleRawValue: String
    var isCompleted: Bool
}
```

Stored in App Groups via new methods on `SharedTaskStore`:
- `savePinnedTasks(_ tasks: [PinnedTaskSnapshot])`
- `loadPinnedTasks() -> [PinnedTaskSnapshot]`

### `DailyFocusSummary`
Already exists in `Flow/DailyFocusSummary.swift` and is shared with the widget extension.

---

## 4. App Intents

Added to `Widgets/CommandTileIntents.swift` (already shared across Flow + WidgetsExtension targets):

- `StartPinnedTaskIntent(taskIndex: Int)` — sets a pending focus flag in App Groups for the pinned task at the given index; the main app resolves it on foreground.
- `CompletePinnedTaskIntent(taskIndex: Int)` — marks the pinned task as completed in App Groups and reloads timelines.

---

## 5. Widget Behavior

### StatsWidget
- Reads `SharedTaskStore.loadDailySummary()`.
- Renders a family-appropriate layout using existing `TaskStyle` accent colors.
- Empty/missing summary displays zeros gracefully.

### PinnedTasksWidget
- Reads `SharedTaskStore.loadPinnedTasks()`.
- Each row shows emoji, title, Focus button, Done button.
- Tapping the row background opens the Flow app.
- Empty state shows “No pinned tasks” + “Open Flow” button.

---

## 6. Files to Create / Modify

### New files in `Widgets/`
- `StatsWidget.swift`
- `PinnedTasksWidget.swift`

### Modified files
- `Flow/SharedTaskStore.swift` — add `PinnedTaskSnapshot` + save/load methods.
- `Widgets/CommandTileIntents.swift` — add `StartPinnedTaskIntent`, `CompletePinnedTaskIntent`.
- `Widgets/WidgetsBundle.swift` — register `StatsWidget()` and `PinnedTasksWidget()`.
- `Flow.xcodeproj/project.pbxproj` — add `PinnedTaskSnapshot` source to WidgetsExtension exception list if placed in a separate file; if added to `SharedTaskStore.swift`, no project change is needed.

---

## 7. Error Handling

- Invalid task index in intents returns `.result(value: false)` and logs a warning.
- Missing App Groups data falls back to empty state.
- Completed pinned tasks are filtered out or shown with a struck-through style.

---

## 8. Testing Plan

1. Build the Flow scheme for iPhone 17 simulator.
2. Verify no Swift compile errors or concurrency warnings.
3. Verify `#Preview` blocks for both widgets render in Xcode canvas.
4. Run the app and confirm pinned tasks / daily summary can be saved and loaded from App Groups.

---

## 9. Out of Scope

- Real-time streak calculation history (streak remains a persisted integer).
- In-app pinning UI (Phase 5).
- Interactive configuration intents for widget personalization (future).
