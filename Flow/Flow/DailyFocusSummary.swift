/**
 * 📊 DailyFocusSummary — The Ledger of the Day
 *
 * "A crystallized snapshot of today's focus deeds:
 *  time spent, sessions fought, tasks conquered, and the
 *  sacred streak that measures your returning flame."
 *
 * - The Cosmic Accountant of Attention
 */

import Foundation

// MARK: - 📊 Focus Ledger

/// A lightweight, cross-process summary of today's focus performance.
/// Computed from SwiftData in the main app and mirrored to App Groups
/// so widgets and Live Activities can display it without launching Flow.
struct DailyFocusSummary: Sendable, Hashable {

    /// Total seconds focused today (accumulated `totalLingeringTime` of completed/active tasks).
    var totalFocusSeconds: TimeInterval

    /// Number of distinct focus sessions started today.
    var sessionsCount: Int

    /// Number of snoozes invoked today.
    var snoozes: Int

    /// Number of tasks completed today.
    var completed: Int

    /// Current consecutive days with at least one focus session.
    var streakDays: Int

    /// The date this summary was generated.
    var generatedAt: Date


    nonisolated init(
        totalFocusSeconds: TimeInterval = 0,
        sessionsCount: Int = 0,
        snoozes: Int = 0,
        completed: Int = 0,
        streakDays: Int = 0,
        generatedAt: Date = .now
    ) {
        self.totalFocusSeconds = totalFocusSeconds
        self.sessionsCount = sessionsCount
        self.snoozes = snoozes
        self.completed = completed
        self.streakDays = streakDays
        self.generatedAt = generatedAt
    }

    /// A human-friendly formatted duration like "2h 14m".
    nonisolated var formattedDuration: String {
        let total = Int(totalFocusSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Empty summary used for placeholders and first launch.
    nonisolated static var empty: DailyFocusSummary { DailyFocusSummary() }
}

// MARK: - 🧮 Explicit Codable Conformance

/// Explicit, nonisolated Codable implementation keeps the conformance usable
/// from actor-isolated contexts under Swift 6 strict concurrency.
extension DailyFocusSummary: Codable {

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.totalFocusSeconds = try container.decode(TimeInterval.self, forKey: .totalFocusSeconds)
        self.sessionsCount = try container.decode(Int.self, forKey: .sessionsCount)
        self.snoozes = try container.decode(Int.self, forKey: .snoozes)
        self.completed = try container.decode(Int.self, forKey: .completed)
        self.streakDays = try container.decode(Int.self, forKey: .streakDays)
        self.generatedAt = try container.decode(Date.self, forKey: .generatedAt)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(totalFocusSeconds, forKey: .totalFocusSeconds)
        try container.encode(sessionsCount, forKey: .sessionsCount)
        try container.encode(snoozes, forKey: .snoozes)
        try container.encode(completed, forKey: .completed)
        try container.encode(streakDays, forKey: .streakDays)
        try container.encode(generatedAt, forKey: .generatedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case totalFocusSeconds, sessionsCount, snoozes, completed, streakDays, generatedAt
    }
}
