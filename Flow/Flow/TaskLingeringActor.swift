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
import OSLog

actor TaskLingeringActor {
    // 🌟 A mystical map of active focus sessions and their start times
    private var activeSessions: [UUID: Date] = [:]

    // 🔮 Recording the moment a task enters the ring of awareness
    func startTracking(taskId: UUID) -> Date {
        let startDate = Date()
        activeSessions[taskId] = startDate
        FlowLogger.task.debug("⏳ Lingering tracking started for task \(taskId, privacy: .public)")
        return startDate
    }

    // 🧪 Calculating the accumulated lingering time since tracking began
    func stopTracking(taskId: UUID) -> TimeInterval {
        guard let startTime = activeSessions.removeValue(forKey: taskId) else {
            FlowLogger.task.warning("🌙 No active lingering session found for task \(taskId, privacy: .public) to stop")
            return 0
        }
        let duration = Date().timeIntervalSince(startTime)
        FlowLogger.task.debug("💎 Lingering measured: \(duration)s for \(taskId, privacy: .public)")
        return duration
    }

    // 🔍 Peek into the current duration without stopping the clock
    func currentLingeringTime(for taskId: UUID) -> TimeInterval {
        guard let startTime = activeSessions[taskId] else {
            FlowLogger.task.debug("🔍 No active lingering session for \(taskId, privacy: .public)")
            return 0
        }
        return Date().timeIntervalSince(startTime)
    }
}
