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
