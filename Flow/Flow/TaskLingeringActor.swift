/**
 * 🎭 The TaskLingeringActor - The Timekeeper of Shadows
 *
 * "An Actor that dwells in the background, measuring the passage of time
 * for tasks that linger in the user's awareness. It is the silent pulse
 * of our temporal mechanics."
 *
 * - The Celestial Chronos Virtuoso
 */

import Foundation

actor TaskLingeringActor {
    // 🌟 A mystical map of active focus sessions and their start times
    private var activeSessions: [UUID: Date] = [:]

    // 🔮 Recording the moment a task enters the ring of awareness
    func startTracking(taskId: UUID) {
        activeSessions[taskId] = .now
        print("⏳ ✨ TRACKING AWAKENS for task \(taskId) at \(Date())")
    }

    // 🧪 Calculating the accumulated lingering time since tracking began
    func stopTracking(taskId: UUID) -> TimeInterval {
        guard let startTime = activeSessions.removeValue(forKey: taskId) else {
            print("🌙 ⚠️ No active session found for task \(taskId) to stop.")
            return 0
        }
        let duration = Date().timeIntervalSince(startTime)
        print("💎 ✨ TRACKING CRYSTALLIZED: \(duration)s for \(taskId)")
        return duration
    }

    // 🔍 Peek into the current duration without stopping the clock
    func currentLingeringTime(for taskId: UUID) -> TimeInterval {
        guard let startTime = activeSessions[taskId] else {
            print("🔍 🧙‍♂️ Peering into void: No active session for \(taskId)")
            return 0
        }
        return Date().timeIntervalSince(startTime)
    }
}
