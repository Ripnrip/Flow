/**
 * 🧘 AMORWeeklyReviewEngine — Weekly Review Automation & Narrative Intelligence
 *
 * "The seven-day mirror. Where scattered sessions crystallize into the arc
 * of a week, where streaks reveal their fragility, and where the rhythm
 * of a life lived with intention finds its weekly reflection."
 *
 * v3.4.0 — Weekly Review Automation & Streak Intelligence
 *
 * This engine runs on app foreground and produces:
 * 1. A weekly review markdown in ~/.hermes/logs/amor-dumps/ (one per ISO week)
 * 2. An entry in the Obsidian vault Journal (if accessible)
 * 3. A WeeklyReviewSummary for in-app narrative display
 *
 * Architecture: Foundation-only enum (no SwiftUI). Pure functions.
 * Reads SwiftData model objects passed as parameters. Writes to filesystem.
 */

import Foundation

// MARK: - WeeklyReviewConfig

enum WeeklyReviewConfig {
    static let lastWeeklyDumpWeekKey = "amor.lastWeeklyDumpWeek"
    static let weeklySnapshotsKey = "amor.weeklySnapshots"
    static let maxWeeklySnapshots = 52  // one year
}

// MARK: - WeeklyReviewSummary

/// Comprehensive weekly review summary for narrative display and dump generation.
struct WeeklyReviewSummary: Codable {
    let weekStart: Date
    let weekEnd: Date
    let isoWeekLabel: String  // "2026-W32"

    // Session metrics
    let totalSessions: Int
    let totalFocusMinutes: Int
    let totalTasksCompleted: Int
    let avgSessionMinutes: Int
    let dailySessionCounts: [Int]  // 7 elements, Mon-Sun
    let dailyFocusMinutes: [Int]   // 7 elements, Mon-Sun

    // Practice metrics
    let practicesTracked: Int
    let totalPracticeCompletions: Int  // total completions across all practices this week
    let perfectPractices: Int  // practices completed every scheduled day
    let longestActiveStreak: Int

    // Mood & Reflection
    let moodDistribution: [String: Int]
    let reflectionCount: Int

    // System health
    let avgCronHealth: Double
    let cronFailures: Int

    // Comparison vs previous week
    let focusMinutesDelta: Int  // positive = improvement
    let sessionsDelta: Int
    let practicesDelta: Int

    // Derived insights
    let mostProductiveDay: String?
    let leastProductiveDay: String?
    let topTools: [String]
    let topSkills: [String]

    var focusHours: Double {
        Double(totalFocusMinutes) / 60.0
    }

    var formattedWeekRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: weekStart)) – \(formatter.string(from: weekEnd))"
    }

    var trendDirection: String {
        if focusMinutesDelta > 0 { return "📈 Improving" }
        if focusMinutesDelta < 0 { return "📉 Declining" }
        return "➡️ Steady"
    }

    var qualityScore: Double {
        // Composite 0-100 score for the week
        let focusScore = min(Double(totalFocusMinutes) / 1200.0, 1.0) * 30  // 20h = max
        let consistencyScore = min(Double(totalSessions) / 14.0, 1.0) * 20  // 14 sessions = max
        let practiceScore = practicesTracked > 0 ?
            min(Double(totalPracticeCompletions) / Double(practicesTracked * 7), 1.0) * 25 : 0
        let reflectionScore = min(Double(reflectionCount) / 7.0, 1.0) * 15
        let healthScore = (avgCronHealth / 100.0) * 10
        return focusScore + consistencyScore + practiceScore + reflectionScore + healthScore
    }
}

// MARK: - WeeklyDumpResult

struct WeeklyDumpResult {
    let weekStart: Date
    let dumpPath: String?
    let obsidianPath: String?
    let summary: WeeklyReviewSummary
    let markdownContent: String
    let wasNew: Bool
}

// MARK: - AMORWeeklyReviewEngine

/// Pure-function engine for weekly review generation.
/// All methods are static — no state, no side effects except filesystem writes.
enum AMORWeeklyReviewEngine {

    // MARK: - Week Helpers

    /// Returns the Monday-start date for the week containing the given date.
    static func weekStart(for date: Date = .now) -> Date {
        let calendar = Calendar(identifier: .iso8601)
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    /// Returns the Sunday-end date for the week containing the given date.
    static func weekEnd(for date: Date = .now) -> Date {
        let calendar = Calendar(identifier: .iso8601)
        let start = weekStart(for: date)
        return calendar.date(byAdding: .day, value: 6, to: start) ?? start
    }

    /// Returns the ISO week label (e.g., "2026-W32").
    static func isoWeekLabel(for date: Date = .now) -> String {
        let calendar = Calendar(identifier: .iso8601)
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let year = components.yearForWeekOfYear ?? 0
        let week = components.weekOfYear ?? 0
        return String(format: "%d-W%02d", year, week)
    }

    /// Returns the ISO week label for the previous week.
    static func previousWeekLabel(for date: Date = .now) -> String {
        let calendar = Calendar(identifier: .iso8601)
        let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: date) ?? date
        return isoWeekLabel(for: lastWeek)
    }

    // MARK: - Weekly Review Generation

    /// Generates a comprehensive weekly review summary from SwiftData models.
    static func generateWeeklyReview(
        sessions: [AMORSessionSnapshot],
        practices: [AMORPracticeSnapshot],
        cronJobs: [AMORCronJobSnapshot],
        summaries: [AMORDailySummarySnapshot],
        reflections: [AMORReflectionSnapshot],
        referenceDate: Date = .now
    ) -> WeeklyReviewSummary {
        let calendar = Calendar(identifier: .iso8601)
        let start = weekStart(for: referenceDate)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? referenceDate

        // Filter sessions to this week
        let weekSessions = sessions.filter { $0.date >= start && $0.date < end }
        let totalMinutes = weekSessions.reduce(0) { $0 + $1.durationMinutes }
        let totalTasks = weekSessions.reduce(0) { $0 + $1.completedTasks }
        let avgMinutes = weekSessions.isEmpty ? 0 : totalMinutes / weekSessions.count

        // Daily breakdown (Mon=0 ... Sun=6)
        var dailySessions = [Int](repeating: 0, count: 7)
        var dailyMinutes = [Int](repeating: 0, count: 7)
        for session in weekSessions {
            let weekday = calendar.component(.weekday, from: session.date)
            // Calendar weekday: 1=Sunday, 2=Monday, ..., 7=Saturday
            // ISO week: Monday=0 ... Sunday=6
            let index = (weekday + 5) % 7  // Convert to Mon=0
            if index >= 0 && index < 7 {
                dailySessions[index] += 1
                dailyMinutes[index] += session.durationMinutes
            }
        }

        // Practice metrics
        let practiceCompletions = computeWeeklyPracticeCompletions(practices: practices, weekStart: start, weekEnd: end)
        let perfectCount = practiceCompletions.values.filter { $0 >= 7 }.count
        let longestStreak = practices.map { $0.currentStreak }.max() ?? 0

        // Mood distribution
        var moodCounts: [String: Int] = [:]
        for session in weekSessions {
            moodCounts[session.mood, default: 0] += 1
        }
        for summary in summaries.filter({ $0.date >= start && $0.date < end }) {
            moodCounts[summary.mood, default: 0] += 1
        }

        // Reflections
        let weekReflections = reflections.filter { $0.date >= start && $0.date < end }

        // Cron health
        let enabledJobs = cronJobs.filter { $0.isEnabled }
        let healthyJobs = enabledJobs.filter { $0.healthStatus == "healthy" }
        let avgHealth = enabledJobs.isEmpty ? 100.0 :
            Double(healthyJobs.count) / Double(enabledJobs.count) * 100.0
        let failures = enabledJobs.filter { $0.consecutiveFailures > 0 }.count

        // Previous week comparison
        let prevStart = calendar.date(byAdding: .weekOfYear, value: -1, to: start) ?? start
        let prevEnd = start
        let prevSessions = sessions.filter { $0.date >= prevStart && $0.date < prevEnd }
        let prevMinutes = prevSessions.reduce(0) { $0 + $1.durationMinutes }
        let prevPracticeCompletions = computeWeeklyPracticeCompletions(practices: practices, weekStart: prevStart, weekEnd: prevEnd)
        let prevTotalPractices = prevPracticeCompletions.values.reduce(0, +)

        // Tools and skills
        let allTools = weekSessions.flatMap { $0.toolsUsed.components(separatedBy: ",") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let topTools = Dictionary(grouping: allTools, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }

        let allSkills = weekSessions.flatMap { $0.skillsLearned.components(separatedBy: ",") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let topSkills = Dictionary(grouping: allSkills, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }

        // Most/least productive days
        let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let maxMinutes = dailyMinutes.max() ?? 0
        let minMinutes = dailyMinutes.filter { $0 > 0 }.min() ?? 0
        let mostProductiveDay = maxMinutes > 0 ? dayNames[dailyMinutes.firstIndex(of: maxMinutes) ?? 0] : nil
        let leastProductiveDay = minMinutes > 0 ? dayNames[dailyMinutes.firstIndex(of: minMinutes) ?? 0] : nil

        return WeeklyReviewSummary(
            weekStart: start,
            weekEnd: calendar.date(byAdding: .day, value: 6, to: start) ?? start,
            isoWeekLabel: isoWeekLabel(for: referenceDate),
            totalSessions: weekSessions.count,
            totalFocusMinutes: totalMinutes,
            totalTasksCompleted: totalTasks,
            avgSessionMinutes: avgMinutes,
            dailySessionCounts: dailySessions,
            dailyFocusMinutes: dailyMinutes,
            practicesTracked: practices.count,
            totalPracticeCompletions: practiceCompletions.values.reduce(0, +),
            perfectPractices: perfectCount,
            longestActiveStreak: longestStreak,
            moodDistribution: moodCounts,
            reflectionCount: weekReflections.count,
            avgCronHealth: avgHealth,
            cronFailures: failures,
            focusMinutesDelta: totalMinutes - prevMinutes,
            sessionsDelta: weekSessions.count - prevSessions.count,
            practicesDelta: practiceCompletions.values.reduce(0, +) - prevTotalPractices,
            mostProductiveDay: mostProductiveDay,
            leastProductiveDay: leastProductiveDay,
            topTools: topTools,
            topSkills: topSkills
        )
    }

    // MARK: - Practice Completion Computation

    /// Estimates weekly practice completions from lastCompletedDate and totalCompletions.
    /// Since PracticeStreak doesn't store per-day history, we approximate:
    /// if the practice is active and was completed within the week, count it.
    private static func computeWeeklyPracticeCompletions(
        practices: [AMORPracticeSnapshot],
        weekStart: Date,
        weekEnd: Date
    ) -> [String: Int] {
        var result: [String: Int] = [:]
        let calendar = Calendar.current

        for practice in practices {
            // Approximation: if lastCompletedDate falls within this week, count 1+ completions.
            // For a more accurate count we'd need per-day history (not stored in the model).
            if let last = practice.lastCompletedDate, last >= weekStart && last < weekEnd {
                // Rough estimate: if total completions are high and the practice is daily,
                // estimate based on days elapsed in the week
                let daysElapsed = calendar.dateComponents([.day], from: weekStart, to: min(last, weekEnd)).day ?? 1
                let estimated = max(1, min(daysElapsed + 1, 7))
                result[practice.practiceName] = estimated
            } else {
                result[practice.practiceName] = 0
            }
        }
        return result
    }

    // MARK: - Weekly Markdown Generation

    /// Generates a narrative weekly review in Markdown format.
    static func generateWeeklyMarkdown(summary: WeeklyReviewSummary) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full

        var output = ""

        // Header
        output += "# AMOR Weekly Review — \(summary.isoWeekLabel)\n\n"
        output += "**Week:** \(summary.formattedWeekRange)\n"
        output += "**Sessions:** \(summary.totalSessions)\n"
        output += "**Focus Time:** \(formatDuration(summary.totalFocusMinutes))\n"
        output += "**Tasks Completed:** \(summary.totalTasksCompleted)\n"
        output += "**Reflections:** \(summary.reflectionCount)\n"
        output += "**Quality Score:** \(String(format: "%.0f/100", summary.qualityScore))\n"
        output += "**Trend:** \(summary.trendDirection)\n\n"

        // Narrative
        output += "## 🌅 The Week's Arc\n\n"
        output += generateNarrative(summary: summary)
        output += "\n\n"

        // Daily Breakdown
        output += "## 📅 Daily Breakdown\n\n"
        output += "| Day | Sessions | Focus |\n"
        output += "|-----|----------|-------|\n"
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        for i in 0..<7 {
            output += "| \(dayNames[i]) | \(summary.dailySessionCounts[i]) | \(formatDuration(summary.dailyFocusMinutes[i])) |\n"
        }
        output += "\n"

        // Practices
        output += "## 🧘 Practices\n\n"
        output += "- **Tracked:** \(summary.practicesTracked)\n"
        output += "- **Total Completions:** \(summary.totalPracticeCompletions)\n"
        output += "- **Perfect (7/7):** \(summary.perfectPractices)\n"
        output += "- **Longest Active Streak:** \(summary.longestActiveStreak) days\n\n"

        // Tools & Skills
        if !summary.topTools.isEmpty {
            output += "## 🔧 Top Tools\n\n"
            for tool in summary.topTools {
                output += "- \(tool)\n"
            }
            output += "\n"
        }

        if !summary.topSkills.isEmpty {
            output += "## 🌱 Skills Developed\n\n"
            for skill in summary.topSkills {
                output += "- \(skill)\n"
            }
            output += "\n"
        }

        // System Health
        output += "## ⚙️ System Health\n\n"
        output += "- **Average Cron Health:** \(String(format: "%.0f%%", summary.avgCronHealth))\n"
        if summary.cronFailures > 0 {
            output += "- **Jobs with Failures:** \(summary.cronFailures)\n"
        }
        output += "\n"

        // Comparison
        output += "## 📊 Week-over-Week\n\n"
        output += "| Metric | This Week | Change |\n"
        output += "|--------|-----------|--------|\n"
        output += "| Sessions | \(summary.totalSessions) | \(formatDelta(summary.sessionsDelta)) |\n"
        output += "| Focus | \(formatDuration(summary.totalFocusMinutes)) | \(formatDelta(summary.focusMinutesDelta, unit: "m")) |\n"
        output += "| Practices | \(summary.totalPracticeCompletions) | \(formatDelta(summary.practicesDelta)) |\n"
        output += "\n"

        // Closing reflection prompt
        output += "## 🪞 Reflection\n\n"
        output += generateReflectionPrompt(summary: summary)
        output += "\n"

        return output
    }

    // MARK: - Narrative Generation

    /// Generates a short prose narrative summarizing the week.
    private static func generateNarrative(summary: WeeklyReviewSummary) -> String {
        var lines: [String] = []

        // Opening
        if summary.totalFocusMinutes >= 600 {
            lines.append("This was a **deep-focus week** with \(formatDuration(summary.totalFocusMinutes)) of intentional work across \(summary.totalSessions) sessions.")
        } else if summary.totalFocusMinutes >= 180 {
            lines.append("A **solid week** — \(formatDuration(summary.totalFocusMinutes)) of focused work in \(summary.totalSessions) sessions.")
        } else if summary.totalFocusMinutes > 0 {
            lines.append("A **lighter week** with \(formatDuration(summary.totalFocusMinutes)) across \(summary.totalSessions) session\(summary.totalSessions == 1 ? "" : "s"). Sometimes showing up is the practice.")
        } else {
            lines.append("This week left no session footprints — a pause, a reset, or simply living beyond the screen.")
        }

        // Trend
        if summary.focusMinutesDelta > 60 {
            lines.append("Focus time **increased by \(formatDuration(summary.focusMinutesDelta))** compared to last week — momentum is building. 📈")
        } else if summary.focusMinutesDelta < -60 {
            lines.append("Focus time **decreased by \(formatDuration(abs(summary.focusMinutesDelta)))** — perhaps rest was needed, or the rhythm shifted. 📉")
        }

        // Practices
        if summary.perfectPractices >= 2 {
            lines.append("\(summary.perfectPractices) practices were completed **every single day** — extraordinary discipline. 🔥")
        } else if summary.totalPracticeCompletions > 0 {
            lines.append("\(summary.totalPracticeCompletions) practice completions this week. The streak continues.")
        }

        // System health
        if summary.cronFailures > 0 {
            lines.append("⚠️ \(summary.cronFailures) system\(summary.cronFailures == 1 ? "" : "s") need attention — check the Systems tab.")
        } else if summary.avgCronHealth >= 95 {
            lines.append("All systems ran cleanly this week. The infrastructure hums. ✅")
        }

        // Productivity pattern
        if let most = summary.mostProductiveDay {
            lines.append("Your most productive day was **\(most)**.")
        }

        return lines.joined(separator: " ")
    }

    /// Generates a rotating reflection prompt based on the week's data.
    private static func generateReflectionPrompt(summary: WeeklyReviewSummary) -> String {
        let prompts: [String]
        if summary.totalFocusMinutes < 180 {
            prompts = [
                "*What stood between you and deeper focus this week? What one thing would change the shape of next week?*",
                "*Rest is not the opposite of practice — it is part of it. What did this quieter week teach you about your rhythms?*",
                "*The unlogged week is still a lived week. What happened in the spaces between sessions?*"
            ]
        } else if summary.perfectPractices >= 3 {
            prompts = [
                "*Streaks are beautiful and fragile. What has made consistency possible this week, and how can you protect it?*",
                "*When discipline feels effortless, something deeper has shifted. What changed?*",
                "*Perfect weeks are rare. Savor this one — and notice what conditions made it possible.*"
            ]
        } else if summary.focusMinutesDelta < 0 {
            prompts = [
                "*The arc of progress is never a straight line. What wisdom does this week's dip carry?*",
                "*Sometimes less is more intentional. Was this week's decrease a choice, a drift, or a signal?*"
            ]
        } else {
            prompts = [
                "*What surprised you this week? What pattern do you want to bring into the next?*",
                "*If next week were a single intention, what would it be?*",
                "*Look at the daily breakdown — when did you feel most alive? How can you engineer more of that?*",
                "*The quality score is a mirror, not a verdict. What does \(String(format: "%.0f", summary.qualityScore))/100 reveal?*"
            ]
        }
        return prompts[abs(summary.isoWeekLabel.hashValue) % prompts.count]
    }

    // MARK: - Auto-Dump Generation

    /// Generates (or updates) this week's weekly review dump.
    /// Deduplicates by ISO week — only writes a new file if the week changed.
    static func autoGenerateWeeklyDump(
        sessions: [AMORSessionSnapshot],
        practices: [AMORPracticeSnapshot],
        cronJobs: [AMORCronJobSnapshot],
        summaries: [AMORDailySummarySnapshot],
        reflections: [AMORReflectionSnapshot],
        dumpsDir: URL,
        obsidianJournalDir: URL?
    ) -> WeeklyDumpResult? {
        let currentWeek = isoWeekLabel()
        let lastWeek = UserDefaults.standard.string(forKey: WeeklyReviewConfig.lastWeeklyDumpWeekKey)

        let summary = generateWeeklyReview(
            sessions: sessions,
            practices: practices,
            cronJobs: cronJobs,
            summaries: summaries,
            reflections: reflections
        )

        let markdown = generateWeeklyMarkdown(summary: summary)
        let fileName = "amor-weekly-\(currentWeek).md"
        let dumpURL = dumpsDir.appendingPathComponent(fileName)
        let wasNew = !FileManager.default.fileExists(atPath: dumpURL.path)

        // Always overwrite with latest data (same pattern as daily dumps)
        do {
            try markdown.data(using: .utf8)?.write(to: dumpURL, options: .atomic)
        } catch {
            return nil
        }

        // Write to Obsidian vault if available
        var obsidianPath: String? = nil
        if let obsDir = obsidianJournalDir,
           FileManager.default.fileExists(atPath: obsDir.path) {
            let obsURL = obsDir.appendingPathComponent(fileName)
            try? markdown.data(using: .utf8)?.write(to: obsURL, options: .atomic)
            obsidianPath = obsURL.path
        }

        // Update last week key
        UserDefaults.standard.set(currentWeek, forKey: WeeklyReviewConfig.lastWeeklyDumpWeekKey)

        return WeeklyDumpResult(
            weekStart: summary.weekStart,
            dumpPath: dumpURL.path,
            obsidianPath: obsidianPath,
            summary: summary,
            markdownContent: markdown,
            wasNew: wasNew && lastWeek != currentWeek
        )
    }

    // MARK: - Formatting Helpers

    private static func formatDuration(_ minutes: Int) -> String {
        if minutes == 0 { return "0m" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(mins)m"
    }

    private static func formatDelta(_ delta: Int, unit: String = "") -> String {
        if delta > 0 { return "+\(delta)\(unit)" }
        if delta < 0 { return "\(delta)\(unit)" }
        return "—"
    }

    /// Returns the weekday name for a given index (0=Monday ... 6=Sunday).
    static func weekdayName(index: Int) -> String {
        let names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        guard index >= 0 && index < 7 else { return "?" }
        return names[index]
    }
}
