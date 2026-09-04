//
//  AMORPracticeSnapshot.swift
//  Flow — AMOR v5.0.0
//
//  ┌─────────────────────────────────────────────────────────────┐
//  │        PRACTICE SNAPSHOT — v5.0.0 "MORTAL STREAKS"          │
//  └─────────────────────────────────────────────────────────────┘
//
//  MISSION: AMORStreakIntelligence was welded to the SwiftData
//  @Model PracticeStreak — so it could never be compiled into the
//  live-fire harness (CLT SDK, no app target). Five versions shipped
//  with a health-score law nobody could fixture-test, and the blind
//  spot lived: a 95-morning Gita devotee rendered as a 🌱 49/100
//  seedling because never-started practices dragged the denominator.
//
//  This mirror is Foundation-only. The intelligence engine reasons
//  over snapshots; the @Model gains a one-line computed conversion.
//  The harness compiles the engine directly — the blind-spot factory
//  is demolished.
//
//  Architecture: Foundation-only — type-checks with swiftc (CLT SDK).
//

import Foundation

/// Model-free mirror of a PracticeStreak's evidence fields.
/// Everything the streak intelligence needs; nothing SwiftData.
struct AMORPracticeSnapshot {
    let practiceName: String
    let currentStreak: Int
    let longestStreak: Int
    let totalCompletions: Int
    let lastCompletedDate: Date?
    /// v5.2.0: engines read the goal law ("daily", "3x per week").
    /// Default preserves the 5-param fixtures across the harness.
    var goal: String = "daily"

    /// Whether the streak is currently active (not broken) — verbatim @Model law.
    var isActive: Bool {
        guard let last = lastCompletedDate else { return false }
        return Calendar.current.isDateInToday(last) ||
               Calendar.current.isDateInYesterday(last)
    }

    /// Whether practice is due today — verbatim @Model law.
    var isDueToday: Bool {
        guard let last = lastCompletedDate else { return true }
        return !Calendar.current.isDateInToday(last)
    }
}
