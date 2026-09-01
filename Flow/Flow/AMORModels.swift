/**
 * 🧘 AMOR — Daily Operating Rhythm Models
 *
 * "The quiet keeper of daily rhythms, sacred practices, and the health
 * of automated systems. Each session logged is a whisper in the halls
 * of self-knowledge."
 *
 * - AMOR (Automated Memory & Operating Rhythm)
 */

import Foundation
import SwiftData

// MARK: - DailySession

/// A work session logged by the user — captures what was done, tools used, and skills learned.
@Model
nonisolated final class DailySession {
    var id: UUID = UUID()
    var date: Date
    var title: String
    var notes: String
    var durationMinutes: Int
    var toolsUsed: String  // CSV or JSON array
    var skillsLearned: String  // CSV or JSON array
    var mood: String  // e.g., "focused", "tired", "energized"
    var completedTasks: Int
    var timestamp: Date
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    init(
        date: Date = .now,
        title: String,
        notes: String = "",
        durationMinutes: Int,
        toolsUsed: String = "",
        skillsLearned: String = "",
        mood: String = "neutral",
        completedTasks: Int = 0,
        timestamp: Date = .now
    ) {
        self.date = date
        self.title = title
        self.notes = notes
        self.durationMinutes = durationMinutes
        self.toolsUsed = toolsUsed
        self.skillsLearned = skillsLearned
        self.mood = mood
        self.completedTasks = completedTasks
        self.timestamp = timestamp
    }
}

// MARK: - PracticeStreak

/// Tracks streaks for daily practices like Gita reading, gym, meditation.
@Model
nonisolated final class PracticeStreak {
    var id: UUID = UUID()
    var practiceName: String  // e.g., "Gita", "Gym", "Meditation"
    var currentStreak: Int
    var longestStreak: Int
    var lastCompletedDate: Date?
    var totalCompletions: Int
    var goal: String  // e.g., "daily", "3x per week"
    
    /// Whether the streak is currently active (not broken)
    var isActive: Bool {
        guard let last = lastCompletedDate else { return false }
        return Calendar.current.isDateInToday(last) || 
               Calendar.current.isDateInYesterday(last)
    }
    
    /// Whether practice is due today
    var isDueToday: Bool {
        guard let last = lastCompletedDate else { return true }
        return !Calendar.current.isDateInToday(last)
    }

    /// Model-free mirror for the intelligence engine + live-fire harness.
    /// v5.0.0: AMORStreakIntelligence reasons over snapshots, never @Models.
    var snapshot: AMORPracticeSnapshot {
        AMORPracticeSnapshot(
            practiceName: practiceName,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            totalCompletions: totalCompletions,
            lastCompletedDate: lastCompletedDate
        )
    }
    
    init(
        practiceName: String,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastCompletedDate: Date? = nil,
        totalCompletions: Int = 0,
        goal: String = "daily"
    ) {
        self.practiceName = practiceName
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastCompletedDate = lastCompletedDate
        self.totalCompletions = totalCompletions
        self.goal = goal
    }
    
    /// Mark practice as completed today
    func complete(today: Date = .now) {
        guard let last = lastCompletedDate else {
            // First completion
            currentStreak = 1
            lastCompletedDate = today
            totalCompletions = 1
            if longestStreak < 1 { longestStreak = 1 }
            return
        }
        
        let calendar = Calendar.current
        if calendar.isDateInToday(last) {
            // Already completed today
            return
        } else if calendar.isDateInYesterday(last) {
            // Continue streak
            currentStreak += 1
            lastCompletedDate = today
            totalCompletions += 1
            if currentStreak > longestStreak { longestStreak = currentStreak }
        } else {
            // Streak broken
            currentStreak = 1
            lastCompletedDate = today
            totalCompletions += 1
        }
    }
}

// MARK: - CronJobHealth

/// Monitors health status of cron jobs / scheduled tasks.
@Model
nonisolated final class CronJobHealth {
    var id: UUID = UUID()
    var jobName: String
    var lastRunDate: Date?
    var lastStatus: String  // "success", "failed", "pending"
    var errorMessage: String?
    var schedule: String  // cron expression or description
    var isEnabled: Bool
    var consecutiveFailures: Int
    var lastSuccessDate: Date?
    
    var statusEmoji: String {
        switch lastStatus {
        case "success": return "✅"
        case "failed": return "❌"
        case "pending": return "⏳"
        default: return "❓"
        }
    }
    
    var healthStatus: String {
        if !isEnabled { return "disabled" }
        if consecutiveFailures >= 3 { return "critical" }
        if consecutiveFailures >= 1 { return "warning" }
        if lastRunDate == nil { return "never_run" }
        return "healthy"
    }
    
    init(
        jobName: String,
        lastRunDate: Date? = nil,
        lastStatus: String = "pending",
        errorMessage: String? = nil,
        schedule: String = "",
        isEnabled: Bool = true,
        consecutiveFailures: Int = 0,
        lastSuccessDate: Date? = nil
    ) {
        self.jobName = jobName
        self.lastRunDate = lastRunDate
        self.lastStatus = lastStatus
        self.errorMessage = errorMessage
        self.schedule = schedule
        self.isEnabled = isEnabled
        self.consecutiveFailures = consecutiveFailures
        self.lastSuccessDate = lastSuccessDate
    }
    
    /// Record a successful run
    func recordSuccess(date: Date = .now) {
        lastRunDate = date
        lastSuccessDate = date
        lastStatus = "success"
        errorMessage = nil
        consecutiveFailures = 0
    }
    
    /// Record a failed run
    func recordFailure(date: Date = .now, error: String?) {
        lastRunDate = date
        lastStatus = "failed"
        errorMessage = error
        consecutiveFailures += 1
    }
}

// MARK: - DailySummary

/// Aggregated daily summary for AMOR dashboard.
@Model
nonisolated final class DailySummary {
    var id: UUID = UUID()
    var date: Date
    var sessionCount: Int
    var totalFocusMinutes: Int
    var tasksCompleted: Int
    var practicesCompleted: [String]  // Names of practices done today
    var mood: String
    var notes: String
    var timestamp: Date
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
    
    init(
        date: Date = .now,
        sessionCount: Int = 0,
        totalFocusMinutes: Int = 0,
        tasksCompleted: Int = 0,
        practicesCompleted: [String] = [],
        mood: String = "neutral",
        notes: String = "",
        timestamp: Date = .now
    ) {
        self.date = date
        self.sessionCount = sessionCount
        self.totalFocusMinutes = totalFocusMinutes
        self.tasksCompleted = tasksCompleted
        self.practicesCompleted = practicesCompleted
        self.mood = mood
        self.notes = notes
        self.timestamp = timestamp
    }
}

// MARK: - SecondBrainEntry

/// Links to second brain / Obsidian notes for daily summaries.
@Model
nonisolated final class SecondBrainEntry {
    var id: UUID = UUID()
    var date: Date
    var notePath: String  // Path in Obsidian vault
    var summary: String
    var tags: String  // CSV of tags
    var timestamp: Date
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    init(
        date: Date = .now,
        notePath: String,
        summary: String,
        tags: String = "",
        timestamp: Date = .now
    ) {
        self.date = date
        self.notePath = notePath
        self.summary = summary
        self.tags = tags
        self.timestamp = timestamp
    }
}