/**
 * 🎭 The TaskService - The Cosmic Orchestrator of Action
 *
 * "An Actor that stands outside of time, managing the flow of tasks
 * with thread-safe precision. It is the guardian of the task's state."
 *
 * - The Celestial Task Maestro
 */

import ActivityKit
import SwiftData
import SwiftUI
import Observation
import AppIntents

@MainActor
@Observable
class TaskService {
    @ObservationIgnored
    private var modelContext: ModelContext

    // ⏳ The timekeeper of shadows
    @ObservationIgnored
    private let lingeringActor = TaskLingeringActor()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        print("🎭 ✨ TASK SERVICE INITIALIZED!")
    }

    // New Function: Restores or starts an active Live Activity session
    func restoreActiveFocusSession() async {
#if os(iOS)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("🌩️ ⚠️ Live Activities are not enabled for this realm.")
            return
        }

        // 1. Check if any activity is already running from a previous launch
        let runningActivities = Activity<FlowAttributes>.activities
        if !runningActivities.isEmpty {
            print("🎉 ✨ Found \(runningActivities.count) existing Live Activities. Assuming continuity.")
            // Also need to ensure background time tracking is restarted for the tracked item
            if let firstActivity = runningActivities.first {
                let taskId = firstActivity.attributes.taskId
                if let uuid = UUID(uuidString: taskId) {
                    await lingeringActor.startTracking(taskId: uuid)
                }
            }
            return
        }
#endif

        // 2. If no activities are running, find an uncompleted task to focus on (the most recent one)
        do {
            let descriptor = FetchDescriptor<Item>(
                predicate: #Predicate { $0.isCompleted == false },
                sortBy: [SortDescriptor(\Item.timestamp, order: .reverse)]
            )
            
            if let taskToFocus = try modelContext.fetch(descriptor).first {
                print("🌟 🔄 Restoring focus on task: [\(taskToFocus.title)]")
                // Start a new Live Activity for this task
                await startFocusSession(for: taskToFocus)
            } else {
                print("🌙 ⚠️ No uncompleted tasks found to restore focus session.")
            }
        } catch {
            print("💥 😭 Error restoring focus session: \(error.localizedDescription)")
        }
    }

    // 🔮 Starting a focus session with modern concurrency
    func startFocusSession(for task: Item) async {
        print("🌐 ✨ FOCUS RITUAL AWAKENS via TaskService for [\(task.title)] in style [\(task.style.rawValue)]")
        print("🔍 🧙‍♂️ Peering into mystical variables: TaskID=\(task.id), Style=\(task.style.rawValue)")

        // ⏳ Start background tracking
        print("🎪 📦 Starting cosmic time-tracking for \(task.title)...")
        await lingeringActor.startTracking(taskId: task.id)

#if os(iOS)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("🌩️ ⚠️ Gentle reminder: Live Activities are not enabled for this realm.")
            return
        }

        let attributes = FlowAttributes(taskId: task.id.uuidString)
        
        let staleDate = Calendar.current.date(byAdding: .hour, value: 4, to: Date())!

        let initialState = FlowAttributes.ContentState(
            title: task.title,
            snoozeCount: task.snoozeCount,
            moveCount: task.moveCount,
            startDate: task.creationDate,
            emoji: task.emoji,
            style: task.style,
            lastInteractionDate: Date.now,
            growthLevel: task.growthLevel
        )

        do {
            // Close any existing activities before starting a new one (to ensure only one is active)
            for activity in Activity<FlowAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            
            print("✨ 🎊 PORTAL TRANSFORMATION COMMENCES! Requesting Live Activity...")
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: staleDate), // <--- FIX APPLIED HERE
                pushType: nil
            )
            print("🎉 ✨ LIVE ACTIVITY MASTERPIECE STARTED! Activity ID: \(activity.id), Style: \(task.style.rawValue)")
        } catch {
            print("💥 😭 FOCUS RITUAL FAILED! The digital muses are taking a brief intermission: \(error.localizedDescription)")
        }
#endif
    }

    // 🌙 The Snooze Ritual - Thread-safe state update
    func snoozeTask(id: UUID) async {
        print("🌙 ✨ SNOOZE RITUAL AWAKENS! Searching for task \(id)...")
        let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == id })
        do {
            if let task = try modelContext.fetch(descriptor).first {
                print("🔍 🧙‍♂️ Found task: \(task.title). Current snooze count: \(task.snoozeCount)")

                let lingering = await lingeringActor.stopTracking(taskId: id)
                print("💎 Crystallized wisdom: \(lingering) seconds of lingering time gathered.")
                task.totalLingeringTime += lingering

                print("🔄 Enchanted alchemy: Incrementing snooze count for \(task.title)...")
                task.snooze()
                try modelContext.save()

                print("🌐 ✨ Restarting cosmic tracking for snoozed task...")
                await lingeringActor.startTracking(taskId: id)

                print("🎨 Syncing state with the peripheral islands...")
                await updateLiveActivity(for: task)
                print("🎉 ✨ SNOOZE MASTERPIECE COMPLETE! Style: \(task.style.rawValue)")
            } else {
                print("🌙 ⚠️ Gentle reminder: Task \(id) not found in the mystical database.")
            }
        } catch {
            print("🌩️ ⚠️ SNOOZE TEMPORARILY HALTED! A storm in the database: \(error.localizedDescription)")
        }
    }

    // ✅ The Done Ritual
    func completeTask(id: UUID) async {
        print("✅ ✨ COMPLETION RITUAL AWAKENS for task \(id)!")
        let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == id })
        do {
            if let task = try modelContext.fetch(descriptor).first {
                print("🌟 Grand attempt at digital magic: Completing \(task.title)...")

                let lingering = await lingeringActor.stopTracking(taskId: id)
                print("💎 Final wisdom crystallization: \(lingering) seconds added to total.")
                task.totalLingeringTime += lingering

                task.isCompleted = true
                try modelContext.save()

                print("🛑 Ending the Live Activity session...")
                await endLiveActivity(for: task)
                print("🎉 ✨ TASK COMPLETION MASTERPIECE COMPLETE! Great job, seeker of wisdom!")
            }
        } catch {
            print("🌩️ ⚠️ COMPLETION TEMPORARILY HALTED! Our digital muses are confused: \(error.localizedDescription)")
        }
    }

    // 🎨 Syncing the state with the Live Activity surface
    private func updateLiveActivity(for task: Item) async {
#if os(iOS)
        // If we update, we should also push out the stale date slightly to maintain relevance
        let staleDate = Calendar.current.date(byAdding: .hour, value: 4, to: Date())!

        for activity in Activity<FlowAttributes>.activities where activity.attributes.taskId == task.id.uuidString {
            let updatedState = FlowAttributes.ContentState(
                title: task.title,
                snoozeCount: task.snoozeCount,
                moveCount: task.moveCount,
                startDate: task.creationDate,
                emoji: task.emoji,
                style: task.style,
                lastInteractionDate: Date.now,
                growthLevel: task.growthLevel
            )
            await activity.update(ActivityContent(state: updatedState, staleDate: staleDate)) // <--- FIX APPLIED HERE
        }
#endif
    }

    private func endLiveActivity(for task: Item) async {
#if os(iOS)
        for activity in Activity<FlowAttributes>.activities where activity.attributes.taskId == task.id.uuidString {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
#endif
    }
}
