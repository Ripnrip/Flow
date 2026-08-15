# Phase 5 Design: In-App Command Center Editor

**Date:** 2026-07-06  
**Project:** Flow — Full Command Center  
**Scope:** Add an in-app editor where users can configure Command Center tiles, pinned tasks, and Live Activity actions.

---

## 1. Goal

Add a **Command Center** destination to the main app that lets users configure:

1. The 4 command tiles shown in the `CommandCenterWidget`
2. The pinned tasks shown in the `PinnedTasksWidget`
3. The Live Activity action buttons and visual settings

All configuration is persisted in App Groups via `SharedTaskStore`, so widgets and Live Activities update immediately.

---

## 2. Navigation

Add a new sidebar item in `ContentView`:

```swift
case commandCenter
```

Label: **Command Center** with `slider.horizontal.3` icon.

Selection reveals the editor in the content column.

---

## 3. Editor Sections

### 3.1 Command Tiles

Grid of 4 editable tiles. Each tile exposes:

- Title text field
- Icon picker (emoji or SF Symbol)
- Action picker (`CommandTileAction`)
- Style picker (`TaskStyle`)

Actions include: `startFocus`, `snooze`, `completeTop`, `syncAll`, `showStats`, `openInbox`, `openURL`, `runShortcut`.

Tapping a tile opens an edit sheet. The 4 tiles are fixed-count; users edit existing ones, not add/remove.

### 3.2 Pinned Tasks

List of all non-completed `Item`s with:

- Pin toggle
- Reorder handle (limited to max 4 pinned tasks)

Shows "Max 4 pinned tasks" hint when limit reached.

### 3.3 Live Activity

- Leading action picker (`LiveActivityAction`)
- Trailing action picker (`LiveActivityAction`)
- Show progress ring toggle
- Animation intensity picker (`LiveActivityAnimationIntensity`)

---

## 4. Data Model

The editor consumes existing models already persisted in App Groups:

- `[CommandTile]` via `SharedTaskStore.loadCommandTiles()` / `saveCommandTiles(_:)`
- `[PinnedTaskSnapshot]` via `SharedTaskStore.loadPinnedTasks()` / `savePinnedTasks(_:)`
- `LiveActivityConfiguration` via `SharedTaskStore.loadLiveActivityConfiguration()` / `saveLiveActivityConfiguration(_:)`

---

## 5. Files to Create / Modify

### New files in `Flow/`
- `CommandCenterEditorView.swift` — root editor with tabbed sections
- `CommandTileEditorView.swift` — 4-tile grid editor
- `PinnedTaskPickerView.swift` — pin/reorder UI
- `LiveActivityConfigEditorView.swift` — Live Activity settings

### Modified files
- `Flow/Flow/ContentView.swift` — add `commandCenter` navigation item and case handling
- `Flow/Flow/SharedTaskStore.swift` — add helper to build `[PinnedTaskSnapshot]` from `[Item]` if needed

---

## 6. Error Handling

- Empty task list in Pinned Tasks section shows "Add a task first"
- Max pinned tasks reached disables additional pin toggles
- Invalid tile configurations fall back to defaults
- Save failures log via `FlowLogger`

---

## 7. Testing Plan

1. Build Flow scheme for iPhone 17 simulator.
2. Verify the Command Center sidebar item appears and navigates correctly.
3. Verify editing tiles persists and widgets update.
4. Verify pinning tasks persists and widgets update.
5. Verify Live Activity config persists.

---

## 8. Out of Scope

- Undo/redo in editor
- iCloud sync of configuration
- macOS menu bar configuration
- Accessibility audit (follow existing patterns)
