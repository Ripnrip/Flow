/**
 * 🏠 AMORWidgetBuilder — Snapshot Builder (Main App Only)
 *
 * "The artisan who shapes raw SwiftData into the compact essence
 *  that travels across process boundaries to the widget realm."
 *
 * v3.6.0 — AMOR Home Screen Widget Suite
 *
 * This file lives in Flow/Flow/ and is compiled ONLY by the main app target.
 * It references SwiftData @Model types (DailySession, PracticeStreak, CronJobHealth)
 * that the widget extension cannot access. The widget reads only the finished
 * AMORWidgetSnapshot struct via AMORWidgetStore.readSnapshot().
 */

import Foundation
import SwiftData

// MARK: - AMORWidgetBuilder

enum AMORWidgetBuilder {

    /// Build a snapshot from SwiftData model objects and write it to App Groups.
    /// Call this from the main app on foreground / data changes.
    @MainActor static func syncSnapshot(
        sessions: [DailySession],
        practices: [PracticeStreak],
        cronJobs: [CronJobHealth]
    ) {
        let snapshot = buildSnapshot(
            sessions: sessions,
            practices: practices,
            cronJobs: cronJobs
        )
        AMORWidgetStore.writeSnapshot(snapshot)
    }

    /// Build a snapshot from SwiftData model objects.
    @MainActor static func buildSnapshot(
        sessions: [DailySession],
        practices: [PracticeStreak],
        cronJobs: [CronJobHealth]
    ) -> AMORWidgetSnapshot {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)

        // Today's sessions
        let todaySessions = sessions.filter { $0.date >= startOfToday }
        let totalMinutes = todaySessions.reduce(0) { $0 + $1.durationMinutes }

        // Practices
        let completedToday = practices.filter { !$0.isDueToday }
        let dueToday = practices.filter { $0.isDueToday }

        let streakSnapshots = practices.map { p in
            StreakSnapshot(
                name: p.practiceName,
                currentStreak: p.currentStreak,
                longestStreak: p.longestStreak,
                isCompletedToday: !p.isDueToday,
                isDueToday: p.isDueToday
            )
        }.sorted { $0.currentStreak > $1.currentStreak }

        // Cron health
        let healthy = cronJobs.filter { $0.healthStatus == "healthy" }.count
        let failed = cronJobs.filter { $0.lastStatus == "failed" }.count

        // Phase determination
        let hour = calendar.component(.hour, from: .now)
        let phase: String
        let briefingTitle: String
        let briefingSubtitle: String

        switch hour {
        case 5..<10:
            phase = "morning"
            briefingTitle = "Good morning"
            let due = dueToday.count
            briefingSubtitle = due > 0 ? "\(due) practice\(due > 1 ? "s" : "") awaiting" : "All practices complete"
        case 10..<14:
            phase = "midday"
            briefingTitle = "\(todaySessions.count) session\(todaySessions.count == 1 ? "" : "s") logged"
            let mins = totalMinutes
            briefingSubtitle = mins > 0 ? "\(mins / 60)h \(mins % 60)m focus time" : "Ready to focus"
        case 14..<18:
            phase = "afternoon"
            briefingTitle = "Afternoon review"
            briefingSubtitle = "\(completedToday.count)/\(practices.count) practices done"
        case 18..<22:
            phase = "evening"
            briefingTitle = "Evening reflection"
            let total = totalMinutes
            briefingSubtitle = total > 0 ? "\(total / 60)h \(total % 60)m focused today" : "How was your day?"
        default:
            phase = "night"
            briefingTitle = "Resting"
            briefingSubtitle = "Tomorrow awaits"
        }

        // Day string
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE, MMM d"
        let dayString = dayFormatter.string(from: .now)

        return AMORWidgetSnapshot(
            date: .now,
            dayString: dayString,
            sessionCount: todaySessions.count,
            totalFocusMinutes: totalMinutes,
            practicesCompleted: completedToday.count,
            practicesDue: dueToday.count,
            activeStreaks: Array(streakSnapshots.prefix(4)),
            cronHealthy: healthy,
            cronFailed: failed,
            cronTotal: cronJobs.count,
            briefingTitle: briefingTitle,
            briefingSubtitle: briefingSubtitle,
            phase: phase
        )
    }
}
