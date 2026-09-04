//
//  AMORMirror.swift
//  Flow — AMOR v5.2.0
//
//  ┌─────────────────────────────────────────────────────────────┐
//  │         THE FULL ILLUMINATION — v5.2.0 "NO DARK ENGINES"    │
//  └─────────────────────────────────────────────────────────────┘
//
//  MISSION: v5.0.0 freed AMORStreakIntelligence from the SwiftData
//  @Model weld — and then the audit found five more engines still
//  welded: BriefingEngine, RhythmEngine, NudgeEngine,
//  WeeklyReviewEngine, and SessionDumpAutomation (3,803 lines of
//  law). None could compile into the live-fire harness, because
//  the @Model macro plugin ships only with Xcode.app. Five versions
//  of AMOR shipped briefing voice, rhythm scores, nudge cadence,
//  weekly reviews, and the daily dump pipeline NOBODY could
//  fixture-test. The blind-spot factory, still running.
//
//  This file completes the demolition: Foundation-only mirrors for
//  every @Model the engines reason over. Each @Model gains a
//  one-line `.snapshot` conversion. The engines keep their law
//  verbatim — only the parameter types change.
//
//  BONUS: computed laws that lived inside @Model classes
//  (CronJobHealth.healthStatus, PracticeStreak.isActive/isDueToday)
//  move into the mirror — Foundation-only, harness-assertable for
//  the first time.
//
//  Architecture: Foundation-only — type-checks with swiftc (CLT SDK).
//

import Foundation

// MARK: - Session Snapshot

/// Model-free mirror of a DailySession's evidence fields.
/// Everything the engines need; nothing SwiftData.
struct AMORSessionSnapshot: Identifiable {
    let id: UUID
    let date: Date
    let title: String
    let notes: String
    let durationMinutes: Int
    let toolsUsed: String       // CSV or JSON array — engines parse
    let skillsLearned: String   // CSV or JSON array — engines parse
    let mood: String            // e.g., "focused", "tired", "energized"
    let completedTasks: Int
    let timestamp: Date

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Cron Job Snapshot

/// Model-free mirror of a CronJobHealth's evidence fields.
/// The health-grade law lives here now — harness-assertable.
struct AMORCronJobSnapshot: Identifiable {
    let id: UUID
    let jobName: String
    let lastRunDate: Date?
    let lastStatus: String      // "success", "failed", "pending"
    let errorMessage: String?
    let schedule: String
    let isEnabled: Bool
    let consecutiveFailures: Int
    let lastSuccessDate: Date?

    /// The health-grade law, verbatim from CronJobHealth (v5.2.0: Foundation-only).
    var healthStatus: String {
        if !isEnabled { return "disabled" }
        if consecutiveFailures >= 3 { return "critical" }
        if consecutiveFailures >= 1 { return "warning" }
        if lastRunDate == nil { return "never_run" }
        return "healthy"
    }

    var statusEmoji: String {
        switch lastStatus {
        case "success": return "✅"
        case "failed": return "❌"
        case "pending": return "⏳"
        default: return "❓"
        }
    }
}

// MARK: - Daily Summary Snapshot

/// Model-free mirror of a DailySummary's evidence fields.
struct AMORDailySummarySnapshot: Identifiable {
    let id: UUID
    let date: Date
    let sessionCount: Int
    let totalFocusMinutes: Int
    let tasksCompleted: Int
    let practicesCompleted: [String]
    let mood: String
    let notes: String
    let timestamp: Date

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
}

// MARK: - Reflection Snapshot

/// Model-free mirror of a ReflectionEntry's evidence fields.
struct AMORReflectionSnapshot: Identifiable {
    let id: UUID
    let date: Date
    let prompt: String
    let response: String
    let theme: String        // "gratitude", "growth", "challenge", "vision", "presence"
    let moodBefore: String
    let moodAfter: String
    let timestamp: Date

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
