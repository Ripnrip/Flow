# Phase 3: Stats Widget + Pinned Tasks Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `StatsWidget` and `PinnedTasksWidget` to the WidgetsExtension, backed by App Groups shared state and App Intents.

**Architecture:** Reuse the existing `SharedTaskStore` actor for cross-process persistence. Add a lightweight `PinnedTaskSnapshot` model, two new widget configurations, and two new App Intents for pinned-task actions. Register the widgets in `WidgetsBundle`.

**Tech Stack:** Swift 6, SwiftUI, WidgetKit, AppIntents, App Groups (`group.com.binarybros.Flow`).

## Global Constraints

- iOS 26 / Swift 6.2 / Xcode 26.0
- Strict concurrency disabled (`SWIFT_STRICT_CONCURRENCY = targeted`) in current build settings
- Widget extension cannot reference `Item.swift` (SwiftData model)
- All cross-process models must be `Codable` + `Sendable`
- New files in `Widgets/` auto-sync to `WidgetsExtension`; cross-target sharing requires `project.pbxproj` exception lists

---

## Task 1: Add Pinned Task Model + SharedTaskStore Persistence

**Files:**
- Modify: `Flow/SharedTaskStore.swift`

**Interfaces:**
- Produces: `PinnedTaskSnapshot` struct
- Produces: `SharedTaskStore.savePinnedTasks(_:)`
- Produces: `SharedTaskStore.loadPinnedTasks() -> [PinnedTaskSnapshot]`

- [ ] **Step 1: Add `PinnedTaskSnapshot` above `ActiveTaskSnapshot`**

```swift
/// A lightweight, Codable mirror of a pinned `Item`.
/// Shared via App Groups so the pinned-tasks widget can render
/// without importing the SwiftData model.
struct PinnedTaskSnapshot: Sendable, Codable {
    var taskId: String
    var title: String
    var emoji: String
    var styleRawValue: String
    var isCompleted: Bool

    nonisolated var style: TaskStyle {
        TaskStyle(rawValue: styleRawValue) ?? .sleekModern
    }
}
```

- [ ] **Step 2: Add keys and CRUD methods inside `SharedTaskStore`**

Add after `summaryKey`:
```swift
private let pinnedKey = "com.binarybros.Flow.pinnedTasks"
```

Add after `loadDailySummary()`:
```swift
    /// Persist the pinned task list to App Groups.
    func savePinnedTasks(_ tasks: [PinnedTaskSnapshot]) {
        guard let defaults else {
            FlowLogger.sync.error("⚠️ [SharedTaskStore] App Groups unavailable — cannot save pinned tasks")
            return
        }
        do {
            let data = try JSONEncoder().encode(tasks)
            defaults.set(data, forKey: pinnedKey)
            FlowLogger.sync.info("📌 [SharedTaskStore] Saved \(tasks.count) pinned task(s)")
        } catch {
            FlowLogger.sync.error("⚠️ [SharedTaskStore] Pinned tasks encode failed: \(error.localizedDescription)")
        }
    }

    /// Load the pinned task list from App Groups.
    func loadPinnedTasks() -> [PinnedTaskSnapshot] {
        guard let defaults,
              let data = defaults.data(forKey: pinnedKey) else { return [] }
        do {
            return try JSONDecoder().decode([PinnedTaskSnapshot].self, from: data)
        } catch {
            FlowLogger.sync.error("⚠️ [SharedTaskStore] Pinned tasks decode failed: \(error.localizedDescription)")
            return []
        }
    }
```

- [ ] **Step 3: Build the Flow scheme**

Run:
```bash
cd /Users/admin/Developer/Flow-GitHub/Flow
xcodebuild build -project Flow.xcodeproj -scheme Flow \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=D3914993-86CF-46F5-94C5-BDE0CAA0ADBF' \
  ONLY_ACTIVE_ARCH=YES CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

Expected: `** BUILD SUCCEEDED **`

---

## Task 2: Add Pinned Task App Intents

**Files:**
- Modify: `Widgets/CommandTileIntents.swift`

**Interfaces:**
- Produces: `StartPinnedTaskIntent`
- Produces: `CompletePinnedTaskIntent`

- [ ] **Step 1: Append `StartPinnedTaskIntent` after `ExecuteCommandTileControlIntent`**

```swift
// MARK: - 📌 Start Focus on Pinned Task

/// Starts focus on a pinned task identified by its widget index.
struct StartPinnedTaskIntent: AppIntent {
    static let openAppWhenRun: Bool = false
    static let title: LocalizedStringResource = "Start Focus on Pinned Task"
    static let description = IntentDescription(
        "Begin a Flow focus session on a pinned task.",
        categoryName: "Focus"
    )
    static let isDiscoverable: Bool = true

    @Parameter(title: "Task Index")
    var taskIndex: Int

    init() { self.taskIndex = 0 }
    init(taskIndex: Int) { self.taskIndex = taskIndex }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let tasks = await SharedTaskStore.shared.loadPinnedTasks()
        guard tasks.indices.contains(taskIndex) else {
            FlowLogger.intent.warning("⚠️ [StartPinnedTaskIntent] Invalid index \(taskIndex)")
            return .result(value: false)
        }
        let task = tasks[taskIndex]
        FlowLogger.intent.info("📌 [StartPinnedTaskIntent] index=\(taskIndex) title='\(task.title)'")

        if let defaults = UserDefaults(suiteName: kFlowAppGroup) {
            defaults.set(task.taskId, forKey: "com.binarybros.Flow.pendingPinnedFocusTaskId")
            defaults.set(task.title, forKey: "com.binarybros.Flow.pendingFocusTaskName")
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result(value: true)
    }
}
```

- [ ] **Step 2: Append `CompletePinnedTaskIntent`**

```swift
// MARK: - ✅ Complete Pinned Task

/// Marks a pinned task as completed.
struct CompletePinnedTaskIntent: AppIntent {
    static let openAppWhenRun: Bool = false
    static let title: LocalizedStringResource = "Complete Pinned Task"
    static let description = IntentDescription(
        "Mark a pinned Flow task as done.",
        categoryName: "Focus"
    )
    static let isDiscoverable: Bool = true

    @Parameter(title: "Task Index")
    var taskIndex: Int

    init() { self.taskIndex = 0 }
    init(taskIndex: Int) { self.taskIndex = taskIndex }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        var tasks = await SharedTaskStore.shared.loadPinnedTasks()
        guard tasks.indices.contains(taskIndex) else {
            FlowLogger.intent.warning("⚠️ [CompletePinnedTaskIntent] Invalid index \(taskIndex)")
            return .result(value: false)
        }
        tasks[taskIndex].isCompleted = true
        await SharedTaskStore.shared.savePinnedTasks(tasks)
        FlowLogger.intent.info("✅ [CompletePinnedTaskIntent] index=\(taskIndex) title='\(tasks[taskIndex].title)'")
        WidgetCenter.shared.reloadAllTimelines()
        return .result(value: true)
    }
}
```

- [ ] **Step 3: Build the Flow scheme**

Same command as Task 1, Step 3.
Expected: `** BUILD SUCCEEDED **`

---

## Task 3: Implement StatsWidget

**Files:**
- Create: `Widgets/StatsWidget.swift`

**Interfaces:**
- Produces: `StatsWidgetConfiguration` intent
- Produces: `StatsWidgetEntry`, `StatsProvider`, `StatsWidgetEntryView`, `StatsWidget`

- [ ] **Step 1: Create `Widgets/StatsWidget.swift` with the following content**

```swift
/**
 * 📊 StatsWidget — The Daily Focus Scoreboard
 *
 * "A glanceable dashboard of today's focus wins:
 *  total time, sessions, completed tasks, and streak."
 */

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - ⚙️ Configuration

struct StatsWidgetConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Focus Stats"
    static let description = IntentDescription("Today's focus summary at a glance.")
}

// MARK: - 📅 Entry

struct StatsWidgetEntry: TimelineEntry {
    let date: Date
    let summary: DailyFocusSummary
    let configuration: StatsWidgetConfiguration
}

// MARK: - 📡 Provider

struct StatsProvider: AppIntentTimelineProvider {
    typealias Entry = StatsWidgetEntry
    typealias Intent = StatsWidgetConfiguration

    func placeholder(in context: Context) -> StatsWidgetEntry {
        StatsWidgetEntry(date: .now, summary: .empty, configuration: StatsWidgetConfiguration())
    }

    func snapshot(for configuration: StatsWidgetConfiguration, in context: Context) async -> StatsWidgetEntry {
        let summary = await SharedTaskStore.shared.loadDailySummary()
        return StatsWidgetEntry(date: .now, summary: summary, configuration: configuration)
    }

    func timeline(for configuration: StatsWidgetConfiguration, in context: Context) async -> Timeline<StatsWidgetEntry> {
        let summary = await SharedTaskStore.shared.loadDailySummary()
        let entry = StatsWidgetEntry(date: .now, summary: summary, configuration: configuration)
        let nextUpdate = Date().addingTimeInterval(5 * 60)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// MARK: - 🖼️ Entry View

struct StatsWidgetEntryView: View {
    let entry: StatsWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .systemLarge:
            largeView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(spacing: 4) {
            Text(entry.summary.formattedDuration)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("\(entry.summary.streakDays)d")
                    .font(.caption.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumView: some View {
        HStack(spacing: 12) {
            statCell(value: entry.summary.formattedDuration, label: "Focused", icon: "clock.fill", color: .blue)
            statCell(value: "\(entry.summary.sessionsCount)", label: "Sessions", icon: "bolt.fill", color: .green)
            statCell(value: "\(entry.summary.completed)", label: "Done", icon: "checkmark.circle.fill", color: .purple)
            statCell(value: "\(entry.summary.streakDays)", label: "Streak", icon: "flame.fill", color: .orange)
        }
        .padding(.horizontal, 12)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var largeView: some View {
        VStack(spacing: 16) {
            Text("Today's Focus")
                .font(.headline.weight(.bold))

            HStack(spacing: 16) {
                statCell(value: entry.summary.formattedDuration, label: "Focused", icon: "clock.fill", color: .blue)
                statCell(value: "\(entry.summary.sessionsCount)", label: "Sessions", icon: "bolt.fill", color: .green)
            }

            HStack(spacing: 16) {
                statCell(value: "\(entry.summary.completed)", label: "Done", icon: "checkmark.circle.fill", color: .purple)
                statCell(value: "\(entry.summary.streakDays)", label: "Streak", icon: "flame.fill", color: .orange)
            }
        }
        .padding(16)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 📦 Widget

struct StatsWidget: Widget {
    let kind: String = "com.binarybros.Flow.Stats"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: StatsWidgetConfiguration.self, provider: StatsProvider()) { entry in
            StatsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Focus Stats")
        .description("Today's focus time, sessions, completed tasks, and streak.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - 🧪 Previews

#Preview("Stats — Small", as: .systemSmall) {
    StatsWidget()
} timeline: {
    StatsWidgetEntry(date: .now, summary: DailyFocusSummary(totalFocusSeconds: 7420, sessionsCount: 3, snoozes: 1, completed: 2, streakDays: 5), configuration: StatsWidgetConfiguration())
}

#Preview("Stats — Medium", as: .systemMedium) {
    StatsWidget()
} timeline: {
    StatsWidgetEntry(date: .now, summary: DailyFocusSummary(totalFocusSeconds: 7420, sessionsCount: 3, snoozes: 1, completed: 2, streakDays: 5), configuration: StatsWidgetConfiguration())
}

#Preview("Stats — Large", as: .systemLarge) {
    StatsWidget()
} timeline: {
    StatsWidgetEntry(date: .now, summary: DailyFocusSummary(totalFocusSeconds: 7420, sessionsCount: 3, snoozes: 1, completed: 2, streakDays: 5), configuration: StatsWidgetConfiguration())
}
```

- [ ] **Step 2: Build the Flow scheme**

Same command as Task 1, Step 3.
Expected: `** BUILD SUCCEEDED **`

---

## Task 4: Implement PinnedTasksWidget

**Files:**
- Create: `Widgets/PinnedTasksWidget.swift`

**Interfaces:**
- Produces: `PinnedTasksWidgetConfiguration` intent
- Produces: `PinnedTasksWidgetEntry`, `PinnedTasksProvider`, `PinnedTasksEntryView`, `PinnedTasksWidget`

- [ ] **Step 1: Create `Widgets/PinnedTasksWidget.swift`**

```swift
/**
 * 📌 PinnedTasksWidget — The Focus Launchpad
 *
 * "Pinned tasks, one tap away. Each row is a mission:
 *  Focus to begin, Done to finish, or tap the body to open Flow."
 */

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - ⚙️ Configuration

struct PinnedTasksWidgetConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Pinned Tasks"
    static let description = IntentDescription("Quick actions for your pinned Flow tasks.")
}

// MARK: - 📅 Entry

struct PinnedTasksWidgetEntry: TimelineEntry {
    let date: Date
    let tasks: [PinnedTaskSnapshot]
    let configuration: PinnedTasksWidgetConfiguration
}

// MARK: - 📡 Provider

struct PinnedTasksProvider: AppIntentTimelineProvider {
    typealias Entry = PinnedTasksWidgetEntry
    typealias Intent = PinnedTasksWidgetConfiguration

    func placeholder(in context: Context) -> PinnedTasksWidgetEntry {
        PinnedTasksWidgetEntry(date: .now, tasks: placeholderTasks, configuration: PinnedTasksWidgetConfiguration())
    }

    func snapshot(for configuration: PinnedTasksWidgetConfiguration, in context: Context) async -> PinnedTasksWidgetEntry {
        let tasks = await SharedTaskStore.shared.loadPinnedTasks()
        return PinnedTasksWidgetEntry(date: .now, tasks: tasks.isEmpty ? placeholderTasks : tasks, configuration: configuration)
    }

    func timeline(for configuration: PinnedTasksWidgetConfiguration, in context: Context) async -> Timeline<PinnedTasksWidgetEntry> {
        let tasks = await SharedTaskStore.shared.loadPinnedTasks()
        let entry = PinnedTasksWidgetEntry(date: .now, tasks: tasks.isEmpty ? placeholderTasks : tasks, configuration: configuration)
        let nextUpdate = Date().addingTimeInterval(5 * 60)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private var placeholderTasks: [PinnedTaskSnapshot] {
        [
            PinnedTaskSnapshot(taskId: UUID().uuidString, title: "Deep Work", emoji: "🎯", styleRawValue: TaskStyle.cyberpunk.rawValue, isCompleted: false),
            PinnedTaskSnapshot(taskId: UUID().uuidString, title: "Email", emoji: "📧", styleRawValue: TaskStyle.sleekModern.rawValue, isCompleted: false)
        ]
    }
}

// MARK: - 🖼️ Entry View

struct PinnedTasksEntryView: View {
    let entry: PinnedTasksWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var maxTasks: Int {
        family == .systemLarge ? 4 : 2
    }

    var body: some View {
        let visible = Array(entry.tasks.prefix(maxTasks))
        VStack(spacing: 8) {
            ForEach(Array(visible.enumerated()), id: \\(.offset)) { index, task in
                PinnedTaskRow(task: task, index: index)
            }
        }
        .padding(family == .systemLarge ? 14 : 12)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - 📌 Row

struct PinnedTaskRow: View {
    let task: PinnedTaskSnapshot
    let index: Int

    var body: some View {
        Button(intent: OpenInboxIntent()) {
            HStack(spacing: 10) {
                Text(task.emoji)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(task.isCompleted ? "Done" : "Ready to focus")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !task.isCompleted {
                    HStack(spacing: 6) {
                        Button(intent: StartPinnedTaskIntent(taskIndex: index)) {
                            Image(systemName: "play.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(task.style.themeAccentColor()))
                        }
                        .buttonStyle(.plain)

                        Button(intent: CompletePinnedTaskIntent(taskIndex: index)) {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(.green))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(task.style.themeBackgroundColor().opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 📦 Widget

struct PinnedTasksWidget: Widget {
    let kind: String = "com.binarybros.Flow.PinnedTasks"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: PinnedTasksWidgetConfiguration.self, provider: PinnedTasksProvider()) { entry in
            PinnedTasksEntryView(entry: entry)
        }
        .configurationDisplayName("Pinned Tasks")
        .description("Focus on or complete your pinned Flow tasks.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - 🧪 Previews

#Preview("Pinned Tasks — Medium", as: .systemMedium) {
    PinnedTasksWidget()
} timeline: {
    PinnedTasksWidgetEntry(
        date: .now,
        tasks: [
            PinnedTaskSnapshot(taskId: UUID().uuidString, title: "Deep Work", emoji: "🎯", styleRawValue: TaskStyle.cyberpunk.rawValue, isCompleted: false),
            PinnedTaskSnapshot(taskId: UUID().uuidString, title: "Email", emoji: "📧", styleRawValue: TaskStyle.sleekModern.rawValue, isCompleted: false)
        ],
        configuration: PinnedTasksWidgetConfiguration()
    )
}

#Preview("Pinned Tasks — Large", as: .systemLarge) {
    PinnedTasksWidget()
} timeline: {
    PinnedTasksWidgetEntry(
        date: .now,
        tasks: [
            PinnedTaskSnapshot(taskId: UUID().uuidString, title: "Deep Work", emoji: "🎯", styleRawValue: TaskStyle.cyberpunk.rawValue, isCompleted: false),
            PinnedTaskSnapshot(taskId: UUID().uuidString, title: "Email", emoji: "📧", styleRawValue: TaskStyle.sleekModern.rawValue, isCompleted: false),
            PinnedTaskSnapshot(taskId: UUID().uuidString, title: "Workout", emoji: "💪", styleRawValue: TaskStyle.retro.rawValue, isCompleted: true),
            PinnedTaskSnapshot(taskId: UUID().uuidString, title: "Read", emoji: "📚", styleRawValue: TaskStyle.nature.rawValue, isCompleted: false)
        ],
        configuration: PinnedTasksWidgetConfiguration()
    )
}
```

- [ ] **Step 2: Build the Flow scheme**

Same command as Task 1, Step 3.
Expected: `** BUILD SUCCEEDED **`

---

## Task 5: Register Widgets in WidgetsBundle

**Files:**
- Modify: `Widgets/WidgetsBundle.swift`

**Interfaces:**
- Consumes: `StatsWidget()`
- Consumes: `PinnedTasksWidget()`

- [ ] **Step 1: Add the two widgets to the bundle body**

Insert after `CommandCenterWidget()`:

```swift
        // 📊 Daily focus stats
        StatsWidget()

        // 📌 Pinned tasks with Focus / Done actions
        PinnedTasksWidget()
```

- [ ] **Step 2: Build the Flow scheme**

Same command as Task 1, Step 3.
Expected: `** BUILD SUCCEEDED **`

---

## Task 6: Verify Widget Previews

**Files:**
- Review: `Widgets/StatsWidget.swift` previews
- Review: `Widgets/PinnedTasksWidget.swift` previews

- [ ] **Step 1: Open each `#Preview` in Xcode canvas or build with previews enabled**

Run:
```bash
cd /Users/admin/Developer/Flow-GitHub/Flow
xcodebuild build -project Flow.xcodeproj -scheme Flow \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=D3914993-86CF-46F5-94C5-BDE0CAA0ADBF' \
  ONLY_ACTIVE_ARCH=YES CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  ENABLE_PREVIEWS=YES
```

Expected: `** BUILD SUCCEEDED **` (previews compile)

---

## Self-Review

1. **Spec coverage:**
   - StatsWidget small/medium/large ✓ (Task 3)
   - PinnedTasksWidget medium/large ✓ (Task 4)
   - PinnedTaskSnapshot + SharedTaskStore methods ✓ (Task 1)
   - StartPinnedTaskIntent + CompletePinnedTaskIntent ✓ (Task 2)
   - WidgetsBundle registration ✓ (Task 5)

2. **Placeholder scan:** No TBD/TODO/fill-in-details found.

3. **Type consistency:** `PinnedTaskSnapshot` fields match usage in `PinnedTasksWidget.swift`. `DailyFocusSummary` fields match `StatsWidget.swift`. `TaskStyle.themeAccentColor()` and `themeBackgroundColor()` are existing helpers.

No issues found. Plan is ready for execution.
