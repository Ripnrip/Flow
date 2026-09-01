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
}
