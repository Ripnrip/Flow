/**
 * 🎛️ CommandTileIntents — The Super Command Center Verbs
 *
 * "A constellation of AppIntents that power the command center:
 *  start focus on a named task, summon stats, sync integrations,
 *  open the inbox, and execute any configured command tile.
 *
 *  Each intent is a small spell. Together they let widgets, Control Center,
 *  Live Activities, Siri, and Shortcuts command Flow without opening it."
 *
 * Targets: Flow (main app) AND WidgetsExtension
 *   — CommandTileIntents.swift is included in both targets so intents run
 *     in the widget extension process for widgets/controls/Live Activities
 *     and are registered by the main app for Siri/Shortcuts.
 *
 * - The Cosmic Command Center Conductor
 */

import AppIntents
import ActivityKit
import OSLog
import SwiftUI
import WidgetKit

// MARK: - 🚀 Start Focus on a Specific Task

/// Starts a focus session on a task identified by name.
///
/// Siri phrase: "Start focusing on [task name] in Flow."
/// Shortcuts action: "Start Focus on Task".
struct StartFocusOnTaskIntent: AppIntent {

    static let openAppWhenRun: Bool = false
    static let title: LocalizedStringResource = "Start Focus on Task"
    static let description = IntentDescription(
        "Begin a Flow focus session on a specific task.",
        categoryName: "Focus"
    )
    static let isDiscoverable: Bool = true

    @Parameter(title: "Task Name", requestValueDialog: IntentDialog("Which task would you like to focus on?"))
    var taskName: String

    init() { self.taskName = "" }
    init(taskName: String) { self.taskName = taskName }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        FlowLogger.intent.info("🚀 [StartFocusOnTaskIntent] taskName: '\(taskName)'")

        // Store the requested task name in App Groups so the main app can
        // resolve it against SwiftData and start the session on foreground.
        if let defaults = UserDefaults(suiteName: kFlowAppGroup) {
            defaults.set(taskName, forKey: "com.binarybros.Flow.pendingFocusTaskName")
        }

        // Ask the system to wake the app so it can start the Live Activity.
        // Note: AppIntents in the extension cannot directly start a Live Activity;
        // we rely on the app handling the pending name in `handleStartup` / foreground.
        WidgetCenter.shared.reloadAllTimelines()

        return .result(value: true)
    }
}

// MARK: - 📊 Show Daily Stats

/// Reads today's focus summary aloud or returns it to Shortcuts.
///
/// Siri phrase: "How long have I focused today?"
struct ShowDailyStatsIntent: AppIntent {

    static let openAppWhenRun: Bool = false
    static let title: LocalizedStringResource = "Show Daily Focus Stats"
    static let description = IntentDescription(
        "Get today's total focus time, completed tasks, and current streak.",
        categoryName: "Focus"
    )
    static let isDiscoverable: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let summary = await SharedTaskStore.shared.loadDailySummary()
        let spoken = "You've focused for \(summary.formattedDuration) today, completed \(summary.completed) task\(summary.completed == 1 ? "" : "s"), and your streak is \(summary.streakDays) day\(summary.streakDays == 1 ? "" : "s")."
        FlowLogger.intent.info("📊 [ShowDailyStatsIntent] \(spoken)")
        return .result(value: spoken)
    }
}

// MARK: - 🔄 Sync All Integrations

/// Pulls fresh tasks from Calendar, Reminders, Todoist, and FlowServer.
///
/// Siri phrase: "Sync my Flow tasks."
struct SyncIntegrationsIntent: AppIntent {

    static let openAppWhenRun: Bool = false
    static let title: LocalizedStringResource = "Sync Flow Integrations"
    static let description = IntentDescription(
        "Import the latest tasks from Calendar, Reminders, Todoist, and FlowServer.",
        categoryName: "Focus"
    )
    static let isDiscoverable: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        FlowLogger.intent.info("🔄 [SyncIntegrationsIntent] Requesting sync")

        // Widget extension cannot run the full integrations itself;
        // set a pending flag so the main app syncs on next foreground.
        if let defaults = UserDefaults(suiteName: kFlowAppGroup) {
            defaults.set(true, forKey: "com.binarybros.Flow.pendingSync")
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result(value: true)
    }
}

// MARK: - 📥 Open Inbox

/// Opens Flow directly to the inbox.
struct OpenInboxIntent: AppIntent {

    static let openAppWhenRun: Bool = true
    static let title: LocalizedStringResource = "Open Flow Inbox"
    static let description = IntentDescription(
        "Jump straight into the Flow inbox.",
        categoryName: "Focus"
    )
    static let isDiscoverable: Bool = true

    func perform() async throws -> some IntentResult {
        FlowLogger.intent.info("📥 [OpenInboxIntent] Opening inbox")
        return .result()
    }
}

// MARK: - 🎛️ Execute Configured Command Tile

/// The universal dispatcher used by command-center widgets and controls.
/// It reads the persisted tile layout, finds the tile at the requested index,
/// and performs its action.
struct ExecuteCommandTileIntent: AppIntent {

    static let openAppWhenRun: Bool = false
    static let title: LocalizedStringResource = "Execute Command Tile"
    static let description = IntentDescription(
        "Run the action assigned to a command-center tile.",
        categoryName: "Focus"
    )

    @Parameter(title: "Tile Index")
    var tileIndex: Int

    init() { self.tileIndex = 0 }
    init(tileIndex: Int) { self.tileIndex = tileIndex }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let tiles = await SharedTaskStore.shared.loadCommandTiles()
        guard tiles.indices.contains(tileIndex) else {
            FlowLogger.intent.warning("⚠️ [ExecuteCommandTileIntent] Invalid tile index \(tileIndex)")
            return .result(value: false)
        }
        let tile = tiles[tileIndex]
        FlowLogger.intent.info("🎛️ [ExecuteCommandTileIntent] index=\(tileIndex) action=\(tile.action.rawValue)")

        switch tile.action {
        case .snooze:
            if let updated = await SharedTaskStore.shared.snooze() {
                await pushLiveActivityUpdate(state: makeContentState(from: updated))
                WidgetCenter.shared.reloadAllTimelines()
            }
        case .complete:
            if let completed = await SharedTaskStore.shared.complete() {
                _ = completed
                await endAllLiveActivities()
                WidgetCenter.shared.reloadAllTimelines()
            }
        case .startFocus:
            if let taskName = tile.title.isEmpty ? nil : tile.title {
                let intent = StartFocusOnTaskIntent(taskName: taskName)
                _ = try? await intent.perform()
            }
        case .syncAll:
            let intent = SyncIntegrationsIntent()
            _ = try? await intent.perform()
        case .showStats:
            let intent = ShowDailyStatsIntent()
            _ = try? await intent.perform()
        case .openInbox, .openURL, .runShortcut:
            // These actions need the main app process (to open URLs/Shortcuts or the app itself).
            // Persist the request in App Groups; the main app checks for pending actions
            // on foreground and performs them. Widget/Control Center extension cannot
            // open arbitrary URLs directly.
            if let defaults = UserDefaults(suiteName: kFlowAppGroup) {
                defaults.set(tile.action.rawValue, forKey: "com.binarybros.Flow.pendingCommandAction")
                defaults.set(tile.payload, forKey: "com.binarybros.Flow.pendingCommandPayload")
            }
            WidgetCenter.shared.reloadAllTimelines()
        }

        return .result(value: true)
    }
}

// MARK: - 🎛️ Control Center Dispatcher

/// A dedicated Control Center intent that executes a tile without parameters.
/// Users assign one control per tile; the system invokes this intent.
@available(iOS 18.0, *)
struct ExecuteCommandTileControlIntent: AppIntent {

    static let openAppWhenRun: Bool = false
    static let title: LocalizedStringResource = "Run Command Tile"
    static let description = IntentDescription(
        "Run a Flow command tile from Control Center.",
        categoryName: "Focus"
    )

    @Parameter(title: "Tile Index")
    var tileIndex: Int

    init() { self.tileIndex = 0 }
    init(tileIndex: Int) { self.tileIndex = tileIndex }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let intent = ExecuteCommandTileIntent(tileIndex: tileIndex)
        return try await intent.perform()
    }
}

// MARK: - 📌 Start Focus on Pinned Task

/// Starts a focus session on a pinned task identified by its widget index.
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
