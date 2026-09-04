/**
 * 🧘 AMORProgressTracker — Progress Tracking & Analytics Engine
 *
 * "The unwavering observer of patterns across time. Where raw sessions
 * become insights, where scattered data points coalesce into the arc
 * of a life being lived with intention."
 *
 * Uses the UserDefaults-direct pattern for independent, testable
 * aggregation without view-lifecycle coupling.
 */

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - WeeklyInsights

/// Aggregated insights for a 7-day window.
struct WeeklyInsights: Identifiable {
    let id = UUID()
    let weekStart: Date
    let totalSessions: Int
    let totalFocusMinutes: Int
    let totalTasksCompleted: Int
    let avgSessionMinutes: Int
    let sessionsPerDay: [DayCount]
    let topTools: [ToolCount]
    let topSkills: [SkillCount]
    let moodDistribution: [MoodCount]
    let practicesCompleted: Int
    let practicesStreak: Int
    let longestStreak: Int
    let cronHealthPercentage: Double
    let mostProductiveDay: String?
    let focusTrend: TrendDirection

    var formattedWeekRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let calendar = Calendar.current
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        return "\(formatter.string(from: weekStart)) – \(formatter.string(from: weekEnd))"
    }
}

// MARK: - Supporting Types

struct DayCount: Identifiable, Hashable {
    let id = UUID()
    let dayName: String
    let count: Int
    let minutes: Int
}

struct ToolCount: Identifiable, Hashable {
    let id = UUID()
    let tool: String
    let count: Int
}

struct SkillCount: Identifiable, Hashable {
    let id = UUID()
    let skill: String
    let count: Int
}

struct MoodCount: Identifiable, Hashable {
    let id = UUID()
    let mood: String
    let count: Int
}

enum TrendDirection: String {
    case up = "↗️"
    case down = "↘️"
    case flat = "→"

    var label: String {
        switch self {
        case .up: return "Increasing"
        case .down: return "Decreasing"
        case .flat: return "Steady"
        }
    }

    #if canImport(SwiftUI)
    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .orange
        case .flat: return .blue
        }
    }
    #endif
}

// MARK: - MonthlyReport

/// Aggregated monthly data for the progress dump.
struct MonthlyReport: Identifiable {
    let id = UUID()
    let monthName: String
    let year: Int
    let totalSessions: Int
    let totalFocusMinutes: Int
    let totalTasksCompleted: Int
    let uniqueTools: Int
    let uniqueSkills: Int
    let practicesCompleted: Int
    let activeDays: Int
    let longestStreak: Int
}

// MARK: - AMORProgressTracker

/// Progress tracking engine — reads data from SwiftData via injected context,
/// computes insights, and generates reports.
/// Designed for reuse across views, widgets, and dump automation.
@Observable
final class AMORProgressTracker {

    // MARK: - Weekly Insights

    /// Compute insights for the last 7 days (or custom window).
    func computeWeeklyInsights(
        sessions: [AMORSessionSnapshot],
        practices: [AMORPracticeSnapshot],
        cronJobs: [AMORCronJobSnapshot],
        weeksAgo: Int = 0
    ) -> WeeklyInsights {
        let calendar = Calendar.current
        let today = Date()

        // Calculate the start of the target week
        let weekOffset = weeksAgo * 7
        guard let weekStart = calendar.date(
            byAdding: .day,
            value: -6 - weekOffset,
            to: today
        ),
        let weekStartNormalized = calendar.date(
            byAdding: .day,
            value: -weekOffset,
            to: calendar.startOfDay(for: weekStart)
        ) else {
            return emptyInsights(weekStart: today)
        }

        let weekEnd = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        // Filter sessions to the window
        let weekSessions = sessions.filter { $0.date >= weekStartNormalized && $0.date < weekEnd }

        let totalFocusMinutes = weekSessions.reduce(0) { $0 + $1.durationMinutes }
        let totalTasks = weekSessions.reduce(0) { $0 + $1.completedTasks }
        let avgMinutes = weekSessions.isEmpty ? 0 : totalFocusMinutes / weekSessions.count

        // Sessions per day
        let sessionsPerDay = computeSessionsPerDay(sessions: weekSessions, weekStart: weekStartNormalized)

        // Tools and skills frequency
        let topTools = computeTopItems(from: weekSessions, extractor: { $0.toolsUsed })
        let topSkills = computeTopSkills(from: weekSessions, extractor: { $0.skillsLearned })

        // Mood distribution
        let moodDistribution = computeMoodDistribution(sessions: weekSessions)

        // Practices
        let practicesCompleted = practices.reduce(0) { $0 + $1.totalCompletions }
        let currentMaxStreak = practices.map { $0.currentStreak }.max() ?? 0
        let longestStreak = practices.map { $0.longestStreak }.max() ?? 0

        // Cron health
        let enabledJobs = cronJobs.filter { $0.isEnabled }
        let healthyJobs = enabledJobs.filter { $0.healthStatus == "healthy" }
        let cronHealthPct = enabledJobs.isEmpty ? 100.0 : Double(healthyJobs.count) / Double(enabledJobs.count) * 100.0

        // Most productive day
        let mostProductiveDay = sessionsPerDay.max(by: { $0.minutes < $1.minutes })?.dayName

        // Trend: compare this week to last week
        let trend = computeTrend(currentSessions: weekSessions.count, allSessions: sessions, weekStart: weekStartNormalized)

        return WeeklyInsights(
            weekStart: weekStartNormalized,
            totalSessions: weekSessions.count,
            totalFocusMinutes: totalFocusMinutes,
            totalTasksCompleted: totalTasks,
            avgSessionMinutes: avgMinutes,
            sessionsPerDay: sessionsPerDay,
            topTools: topTools,
            topSkills: topSkills,
            moodDistribution: moodDistribution,
            practicesCompleted: practicesCompleted,
            practicesStreak: currentMaxStreak,
            longestStreak: longestStreak,
            cronHealthPercentage: cronHealthPct,
            mostProductiveDay: mostProductiveDay,
            focusTrend: trend
        )
    }

    // MARK: - Monthly Report

    /// Compute a monthly report for the given month offset (0 = current month).
    func computeMonthlyReport(
        sessions: [AMORSessionSnapshot],
        practices: [AMORPracticeSnapshot],
        monthsAgo: Int = 0
    ) -> MonthlyReport {
        let calendar = Calendar.current
        let today = Date()

        guard let targetMonth = calendar.date(byAdding: .month, value: -monthsAgo, to: today) else {
            return emptyMonthlyReport()
        }

        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: targetMonth))!
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!

        let monthSessions = sessions.filter { $0.date >= monthStart && $0.date < monthEnd }
        let totalFocusMinutes = monthSessions.reduce(0) { $0 + $1.durationMinutes }
        let totalTasks = monthSessions.reduce(0) { $0 + $1.completedTasks }

        let allTools = monthSessions.flatMap { parseCSV($0.toolsUsed) }
        let allSkills = monthSessions.flatMap { parseCSV($0.skillsLearned) }

        let activeDays = Set(monthSessions.map { calendar.startOfDay(for: $0.date) }).count
        let longestStreak = practices.map { $0.longestStreak }.max() ?? 0
        let practicesCompleted = practices.reduce(0) { $0 + $1.totalCompletions }

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"
        let monthName = monthFormatter.string(from: targetMonth)
        let year = calendar.component(.year, from: targetMonth)

        return MonthlyReport(
            monthName: monthName,
            year: year,
            totalSessions: monthSessions.count,
            totalFocusMinutes: totalFocusMinutes,
            totalTasksCompleted: totalTasks,
            uniqueTools: Set(allTools).count,
            uniqueSkills: Set(allSkills).count,
            practicesCompleted: practicesCompleted,
            activeDays: activeDays,
            longestStreak: longestStreak
        )
    }

    // MARK: - Streak Analytics

    /// Compute streak statistics across all practices.
    func computeStreakStats(practices: [AMORPracticeSnapshot]) -> StreakStats {
        let active = practices.filter { $0.isActive }
        let totalCompletions = practices.reduce(0) { $0 + $1.totalCompletions }
        let longestStreak = practices.map { $0.longestStreak }.max() ?? 0
        let currentBest = practices.map { $0.currentStreak }.max() ?? 0
        let dueToday = practices.filter { $0.isDueToday }

        return StreakStats(
            activeCount: active.count,
            totalPractices: practices.count,
            totalCompletions: totalCompletions,
            longestStreak: longestStreak,
            currentBestStreak: currentBest,
            dueTodayCount: dueToday.count
        )
    }

    // MARK: - Private Helpers

    private func computeSessionsPerDay(sessions: [AMORSessionSnapshot], weekStart: Date) -> [DayCount] {
        let calendar = Calendar.current
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var results: [DayCount] = []

        for i in 0..<7 {
            guard let dayStart = calendar.date(byAdding: .day, value: i, to: weekStart),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            let daySessions = sessions.filter { $0.date >= dayStart && $0.date < dayEnd }
            let minutes = daySessions.reduce(0) { $0 + $1.durationMinutes }

            let weekday = calendar.component(.weekday, from: dayStart)
            let dayName = dayNames[(weekday - 2 + 7) % 7] // Convert Sunday=1 to Monday=0

            results.append(DayCount(dayName: dayName, count: daySessions.count, minutes: minutes))
        }

        return results
    }

    private func computeTopItems(from sessions: [AMORSessionSnapshot], extractor: (AMORSessionSnapshot) -> String) -> [ToolCount] {
        computeItemCounts(from: sessions, extractor: extractor)
            .map { ToolCount(tool: $0.key, count: $0.value) }
    }

    private func computeTopSkills(from sessions: [AMORSessionSnapshot], extractor: (AMORSessionSnapshot) -> String) -> [SkillCount] {
        computeItemCounts(from: sessions, extractor: extractor)
            .map { SkillCount(skill: $0.key, count: $0.value) }
    }

    private func computeItemCounts(from sessions: [AMORSessionSnapshot], extractor: (AMORSessionSnapshot) -> String) -> [(key: String, value: Int)] {
        var counts: [String: Int] = [:]
        for session in sessions {
            let items = parseCSV(extractor(session))
            for item in items {
                let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    counts[trimmed, default: 0] += 1
                }
            }
        }
        return counts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { (key: $0.key, value: $0.value) }
    }

    private func computeMoodDistribution(sessions: [AMORSessionSnapshot]) -> [MoodCount] {
        var counts: [String: Int] = [:]
        for session in sessions {
            counts[session.mood, default: 0] += 1
        }
        return counts
            .sorted { $0.value > $1.value }
            .map { MoodCount(mood: $0.key, count: $0.value) }
    }

    private func computeTrend(currentSessions: Int, allSessions: [AMORSessionSnapshot], weekStart: Date) -> TrendDirection {
        let calendar = Calendar.current
        guard let prevWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStart),
              let prevWeekEnd = calendar.date(byAdding: .day, value: 7, to: prevWeekStart) else {
            return .flat
        }

        let prevWeekSessions = allSessions.filter { $0.date >= prevWeekStart && $0.date < prevWeekEnd }

        if currentSessions > prevWeekSessions.count + 1 { return .up }
        if currentSessions < prevWeekSessions.count - 1 { return .down }
        return .flat
    }

    private func parseCSV(_ csv: String) -> [String] {
        guard !csv.isEmpty else { return [] }
        // Try JSON array first
        if let data = csv.data(using: .utf8),
           let array = try? JSONDecoder().decode([String].self, from: data) {
            return array
        }
        // Fall back to comma-separated
        return csv.components(separatedBy: ",")
    }

    private func emptyInsights(weekStart: Date) -> WeeklyInsights {
        WeeklyInsights(
            weekStart: weekStart,
            totalSessions: 0,
            totalFocusMinutes: 0,
            totalTasksCompleted: 0,
            avgSessionMinutes: 0,
            sessionsPerDay: [],
            topTools: [],
            topSkills: [],
            moodDistribution: [],
            practicesCompleted: 0,
            practicesStreak: 0,
            longestStreak: 0,
            cronHealthPercentage: 100,
            mostProductiveDay: nil,
            focusTrend: .flat
        )
    }

    private func emptyMonthlyReport() -> MonthlyReport {
        MonthlyReport(
            monthName: "Unknown",
            year: Calendar.current.component(.year, from: Date()),
            totalSessions: 0,
            totalFocusMinutes: 0,
            totalTasksCompleted: 0,
            uniqueTools: 0,
            uniqueSkills: 0,
            practicesCompleted: 0,
            activeDays: 0,
            longestStreak: 0
        )
    }
}

// MARK: - StreakStats

struct StreakStats: Identifiable {
    let id = UUID()
    let activeCount: Int
    let totalPractices: Int
    let totalCompletions: Int
    let longestStreak: Int
    let currentBestStreak: Int
    let dueTodayCount: Int

    var activePercentage: Double {
        guard totalPractices > 0 else { return 0 }
        return Double(activeCount) / Double(totalPractices) * 100
    }
}
