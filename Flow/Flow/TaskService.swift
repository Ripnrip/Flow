/**
 * 🎭 TaskService — The Cosmic Orchestrator of Action
 *
 * "An @MainActor @Observable class that manages the full lifecycle
 * of a focus session: ActivityKit Live Activities, background time
 * tracking via TaskLingeringActor, and the cross-process App Groups
 * bridge via SharedTaskStore."
 *
 * Swift 6 concurrency notes
 * ─────────────────────────
 *   • @MainActor isolates all UI-facing state mutations.
 *   • `await lingeringActor.*` crosses actor boundaries safely.
 *   • `await SharedTaskStore.shared.*` crosses actor boundaries safely.
 *   • All ActivityKit calls are wrapped in `#if os(iOS)`.
 *
 * Intent reconciliation
 * ─────────────────────
 *   AppIntents (SnoozeIntent, DoneIntent) mutate SharedTaskStore
 *   without opening the app. On next foreground the app calls
 *   `reconcileFromSharedStore()` to apply those changes to SwiftData
 *   and keep the single source of truth in sync.
 *
 * Logging channels used
 * ─────────────────────
 *   🌐 FlowLogger.network  — external API calls
 *   🏠 FlowLogger.local    — SwiftData / local operations
 *   🏝️ FlowLogger.liveActivity — ActivityKit
 *   🔃 FlowLogger.sync     — SharedTaskStore bridge
 *   ⚙️ FlowLogger.task     — CRUD / session operations
 *   ⚠️ FlowLogger.task.warning — degraded / unexpected paths
 *   🎉 FlowLogger.task.info — success milestones
 */

import ActivityKit
import SwiftData
import SwiftUI
import Observation
import AppIntents
import WidgetKit

@MainActor
@Observable
class TaskService {

    @ObservationIgnored
    private var modelContext: ModelContext

    @ObservationIgnored
    private let lingeringActor = TaskLingeringActor()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        FlowLogger.lifecycle.info("🌐 ✨ TaskService initialised")
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - 🔄 Session Restore / Reconcile
    // ─────────────────────────────────────────────────────────

    /// Called on app launch and foreground. Reconciles any pending changes
    /// written by AppIntents while the app was not running.
    func restoreActiveFocusSession() async {
        FlowLogger.lifecycle.info("🔄 Restoring active focus session…")

        // 1. Apply any intent-pending changes first
        await reconcileFromSharedStore()

        #if os(iOS)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            FlowLogger.liveActivity.warning("⚠️ Live Activities disabled — skipping restore")
            return
        }

        // 2. If a Live Activity is already running, re-attach background tracking
        let running = Activity<FlowAttributes>.activities
        if !running.isEmpty {
            FlowLogger.liveActivity.info("🎉 Found \(running.count) running Live Activities — re-attaching")
            for activity in running {
                if let uuid = UUID(uuidString: activity.attributes.taskId) {
                    await lingeringActor.startTracking(taskId: uuid)
                }
            }
            return
        }
        #endif

        // 3. No running Live Activity — find the most-recent uncompleted task
        do {
            let descriptor = FetchDescriptor<Item>(
                predicate: #Predicate { $0.isCompleted == false },
                sortBy: [SortDescriptor(\Item.timestamp, order: .reverse)]
            )
            if let task = try modelContext.fetch(descriptor).first {
                FlowLogger.task.info("🌟 Restoring focus on: '\(task.title)'")
                await startFocusSession(for: task)
            } else {
                FlowLogger.task.info("🌙 No uncompleted tasks — nothing to restore")
            }
        } catch {
            FlowLogger.task.error("💥 restoreActiveFocusSession fetch error: \(error.localizedDescription)")
        }
    }

    /// Reads `SharedTaskStore` for pending intent actions and commits them
    /// to SwiftData. Called on foreground and after receiving a background
    /// app-refresh task.
    func reconcileFromSharedStore() async {
        guard await SharedTaskStore.shared.needsReconciliation else {
            FlowLogger.sync.info("🔃 SharedTaskStore: nothing pending")
            return
        }

        guard let snapshot = await SharedTaskStore.shared.load() else { return }
        FlowLogger.sync.info("🔃 Reconciling snapshot: '\(snapshot.title)' pendingSnooze=\(snapshot.pendingSnooze) pendingComplete=\(snapshot.pendingComplete)")

        guard let uuid = UUID(uuidString: snapshot.taskId) else {
            FlowLogger.sync.error("⚠️ Invalid taskId in snapshot: \(snapshot.taskId)")
            return
        }

        let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == uuid })
        do {
            guard let task = try modelContext.fetch(descriptor).first else {
                FlowLogger.sync.warning("⚠️ Task \(uuid) not found in SwiftData — clearing stale snapshot")
                await SharedTaskStore.shared.clear()
                return
            }

            if snapshot.pendingSnooze {
                FlowLogger.task.info("💤 Reconcile: applying snooze to '\(task.title)'")
                let lingering = await lingeringActor.stopTracking(taskId: uuid)
                task.totalLingeringTime += lingering
                task.snooze()
                await lingeringActor.startTracking(taskId: uuid)
            }

            if snapshot.pendingComplete {
                FlowLogger.task.info("✅ Reconcile: applying completion to '\(task.title)'")
                let lingering = await lingeringActor.stopTracking(taskId: uuid)
                task.totalLingeringTime += lingering
                task.isCompleted = true
            }

            try modelContext.save()
            FlowLogger.local.info("🏠 SwiftData saved after reconcile")

            await SharedTaskStore.shared.clearPendingFlags()
            if snapshot.pendingComplete {
                await SharedTaskStore.shared.clear()
            } else {
                // Refresh snapshot with latest SwiftData values
                await writeSnapshotToStore(for: task)
            }

            // Refresh widget timelines after SwiftData commit
            WidgetCenter.shared.reloadAllTimelines()

        } catch {
            FlowLogger.local.error("💥 Reconcile save error: \(error.localizedDescription)")
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - 🚀 Start Focus Session
    // ─────────────────────────────────────────────────────────

    func startFocusSession(for task: Item) async {
        FlowLogger.task.info("🌐 Starting focus: '\(task.title)' style=\(task.style.rawValue)")

        await lingeringActor.startTracking(taskId: task.id)

        // Persist snapshot so widgets + intents can act without the app
        await writeSnapshotToStore(for: task)
        WidgetCenter.shared.reloadAllTimelines()

        #if os(iOS)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            FlowLogger.liveActivity.warning("⚠️ Live Activities disabled — focus session started locally only")
            return
        }

        let attributes = FlowAttributes(taskId: task.id.uuidString)
        let staleDate  = Calendar.current.date(byAdding: .hour, value: 4, to: .now)

        let initialState = FlowAttributes.ContentState(
            title: task.title,
            snoozeCount: task.snoozeCount,
            moveCount: task.moveCount,
            startDate: task.creationDate,
            emoji: task.emoji,
            style: task.style,
            lastInteractionDate: .now,
            growthLevel: task.growthLevel
        )

        do {
            // End any existing Live Activities before starting a new one
            for activity in Activity<FlowAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: staleDate),
                pushType: nil
            )
            FlowLogger.liveActivity.info("🎉 Live Activity started: id=\(activity.id) style=\(task.style.rawValue)")
        } catch {
            FlowLogger.liveActivity.error("💥 Activity.request failed: \(error.localizedDescription)")
        }
        #endif
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - 💤 Snooze Task
    // ─────────────────────────────────────────────────────────

    func snoozeTask(id: UUID) async {
        FlowLogger.task.info("💤 Snoozing task \(id)…")
        let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == id })
        do {
            guard let task = try modelContext.fetch(descriptor).first else {
                FlowLogger.task.warning("⚠️ snoozeTask: task \(id) not found")
                return
            }

            let lingering = await lingeringActor.stopTracking(taskId: id)
            FlowLogger.task.info("💎 Lingering crystallised: \(lingering)s")
            task.totalLingeringTime += lingering
            task.snooze()
            try modelContext.save()
            FlowLogger.local.info("🏠 Snooze saved to SwiftData: '\(task.title)' count=\(task.snoozeCount)")

            await lingeringActor.startTracking(taskId: id)
            await writeSnapshotToStore(for: task)
            await updateLiveActivity(for: task)

            WidgetCenter.shared.reloadAllTimelines()
            FlowLogger.task.info("🎉 Snooze complete: '\(task.title)' count=\(task.snoozeCount)")
        } catch {
            FlowLogger.local.error("💥 snoozeTask save error: \(error.localizedDescription)")
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - ✅ Complete Task
    // ─────────────────────────────────────────────────────────

    func completeTask(id: UUID) async {
        FlowLogger.task.info("✅ Completing task \(id)…")
        let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == id })
        do {
            guard let task = try modelContext.fetch(descriptor).first else {
                FlowLogger.task.warning("⚠️ completeTask: task \(id) not found")
                return
            }

            let lingering = await lingeringActor.stopTracking(taskId: id)
            FlowLogger.task.info("💎 Final lingering: \(lingering)s total=\(task.totalLingeringTime + lingering)s")
            task.totalLingeringTime += lingering
            task.isCompleted = true
            try modelContext.save()
            FlowLogger.local.info("🏠 Completion saved to SwiftData: '\(task.title)'")

            await endLiveActivity(for: task)
            await SharedTaskStore.shared.clear()
            WidgetCenter.shared.reloadAllTimelines()
            FlowLogger.task.info("🎉 Task completed: '\(task.title)'")
        } catch {
            FlowLogger.local.error("💥 completeTask save error: \(error.localizedDescription)")
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: - 🔒 Private Helpers
    // ─────────────────────────────────────────────────────────

    /// Write (or overwrite) the App Groups snapshot for this task.
    private func writeSnapshotToStore(for task: Item) async {
        let snapshot = ActiveTaskSnapshot(
            taskId: task.id.uuidString,
            title: task.title,
            emoji: task.emoji,
            styleRawValue: task.style.rawValue,
            snoozeCount: task.snoozeCount,
            moveCount: task.moveCount,
            startDate: task.creationDate,
            growthLevel: task.growthLevel,
            lastInteractionDate: .now,
            isCompleted: task.isCompleted
        )
        await SharedTaskStore.shared.save(snapshot)
        FlowLogger.sync.info("🔃 Snapshot written for '\(task.title)'")
    }

    private func updateLiveActivity(for task: Item) async {
        #if os(iOS)
        let staleDate    = Calendar.current.date(byAdding: .hour, value: 4, to: .now)
        let updatedState = FlowAttributes.ContentState(
            title: task.title,
            snoozeCount: task.snoozeCount,
            moveCount: task.moveCount,
            startDate: task.creationDate,
            emoji: task.emoji,
            style: task.style,
            lastInteractionDate: .now,
            growthLevel: task.growthLevel
        )
        for activity in Activity<FlowAttributes>.activities where activity.attributes.taskId == task.id.uuidString {
            await activity.update(ActivityContent(state: updatedState, staleDate: staleDate))
            FlowLogger.liveActivity.info("🏝️ Updated Live Activity \(activity.id) for '\(task.title)'")
        }
        #endif
    }

    private func endLiveActivity(for task: Item) async {
        #if os(iOS)
        for activity in Activity<FlowAttributes>.activities where activity.attributes.taskId == task.id.uuidString {
            await activity.end(nil, dismissalPolicy: .immediate)
            FlowLogger.liveActivity.info("🏝️ Ended Live Activity \(activity.id)")
        }
        #endif
    }
}
