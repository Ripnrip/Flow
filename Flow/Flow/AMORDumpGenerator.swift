/**
 * 🧘 AMORDumpGenerator — Session-Dump Automation Engine
 *
 * "The scribe of the digital temple. Where moments crystallize into
 * narratives, and the chaos of raw experience finds its reflection
 * in structured prose. This is the bridge between doing and being."
 *
 * Generates formatted session dumps for:
 * - Daily summaries (for second brain / Obsidian)
 * - Weekly reviews (for reflection and planning)
 * - Progress exports (for external analysis)
 *
 * All output is designed to be copy-pasted directly into Obsidian,
 * Notion, or any markdown-based second brain system.
 */

import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - DumpFormat

enum DumpFormat: String, CaseIterable {
    case dailyMarkdown = "Daily (Markdown)"
    case weeklyMarkdown = "Weekly (Markdown)"
    case jsonExport = "JSON Export"
    case csvExport = "CSV Export"
}

// MARK: - AMORDumpGenerator

/// Generates session dumps and exports for second brain integration.
/// Uses the UserDefaults-direct pattern for independent, testable operation.
final class AMORDumpGenerator {

    // MARK: - Daily Dump

    /// Generate a formatted daily session dump in Markdown.
    func generateDailyDump(
        date: Date = .now,
        sessions: [DailySession],
        practices: [PracticeStreak],
        cronJobs: [CronJobHealth],
        mood: String = "neutral",
        reflections: String = ""
    ) -> String {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        let daySessions = sessions.filter { $0.date >= startOfDay && $0.date < tomorrow }
        let totalMinutes = daySessions.reduce(0) { $0 + $1.durationMinutes }
        let totalTasks = daySessions.reduce(0) { $0 + $1.completedTasks }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: date)

        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy"
        let prettyDate = dateFormatter.string(from: date)

        var output = ""

        // Header
        output += "# AMOR Daily Dump — \(prettyDate)\n\n"
        output += "**Date:** \(dateStr)\n"
        output += "**Sessions:** \(daySessions.count)\n"
        output += "**Focus Time:** \(formatDuration(totalMinutes))\n"
        output += "**Tasks Completed:** \(totalTasks)\n"
        output += "**Mood:** \(mood.capitalized)\n\n"

        // Sessions
        if daySessions.isEmpty {
            output += "## Sessions\n\n*No sessions logged today.*\n\n"
        } else {
            output += "## Sessions\n\n"
            for session in daySessions.sorted(by: { $0.timestamp < $1.timestamp }) {
                output += "### \(session.title)\n"
                output += "- **Duration:** \(formatDuration(session.durationMinutes))\n"
                output += "- **Mood:** \(session.mood.capitalized)\n"
                output += "- **Tasks Completed:** \(session.completedTasks)\n"
                if !session.toolsUsed.isEmpty {
                    output += "- **Tools:** \(formatList(session.toolsUsed))\n"
                }
                if !session.skillsLearned.isEmpty {
                    output += "- **Skills:** \(formatList(session.skillsLearned))\n"
                }
                if !session.notes.isEmpty {
                    output += "- **Notes:** \(session.notes)\n"
                }
                output += "\n"
            }
        }

        // Practices
        let todayPractices = practices.filter { !$0.isDueToday }
        if !practices.isEmpty {
            output += "## Practices\n\n"
            output += "| Practice | Status | Streak | Goal |\n"
            output += "|----------|--------|--------|------|\n"
            for practice in practices {
                let status = todayPractices.contains(where: { $0.id == practice.id }) ? "✅" : "⬜"
                output += "| \(practice.practiceName) | \(status) | \(practice.currentStreak) days | \(practice.goal) |\n"
            }
            output += "\n"
        }

        // Cron Health
        if !cronJobs.isEmpty {
            let healthyCount = cronJobs.filter { $0.healthStatus == "healthy" }.count
            output += "## System Health\n\n"
            output += "**Health:** \(healthyCount)/\(cronJobs.count) jobs healthy\n\n"
            let unhealthy = cronJobs.filter { $0.healthStatus != "healthy" && $0.isEnabled }
            if !unhealthy.isEmpty {
                output += "| Job | Status | Last Issue |\n"
                output += "|-----|--------|------------|\n"
                for job in unhealthy {
                    let issue = job.errorMessage ?? "N/A"
                    output += "| \(job.jobName) | \(job.statusEmoji) \(job.healthStatus) | \(issue) |\n"
                }
                output += "\n"
            }
        }

        // Reflections
        if !reflections.isEmpty {
            output += "## Reflections\n\n\(reflections)\n\n"
        }

        // Tags
        output += "---\n\n"
        output += "**Tags:** #amor #daily-dump #\(dateStr)\n"

        return output
    }

    // MARK: - Weekly Dump

    /// Generate a formatted weekly review dump in Markdown.
    func generateWeeklyDump(
        sessions: [DailySession],
        practices: [PracticeStreak],
        cronJobs: [CronJobHealth],
        tracker: AMORProgressTracker
    ) -> String {
        let insights = tracker.computeWeeklyInsights(
            sessions: sessions,
            practices: practices,
            cronJobs: cronJobs,
            weeksAgo: 0
        )

        var output = ""

        // Header
        output += "# AMOR Weekly Review — \(insights.formattedWeekRange)\n\n"

        // Summary Stats
        output += "## Weekly Summary\n\n"
        output += "| Metric | Value |\n"
        output += "|--------|-------|\n"
        output += "| Total Sessions | \(insights.totalSessions) |\n"
        output += "| Focus Time | \(formatDuration(insights.totalFocusMinutes)) |\n"
        output += "| Tasks Completed | \(insights.totalTasksCompleted) |\n"
        output += "| Avg Session Length | \(formatDuration(insights.avgSessionMinutes)) |\n"
        output += "| Practices Completed | \(insights.practicesCompleted) |\n"
        output += "| Longest Practice Streak | \(insights.longestStreak) days |\n"
        output += "| System Health | \(String(format: "%.0f%%", insights.cronHealthPercentage)) |\n"
        output += "| Trend | \(insights.focusTrend.rawValue) \(insights.focusTrend.label) |\n\n"

        // Sessions Per Day
        if !insights.sessionsPerDay.isEmpty {
            output += "## Daily Breakdown\n\n"
            output += "| Day | Sessions | Focus Time |\n"
            output += "|-----|----------|------------|\n"
            for day in insights.sessionsPerDay {
                output += "| \(day.dayName) | \(day.count) | \(formatDuration(day.minutes)) |\n"
            }
            if let mpd = insights.mostProductiveDay {
                output += "\n**Most productive day:** \(mpd)\n\n"
            }
        }

        // Top Tools
        if !insights.topTools.isEmpty {
            output += "## Top Tools\n\n"
            for (index, tool) in insights.topTools.enumerated() {
                output += "\(index + 1). **\(tool.tool)** — \(tool.count) sessions\n"
            }
            output += "\n"
        }

        // Top Skills
        if !insights.topSkills.isEmpty {
            output += "## Skills Developed\n\n"
            for (index, skill) in insights.topSkills.enumerated() {
                output += "\(index + 1). **\(skill.skill)** — \(skill.count) sessions\n"
            }
            output += "\n"
        }

        // Mood Distribution
        if !insights.moodDistribution.isEmpty {
            output += "## Mood Distribution\n\n"
            for mood in insights.moodDistribution {
                let barLength = max(1, mood.count * 5)
                let bar = String(repeating: "█", count: barLength)
                output += "- **\(mood.mood.capitalized):** \(bar) \(mood.count)\n"
            }
            output += "\n"
        }

        // Practices Status
        if !practices.isEmpty {
            output += "## Practice Streaks\n\n"
            for practice in practices {
                let flame = practice.isActive ? "🔥" : "💤"
                output += "- \(flame) **\(practice.practiceName)** — Current: \(practice.currentStreak), Longest: \(practice.longestStreak), Total: \(practice.totalCompletions)\n"
            }
            output += "\n"
        }

        // Tags
        output += "---\n\n"
        output += "**Tags:** #amor #weekly-review #progress\n"

        return output
    }

    // MARK: - JSON Export

    /// Generate a JSON export of all sessions for external analysis.
    func generateJSONExport(sessions: [DailySession]) -> String? {
        let exportData = sessions.map { session -> [String: Any] in
            return [
                "id": session.id.uuidString,
                "date": ISO8601DateFormatter().string(from: session.date),
                "title": session.title,
                "notes": session.notes,
                "duration_minutes": session.durationMinutes,
                "tools_used": session.toolsUsed,
                "skills_learned": session.skillsLearned,
                "mood": session.mood,
                "completed_tasks": session.completedTasks,
                "timestamp": ISO8601DateFormatter().string(from: session.timestamp)
            ]
        }

        let meta: [String: Any] = [
            "app": "AMOR",
            "version": "2.0.0",
            "export_date": ISO8601DateFormatter().string(from: Date()),
            "session_count": exportData.count
        ]

        let fullExport: [String: Any] = ["meta": meta, "sessions": exportData]

        if JSONSerialization.isValidJSONObject(fullExport),
           let data = try? JSONSerialization.data(withJSONObject: fullExport, options: [.prettyPrinted, .sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return nil
    }

    // MARK: - CSV Export

    /// Generate a CSV export of all sessions.
    func generateCSVExport(sessions: [DailySession]) -> String {
        var csv = "date,title,duration_minutes,mood,tasks_completed,tools_used,skills_learned,notes\n"

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        for session in sessions.sorted(by: { $0.date > $1.date }) {
            let dateStr = dateFormatter.string(from: session.date)
            csv += "\(dateStr),\(escapeCSV(session.title)),\(session.durationMinutes),\(session.mood),\(session.completedTasks),"
            csv += "\(escapeCSV(session.toolsUsed)),\(escapeCSV(session.skillsLearned)),\(escapeCSV(session.notes))\n"
        }

        return csv
    }

    // MARK: - Save to File

    /// Save a dump to the iOS Documents directory (accessible via Files app).
    func saveDump(_ content: String, filename: String) -> URL? {
        let fileManager = FileManager.default

        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let amorDir = documentsDir.appendingPathComponent("AMORDumps", isDirectory: true)

        if !fileManager.fileExists(atPath: amorDir.path) {
            try? fileManager.createDirectory(at: amorDir, withIntermediateDirectories: true)
        }

        let fileURL = amorDir.appendingPathComponent(filename)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }

    // MARK: - Copy to Clipboard

    /// Copy dump content to clipboard (uses UIPasteboard on iOS).
    func copyToClipboard(_ content: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = content
        #endif
    }

    // MARK: - Private Helpers

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return remainingMinutes == 0 ? "\(hours)h" : "\(hours)h \(remainingMinutes)m"
    }

    private func formatList(_ raw: String) -> String {
        guard !raw.isEmpty else { return "" }
        // Try JSON array
        if let data = raw.data(using: .utf8),
           let array = try? JSONDecoder().decode([String].self, from: data) {
            return array.joined(separator: ", ")
        }
        return raw
    }

    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
