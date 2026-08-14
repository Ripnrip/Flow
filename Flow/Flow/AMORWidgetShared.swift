/**
 * 🏠 AMORWidgetShared — Widget Snapshot Bridge
 *
 * "The bridge between the sanctuary within and the world without.
 *  AMOR's daily rhythm, compressed into a glanceable snapshot that
 *  lives on the Home Screen, Lock Screen, and StandBy — always present,
 *  never intrusive."
 *
 * v3.6.0 — AMOR Home Screen Widget Suite
 *
 * Architecture:
 *   • AMORWidgetSnapshot — Codable, Sendable struct written to App Groups
 *   • AMORWidgetStore — nonisolated actor for cross-process read/write
 *   • The main app writes a snapshot on foreground + data changes
 *   • Widgets read the snapshot via timeline provider (no SwiftData needed)
 *
 * App Group: group.com.binarybros.Flow (shared with SharedTaskStore)
 */

import Foundation

// MARK: - AMORWidgetSnapshot

/// A compact, Codable snapshot of AMOR's daily state for widget rendering.
/// Designed to fit comfortably in UserDefaults (~1KB).
struct AMORWidgetSnapshot: Codable, Sendable, Hashable {
    let date: Date
    let dayString: String  // "Tuesday, Aug 11"

    // Sessions today
    let sessionCount: Int
    let totalFocusMinutes: Int

    // Practices / streaks
    let practicesCompleted: Int
    let practicesDue: Int
    let activeStreaks: [StreakSnapshot]

    // Cron health
    let cronHealthy: Int
    let cronFailed: Int
    let cronTotal: Int

    // Briefing preview
    let briefingTitle: String
    let briefingSubtitle: String

    // Phase (morning/afternoon/evening/night)
    let phase: String

    var cronHealthPercentage: Double {
        guard cronTotal > 0 else { return 1.0 }
        return Double(cronHealthy) / Double(cronTotal)
    }

    var hasFailedCrons: Bool {
        cronFailed > 0
    }

    var allPracticesDone: Bool {
        practicesDue == 0 && practicesCompleted > 0
    }
}

// MARK: - StreakSnapshot

/// A single practice streak for widget display.
struct StreakSnapshot: Codable, Sendable, Hashable, Identifiable {
    var id: String { name }
    let name: String
    let currentStreak: Int
    let longestStreak: Int
    let isCompletedToday: Bool
    let isDueToday: Bool

    var displayIcon: String {
        switch name.lowercased() {
        case let n where n.contains("gita"): return "book.fill"
        case let n where n.contains("gym") || n.contains("workout") || n.contains("fitness"): return "figure.strengthtraining.functional"
        case let n where n.contains("medit"): return "figure.mind.and.body"
        case let n where n.contains("walk") || n.contains("run"): return "figure.run"
        case let n where n.contains("read"): return "text.book.closed.fill"
        default: return "flame.fill"
        }
    }

    var streakColor: String {
        if isCompletedToday { return "sageGreen" }
        if currentStreak >= 7 { return "dawnOrange" }
        if currentStreak >= 3 { return "mutedGold" }
        return "softClay"
    }
}

// MARK: - AMORWidgetStore

/// Cross-process bridge using App Groups UserDefaults.
/// The main app writes snapshots; widgets read them in timeline providers.
enum AMORWidgetStore {

    static let snapshotKey = "amor.widgetSnapshot"
    static let lastUpdateKey = "amor.widgetLastUpdate"

    /// Write a snapshot to App Groups UserDefaults.
    /// Called from the main app on foreground / data change.
    static func writeSnapshot(_ snapshot: AMORWidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: kFlowAppGroup) else { return }
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: snapshotKey)
            defaults.set(Date(), forKey: lastUpdateKey)
        }
    }

    /// Read the latest snapshot. Callable from widget extension (nonisolated).
    static func readSnapshot() -> AMORWidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: kFlowAppGroup),
              let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(AMORWidgetSnapshot.self, from: data)
    }

    /// Read the last update timestamp (for staleness display).
    static func lastUpdateTime() -> Date? {
        UserDefaults(suiteName: kFlowAppGroup)?.object(forKey: lastUpdateKey) as? Date
    }

}

// MARK: - Pending Action Queue (App Groups Bridge)
// v3.9.0 — moved from AMORAppIntents.swift so the WIDGET EXTENSION target
// (which compiles this file via the exception set) can enqueue actions from
// interactive widget buttons without a SwiftData ModelContext.

/// Represents an action queued by an AppIntent or an interactive widget
/// button for later reconciliation. Stored in App Groups UserDefaults so
/// intents can write without a ModelContext.
struct AMORPendingAction: Codable, Sendable, Identifiable {
    enum ActionType: String, Codable, Sendable {
        case logSession
        case completePractice
        case setMood
    }

    let id: UUID
    let type: ActionType
    let timestamp: Date
    let parameters: [String: String]

    init(type: ActionType, parameters: [String: String] = [:]) {
        self.id = UUID()
        self.type = type
        self.timestamp = Date()
        self.parameters = parameters
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, timestamp, parameters
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.type = try c.decode(ActionType.self, forKey: .type)
        self.timestamp = try c.decode(Date.self, forKey: .timestamp)
        self.parameters = try c.decodeIfPresent([String: String].self, forKey: .parameters) ?? [:]
    }
}

/// Reads and writes the pending action queue via App Groups UserDefaults.
/// AppIntents AND interactive widget buttons enqueue actions; FlowApp
/// reconciles them into SwiftData on every foreground transition.
enum AMORPendingActionStore {

    static let queueKey = "amor.pendingActions"

    /// Enqueue a new pending action.
    static func enqueue(_ action: AMORPendingAction) {
        guard let defaults = UserDefaults(suiteName: kFlowAppGroup) else { return }
        var queue = readAll()
        queue.append(action)
        // Keep only the last 50 actions to prevent unbounded growth
        if queue.count > 50 {
            queue = Array(queue.suffix(50))
        }
        if let data = try? JSONEncoder().encode(queue) {
            defaults.set(data, forKey: queueKey)
        }
    }

    /// Read all pending actions (nonisolated — safe from any context).
    static func readAll() -> [AMORPendingAction] {
        guard let defaults = UserDefaults(suiteName: kFlowAppGroup),
              let data = defaults.data(forKey: queueKey) else { return [] }
        return (try? JSONDecoder().decode([AMORPendingAction].self, from: data)) ?? []
    }

    /// Clear the action queue after reconciliation.
    static func clear() {
        UserDefaults(suiteName: kFlowAppGroup)?.removeObject(forKey: queueKey)
    }

    /// Remove specific action IDs after successful reconciliation.
    static func remove(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let remaining = readAll().filter { !ids.contains($0.id) }
        if let data = try? JSONEncoder().encode(remaining) {
            UserDefaults(suiteName: kFlowAppGroup)?.set(data, forKey: queueKey)
        }
    }
}

// MARK: - Optimistic Snapshot Updates (v3.9.0)
// Interactive widget buttons need INSTANT visual feedback — the user can't
// wait for the app to open and reconcile. These helpers rewrite the App
// Groups snapshot immediately; AMORIntentReconciler commits the real
// SwiftData change on next foreground, and syncAMORWidget() overwrites the
// optimistic state with ground truth. If the user never opens the app, the
// snapshot may show a stale "completed" state until the next app foreground
// — a documented, accepted tradeoff of the pending-action queue pattern.

extension AMORWidgetSnapshot {

    /// Returns a new snapshot with the named practice marked complete.
    func completingPractice(named name: String) -> AMORWidgetSnapshot {
        var alreadyDone = false
        let streaks = activeStreaks.map { streak -> StreakSnapshot in
            guard streak.name == name else { return streak }
            if streak.isCompletedToday {
                alreadyDone = true
                return streak
            }
            return StreakSnapshot(
                name: streak.name,
                currentStreak: streak.currentStreak + 1,
                longestStreak: max(streak.longestStreak, streak.currentStreak + 1),
                isCompletedToday: true,
                isDueToday: false
            )
        }
        guard !alreadyDone else { return self }
        return AMORWidgetSnapshot(
            date: date,
            dayString: dayString,
            sessionCount: sessionCount,
            totalFocusMinutes: totalFocusMinutes,
            practicesCompleted: practicesCompleted + 1,
            practicesDue: max(0, practicesDue - 1),
            activeStreaks: streaks,
            cronHealthy: cronHealthy,
            cronFailed: cronFailed,
            cronTotal: cronTotal,
            briefingTitle: briefingTitle,
            briefingSubtitle: briefingSubtitle,
            phase: phase
        )
    }

    /// Returns a new snapshot with a quick session logged.
    func loggingQuickSession(title: String, minutes: Int) -> AMORWidgetSnapshot {
        AMORWidgetSnapshot(
            date: date,
            dayString: dayString,
            sessionCount: sessionCount + 1,
            totalFocusMinutes: totalFocusMinutes + minutes,
            practicesCompleted: practicesCompleted,
            practicesDue: practicesDue,
            activeStreaks: activeStreaks,
            cronHealthy: cronHealthy,
            cronFailed: cronFailed,
            cronTotal: cronTotal,
            briefingTitle: "\(sessionCount + 1) sessions logged",
            briefingSubtitle: briefingSubtitle,
            phase: phase
        )
    }
}
