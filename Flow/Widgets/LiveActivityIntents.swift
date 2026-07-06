/**
 * 🎯 LiveActivityIntents — Cross-Realm Action System
 *
 * "The intents that transcend process boundaries.
 *  SnoozeIntent and DoneIntent complete without opening the app,
 *  updating SharedTaskStore and pushing a new Live Activity content
 *  state in one async perform() call."
 *
 * Targets: Flow (main app) AND WidgetsExtension
 *   — LiveActivityIntents.swift is an exception-include for the
 *     Flow target (see project.pbxproj 84D6DE8F) and is auto-synced
 *     into WidgetsExtension via the Widgets/ folder sync.
 *
 * Intent matrix
 * ─────────────
 *  SnoozeIntent      — Live Activity button, widget button, Siri/Shortcuts
 *  DoneIntent        — Live Activity button, widget button, Siri/Shortcuts
 *  StartFocusIntent  — Siri, Shortcuts, Control Center (future)
 *
 * HIG ref: developer.apple.com/design/human-interface-guidelines/live-activities
 * API ref: developer.apple.com/documentation/appintents
 */

import AppIntents
import ActivityKit
import OSLog
import SwiftUI
import WidgetKit

// MARK: - 🎛️ Live Activity Configuration

/// An action that can appear on the Live Activity.
enum LiveActivityAction: String, Sendable, Codable, CaseIterable {
    case snooze
    case done
    case pauseResume
    case extend
}

/// How much motion the Live Activity should use.
enum LiveActivityAnimationIntensity: String, Sendable, Codable, CaseIterable {
    case calm
    case normal
    case lively
}

/// User-facing configuration for the Live Activity.
struct LiveActivityConfiguration: Sendable, Codable {
    var leadingAction: LiveActivityAction
    var trailingAction: LiveActivityAction
    var showProgressRing: Bool
    var animationIntensity: LiveActivityAnimationIntensity

    nonisolated static var `default`: LiveActivityConfiguration {
        LiveActivityConfiguration(
            leadingAction: .snooze,
            trailingAction: .done,
            showProgressRing: true,
            animationIntensity: .normal
        )
    }
}

extension LiveActivityConfiguration {
    private enum CodingKeys: String, CodingKey {
        case leadingAction, trailingAction, showProgressRing, animationIntensity
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.leadingAction = try container.decode(LiveActivityAction.self, forKey: .leadingAction)
        self.trailingAction = try container.decode(LiveActivityAction.self, forKey: .trailingAction)
        self.showProgressRing = try container.decode(Bool.self, forKey: .showProgressRing)
        self.animationIntensity = try container.decode(LiveActivityAnimationIntensity.self, forKey: .animationIntensity)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(leadingAction, forKey: .leadingAction)
        try container.encode(trailingAction, forKey: .trailingAction)
        try container.encode(showProgressRing, forKey: .showProgressRing)
        try container.encode(animationIntensity, forKey: .animationIntensity)
    }
}

// MARK: - 🏷️ Activity Attributes (shared between app + widget)

/// The ActivityKit attributes type for all Flow Live Activities.
/// `taskId` is static (set once at activity creation);
/// `ContentState` carries all mutable, live-updating fields.
public struct FlowAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        var title: String
        var snoozeCount: Int
        var moveCount: Int
        var startDate: Date
        var emoji: String
        var style: TaskStyle
        var lastInteractionDate: Date = .now
        var growthLevel: Int = 0
        var isPaused: Bool = false
        var focusTargetMinutes: Int = 25
        var elapsedPauseSeconds: TimeInterval = 0
    }
    var taskId: String
}

// MARK: - 🛠️ Helpers

nonisolated func makeContentState(from snapshot: ActiveTaskSnapshot) -> FlowAttributes.ContentState {
    FlowAttributes.ContentState(
        title: snapshot.title,
        snoozeCount: snapshot.snoozeCount,
        moveCount: snapshot.moveCount,
        startDate: snapshot.startDate,
        emoji: snapshot.emoji,
        style: snapshot.style,
        lastInteractionDate: snapshot.lastInteractionDate,
        growthLevel: snapshot.growthLevel,
        isPaused: false,
        focusTargetMinutes: 25,
        elapsedPauseSeconds: 0
    )
}

/// Push an updated state to all running Flow Live Activities.
/// Safe to call from any target; guarded by `#if os(iOS)`.
func pushLiveActivityUpdate(state: FlowAttributes.ContentState) async {
    #if os(iOS)
    await MainActor.run {
        let staleDate = Calendar.current.date(byAdding: .hour, value: 4, to: .now)
        let content   = ActivityContent(state: state, staleDate: staleDate)
        for activity in Activity<FlowAttributes>.activities {
            Task {
                await activity.update(content)
            }
            FlowLogger.liveActivity.info("🏝️ Updated Live Activity \(activity.id) snooze=\(state.snoozeCount)")
        }
    }
    #endif
}

/// End all running Flow Live Activities immediately.
func endAllLiveActivities() async {
    #if os(iOS)
    await MainActor.run {
        for activity in Activity<FlowAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            FlowLogger.liveActivity.info("🏝️ Ended Live Activity \(activity.id)")
        }
    }
    #endif
}

// MARK: - 💤 SnoozeIntent

/// Snoozes the active focus task **without opening the app**.
///
/// Execution flow:
/// 1. Increments snooze count in `SharedTaskStore` (App Groups).
/// 2. Pushes the updated state to all running Live Activities.
/// 3. Requests a WidgetKit timeline refresh.
/// 4. Returns without opening the app.
///
/// When the main app next foregrounds, `TaskService.reconcileFromSharedStore()`
/// commits the pending snooze to SwiftData.
/// Conforms to `LiveActivityIntent` (iOS 16.2+, subprotocol of `AppIntent`)
/// so the system optimises delivery to the widget extension process and
/// updates the Live Activity content state in the same pass.
struct SnoozeIntent: LiveActivityIntent {

    static let openAppWhenRun: Bool = false
    static let title: LocalizedStringResource = "Snooze Task"
    static let description = IntentDescription(
        "Snooze your active Flow task and keep your focus streak going.",
        categoryName: "Focus"
    )
    static let isDiscoverable: Bool = true

    @Parameter(title: "Task Identifier")
    var taskId: String

    init(taskId: String) { self.taskId = taskId }
    init() { self.taskId = "" }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        FlowLogger.intent.info("💤 [SnoozeIntent] Performing for task: \(taskId)")

        // 1. Mutate shared store (cross-process safe via App Groups)
        guard let updated = await SharedTaskStore.shared.snooze(taskId: taskId) else {
            FlowLogger.intent.warning("⚠️ [SnoozeIntent] No active task matching \(taskId) — nothing to snooze")
            return .result(value: false)
        }

        // 2. Push updated state to running Live Activities
        let newState = makeContentState(from: updated)
        await pushLiveActivityUpdate(state: newState)

        // 3. Invalidate widget timelines so they reflect the new snooze count
        WidgetCenter.shared.reloadAllTimelines()

        FlowLogger.intent.info("🎉 [SnoozeIntent] Snooze complete: '\(updated.title)' count=\(updated.snoozeCount)")
        return .result(value: true)
    }
}

// MARK: - ✅ DoneIntent

/// Marks the active focus task as **complete without opening the app**.
///
/// Execution flow:
/// 1. Sets `isCompleted = true` in `SharedTaskStore` (App Groups).
/// 2. Ends all running Live Activities with `.immediate` dismissal.
/// 3. Requests a WidgetKit timeline refresh.
///
/// The main app commits the completion to SwiftData on next foreground.
/// `LiveActivityIntent` so the system co-locates execution with the
/// widget extension and can update Live Activity state atomically.
struct DoneIntent: LiveActivityIntent {

    static let openAppWhenRun: Bool = false
    static let title: LocalizedStringResource = "Complete Task"
    static let description = IntentDescription(
        "Mark your active Flow task as done.",
        categoryName: "Focus"
    )
    static let isDiscoverable: Bool = true

    @Parameter(title: "Task Identifier")
    var taskId: String

    init(taskId: String) { self.taskId = taskId }
    init() { self.taskId = "" }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        FlowLogger.intent.info("✅ [DoneIntent] Performing for task: \(taskId)")

        // 1. Mark completed in shared store
        guard let completed = await SharedTaskStore.shared.complete(taskId: taskId) else {
            FlowLogger.intent.warning("⚠️ [DoneIntent] No active task matching \(taskId) — nothing to complete")
            return .result(value: false)
        }

        // 2. End all running Live Activities
        await endAllLiveActivities()

        // 3. Invalidate widget timelines (they'll show empty-state)
        WidgetCenter.shared.reloadAllTimelines()

        FlowLogger.intent.info("🎉 [DoneIntent] Completed: '\(completed.title)'")
        return .result(value: true)
    }
}

// MARK: - 🚀 StartFocusIntent (Siri / Shortcuts / Control Center)

/// Starts a focus session on a named task — exposed to Siri and Shortcuts.
///
/// On iOS 26+ this conforms to `LiveActivityStartingIntent` so the system
/// can start the Live Activity directly from a shortcut or Control Widget
/// without bringing the app to the foreground.
///
/// On earlier OS versions it falls back to opening the app (`openAppWhenRun = true`),
/// where the DeepLink handler in FlowApp reads the pending task name from
/// App Groups UserDefaults and pre-populates the add-task sheet.
@available(iOS 26.0, macOS 26.0, *)
struct StartFocusIntentLiveActivity: LiveActivityIntent {

    static let openAppWhenRun: Bool = false
    static let title: LocalizedStringResource = "Start Focus Session"
    static let description = IntentDescription(
        "Start a Live Activity focus session directly from Siri or Control Center.",
        categoryName: "Focus"
    )
    static let isDiscoverable: Bool = true

    @Parameter(title: "Task Name", requestValueDialog: IntentDialog("What task would you like to focus on?"))
    var taskName: String

    init() { self.taskName = "" }
    init(taskName: String) { self.taskName = taskName }

    func perform() async throws -> some IntentResult {
        FlowLogger.intent.info("🚀 [StartFocusIntentLiveActivity] task: '\(taskName)'")
        if let defaults = UserDefaults(suiteName: kFlowAppGroup) {
            defaults.set(taskName, forKey: "com.binarybros.Flow.pendingTaskName")
        }
        return .result()
    }
}

/// Pre-iOS-26 fallback: opens the app to start a session.
struct StartFocusIntent: AppIntent {

    static let openAppWhenRun: Bool = true
    static let title: LocalizedStringResource = "Start Focus Session"
    static let description = IntentDescription(
        "Open Flow and start focusing on a specific task.",
        categoryName: "Focus"
    )
    static let isDiscoverable: Bool = true

    @Parameter(title: "Task Name", requestValueDialog: IntentDialog("What task would you like to focus on?"))
    var taskName: String

    init() { self.taskName = "" }
    init(taskName: String) { self.taskName = taskName }

    func perform() async throws -> some IntentResult & OpensIntent {
        FlowLogger.intent.info("🚀 [StartFocusIntent] Opening app for task: '\(taskName)'")
        if let defaults = UserDefaults(suiteName: kFlowAppGroup) {
            defaults.set(taskName, forKey: "com.binarybros.Flow.pendingTaskName")
        }
        return .result()
    }
}
