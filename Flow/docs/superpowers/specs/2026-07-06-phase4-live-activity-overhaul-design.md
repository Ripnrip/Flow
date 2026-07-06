# Phase 4 Design: Enhanced Live Activity Overhaul

**Date:** 2026-07-06  
**Project:** Flow — Full Command Center  
**Scope:** Upgrade the existing ActivityKit Live Activity with configurable action buttons, richer animations, and improved Dynamic Island layouts.

---

## 1. Goal

Transform `WidgetsLiveActivity` from a fixed Snooze/Done timer into a configurable, animated focus command center that works across:

- Lock Screen / Banner
- Dynamic Island compact, minimal, and expanded presentations
- StandBy

Users can choose which two actions appear on the Live Activity. Default remains Snooze + Done.

---

## 2. Supported Actions

Action registry (`LiveActivityAction`):

1. **snooze** — increment snooze count; updates Live Activity
2. **done** — mark task complete; dismisses Live Activity
3. **pauseResume** — toggle a new `isPaused` flag in `FlowAttributes.ContentState`
4. **extend** — add 5 minutes to the focus target; does not mutate task state

Each action maps to a dedicated `LiveActivityIntent`:

- `SnoozeIntent` (existing)
- `DoneIntent` (existing)
- `PauseResumeIntent` (new)
- `ExtendFocusIntent` (new)

---

## 3. Configuration Model

### `LiveActivityConfiguration`

Stored in App Groups via `SharedTaskStore`.

```swift
struct LiveActivityConfiguration: Sendable, Codable {
    var leadingAction: LiveActivityAction
    var trailingAction: LiveActivityAction
    var showProgressRing: Bool
    var animationIntensity: LiveActivityAnimationIntensity
}
```

### `LiveActivityAnimationIntensity`

```swift
enum LiveActivityAnimationIntensity: String, Sendable, Codable {
    case calm    // subtle pulse only
    case normal  // pulse + wiggle/bounce on interactions
    case lively  // progress ring rotation, completion flash, stronger effects
}
```

---

## 4. Data Model Changes

### `FlowAttributes.ContentState`

Add fields:

- `isPaused: Bool` — for pause/resume action
- `focusTargetMinutes: Int` — default 25, used by Extend action and progress ring
- `elapsedPauseSeconds: TimeInterval` — accumulated paused time so timer stays accurate

Existing fields remain: `title`, `snoozeCount`, `moveCount`, `startDate`, `emoji`, `style`, `lastInteractionDate`, `growthLevel`.

---

## 5. Visual Changes

### Lock Screen / Banner
- Circular progress ring around the emoji (25-min default target)
- Title + live timer
- Two configurable action buttons at the bottom
- `.pulse` on active timer icon

### Dynamic Island — Compact
- Leading: emoji with progress ring
- Trailing: live timer

### Dynamic Island — Expanded
- Leading: emoji + progress ring
- Center: title
- Trailing: timer + snooze badge
- Bottom: two configurable action buttons + progress bar

### Dynamic Island — Minimal
- Emoji only, with subtle pulse when active

### Completion
- When `DoneIntent` fires, show a brief green flash / checkmark burst before dismissal.

---

## 6. Files to Create / Modify

### Modify
- `Flow/Widgets/LiveActivityIntents.swift`
  - Add `LiveActivityAction` enum
  - Add `PauseResumeIntent`
  - Add `ExtendFocusIntent`
  - Update `FlowAttributes.ContentState`
  - Add `LiveActivityConfiguration` + helpers
- `Flow/Widgets/WidgetsLiveActivity.swift`
  - Refactor views to use configuration
  - Add progress ring
  - Add configurable buttons
  - Add completion flash animation
- `Flow/Flow/SharedTaskStore.swift`
  - Add `LiveActivityConfiguration` save/load
  - Add pause/resume/extend helpers for `ActiveTaskSnapshot`
- `Flow/Flow/TaskService.swift`
  - Handle paused state and target extension when reconciling from shared store

### New files
- None planned; keep changes in existing Live Activity stack.

---

## 7. Error Handling

- Invalid action configuration falls back to default Snooze + Done.
- Pause/resume on a completed task is a no-op.
- Extend beyond 60 minutes caps at 60 to prevent runaway timers.

---

## 8. Testing Plan

1. Build the Flow scheme for iPhone 17 simulator.
2. Verify all `#Preview` blocks for Live Activity compile (lock screen, compact, minimal, expanded).
3. Run `FlowTests` unit suite.
4. Manual runtime check: start a focus session and verify Live Activity renders with default buttons.

---

## 9. Out of Scope

- In-app UI for configuring actions (Phase 5 Command Center editor will own this).
- Custom haptic patterns.
- watchOS / macOS Live Activity support.
