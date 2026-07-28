/**
 * 🔥 AMORActivityHeatmap — Activity Intensity Visualization
 *
 * "The constellation of your days, mapped in fire and ember. Where each
 * square is a day lived with intention, and the pattern reveals the
 * rhythm of a life in motion."
 *
 * v2.8.0 — Activity Heatmap Calendar
 *
 * A GitHub-style contribution grid showing the last 12 weeks of daily
 * activity. Color intensity is computed from sessions logged, focus
 * minutes, tasks completed, and practices done.
 */

import SwiftUI
import SwiftData

// MARK: - Activity Heatmap Data

/// Computes daily activity scores from session data.
struct ActivityHeatmapData: Identifiable {
    let id = UUID()
    let date: Date
    let activityScore: Int      // 0-4 intensity level
    let sessionCount: Int
    let focusMinutes: Int
    let practicesCompleted: Int

    var isActive: Bool { activityScore > 0 }
    var intensityLabel: String {
        switch activityScore {
        case 0: return "No activity"
        case 1: return "Light"
        case 2: return "Moderate"
        case 3: return "Strong"
        default: return "Intense"
        }
    }
}

// MARK: - Heatmap Color Intensity

enum HeatmapIntensity {
    /// Returns a color for a given activity score (0-4).
    static func color(for score: Int) -> Color {
        switch score {
        case 0: return Color.gray.opacity(0.12)
        case 1: return Color(red: 0.55, green: 0.68, blue: 0.52).opacity(0.35)
        case 2: return Color(red: 0.55, green: 0.68, blue: 0.52).opacity(0.55)
        case 3: return Color(red: 0.82, green: 0.68, blue: 0.42).opacity(0.75)
        default: return Color(red: 0.95, green: 0.65, blue: 0.42)
        }
    }

    /// Returns the AMOR palette name for legend display.
    static var legendLevels: [(label: String, color: Color)] {
        [
            ("None", color(for: 0)),
            ("Light", color(for: 1)),
            ("Moderate", color(for: 2)),
            ("Strong", color(for: 3)),
            ("Intense", color(for: 4))
        ]
    }
}

// MARK: - Heatmap Week Model

struct HeatmapWeek: Identifiable {
    let id = UUID()
    let weekIndex: Int
    let days: [ActivityHeatmapData?]  // 7 entries, nil for dates outside range
    let weekStartDate: Date
}

// MARK: - Activity Heatmap View

struct AMORActivityHeatmapView: View {
    @Query private var sessions: [DailySession]
    @Query private var practices: [PracticeStreak]

    @State private var selectedDay: ActivityHeatmapData?
    @State private var showLegend = false

    /// Number of weeks to display.
    private let weeksToShow = 12

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                headerSection

                // Stats Summary
                statsSummary

                // Heatmap Grid
                heatmapGrid

                // Legend
                legendRow

                // Selected Day Detail
                if let selected = selectedDay {
                    selectedDayCard(selected)
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Activity Map")
                .font(AMORTypography.headingFont)
                .foregroundStyle(AMORColorPalette.deepIndigo)

            Text("Last \(weeksToShow) weeks of intentional living")
                .font(AMORTypography.subtitleFont)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stats Summary

    private var statsSummary: some View {
        let stats = computeOverallStats()

        return AMORComponents.ContemplativeCard {
            HStack(spacing: 16) {
                statBlock(value: "\(stats.activeDays)", label: "Active Days", icon: "calendar")
                Divider().frame(height: 40)
                statBlock(value: "\(stats.totalSessions)", label: "Sessions", icon: AMORIconSet.journal)
                Divider().frame(height: 40)
                statBlock(value: "\(stats.totalMinutes / 60)h", label: "Focus Time", icon: "hourglass")
                Divider().frame(height: 40)
                statBlock(value: "\(stats.avgPerWeek, specifier: "%.1f")", label: "Per Week", icon: "chart.bar.fill")
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func statBlock(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AMORColorPalette.growth)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.primary)
            Text(label)
                .font(AMORTypography.captionFont)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Heatmap Grid

    private var heatmapGrid: some View {
        let weeks = buildWeeks()

        return AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 8) {
                // Day-of-week labels
                HStack(spacing: 4) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(["Mon", "Wed", "Fri"], id: \.self) { day in
                            Text(day)
                                .font(AMORTypography.captionFont)
                                .foregroundStyle(.secondary)
                                .frame(width: 28, height: 28, alignment: .center)
                        }
                    }

                    // Weekday label spacer rows
                    VStack(spacing: 0) {
                        ForEach(0..<7) { row in
                            if row % 2 == 0 {
                                Text(["M", "", "W", "", "F", "", "S"][row])
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 12, height: 28, alignment: .center)
                            } else {
                                Color.clear.frame(width: 12, height: 28)
                            }
                        }
                    }

                    // Grid cells
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(weeks) { week in
                                VStack(spacing: 4) {
                                    ForEach(0..<7) { dayIndex in
                                        heatmapCell(week.days[dayIndex])
                                    }
                                }
                            }
                        }
                    }
                }

                // Month labels
                monthLabels(for: weeks)
            }
        }
    }

    private func heatmapCell(_ data: ActivityHeatmapData?) -> some View {
        Group {
            if let data = data {
                RoundedRectangle(cornerRadius: 4)
                    .fill(HeatmapIntensity.color(for: data.activityScore))
                    .frame(width: 28, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(
                                selectedDay?.id == data.id ?
                                AMORColorPalette.mutedGold : Color.clear,
                                lineWidth: 2
                            )
                    )
                    .onTapGesture {
                        withAnimation(AMORAnimations.slowFade) {
                            selectedDay = data
                        }
                    }
                    .accessibilityLabel("\(data.intensityLabel) — \(data.sessionCount) sessions, \(data.focusMinutes) minutes")
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.clear)
                    .frame(width: 28, height: 28)
            }
        }
    }

    private func monthLabels(for weeks: [HeatmapWeek]) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        // Show month abbreviations at the start of each month
        return HStack(spacing: 4) {
            ForEach(Array(weeks.enumerated()), id: \.element.id) { index, week in
                let monthName = formatter.string(from: week.weekStartDate)
                let isMonthStart = index == 0 ||
                    Calendar.current.component(.month, from: week.weekStartDate) !=
                    Calendar.current.component(.month, from: weeks[max(0, index - 1)].weekStartDate)

                Text(isMonthStart ? monthName : "")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .leading)
            }
        }
        .padding(.leading, 52)
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: 6) {
            Text("Less")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            ForEach(Array(HeatmapIntensity.legendLevels.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 3)
                    .fill(level.color)
                    .frame(width: 14, height: 14)
            }

            Text("More")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Selected Day Detail

    private func selectedDayCard(_ data: ActivityHeatmapData) -> some View {
        let formatter = DateFormatter()
        formatter.dateStyle = .full

        return AMORComponents.ContemplativeCard(isActive: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "calendar.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AMORColorPalette.twilightPurple)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatter.string(from: data.date))
                            .font(AMORTypography.titleFont)
                            .foregroundStyle(.primary)

                        Text(data.intensityLabel)
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(AMORColorPalette.twilightPurple)
                    }

                    Spacer()

                    // Intensity indicator
                    Circle()
                        .fill(HeatmapIntensity.color(for: data.activityScore))
                        .frame(width: 16, height: 16)
                }

                Divider()

                // Day stats
                HStack(spacing: 24) {
                    VStack {
                        Text("\(data.sessionCount)")
                            .font(.title2.bold())
                        Text("Sessions")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                    }

                    VStack {
                        Text("\(data.focusMinutes)m")
                            .font(.title2.bold())
                        Text("Focus")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                    }

                    VStack {
                        Text("\(data.practicesCompleted)")
                            .font(.title2.bold())
                        Text("Practices")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                // Sessions on this day
                let daySessions = sessions.filter { isSameDay($0.date, data.date) }
                if !daySessions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sessions")
                            .font(AMORTypography.bodyFont.bold())
                            .foregroundStyle(AMORColorPalette.deepIndigo)

                        ForEach(daySessions.prefix(5), id: \.id) { session in
                            HStack {
                                Text("• \(session.title)")
                                    .font(AMORTypography.bodyFont)
                                Spacer()
                                Text("\(session.durationMinutes)m")
                                    .font(AMORTypography.captionFont)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Data Computation

    /// Build weeks of heatmap data from session records.
    private func buildWeeks() -> [HeatmapWeek] {
        let calendar = Calendar.current
        let today = Date()
        let totalDays = weeksToShow * 7

        // Find the start of the current week (Sunday)
        let currentWeekday = calendar.component(.weekday, from: today)
        let daysFromSunday = currentWeekday - 1
        guard let thisSunday = calendar.date(byAdding: .day, value: daysFromSunday, to: today),
              let startDate = calendar.date(byAdding: .day, value: -(totalDays - 1), to: thisSunday) else {
            return []
        }

        var weeks: [HeatmapWeek] = []

        for weekIndex in 0..<weeksToShow {
            guard let weekStart = calendar.date(byAdding: .day, value: weekIndex * 7, to: startDate) else { continue }

            var days: [ActivityHeatmapData?] = []

            for dayOffset in 0..<7 {
                guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else {
                    days.append(nil)
                    continue
                }

                // Skip future dates
                if dayDate > today {
                    days.append(nil)
                    continue
                }

                let dayData = computeDayActivity(for: dayDate)
                days.append(dayData)
            }

            weeks.append(HeatmapWeek(
                weekIndex: weekIndex,
                days: days,
                weekStartDate: weekStart
            ))
        }

        return weeks
    }

    /// Compute activity intensity for a single day.
    private func computeDayActivity(for date: Date) -> ActivityHeatmapData {
        let daySessions = sessions.filter { isSameDay($0.date, date) }

        let sessionCount = daySessions.count
        let focusMinutes = daySessions.reduce(0) { $0 + $1.durationMinutes }
        let tasksCompleted = daySessions.reduce(0) { $0 + $1.completedTasks }

        // Count practices completed on this day
        let practicesCompleted = practices.filter { practice in
            guard let last = practice.lastCompletedDate else { return false }
            return isSameDay(last, date)
        }.count

        // Compute activity score (0-4)
        // Weight: sessions + minutes/30 + tasks/2 + practices
        let rawScore = sessionCount * 2 + (focusMinutes / 30) + (tasksCompleted / 2) + practicesCompleted
        let score: Int
        switch rawScore {
        case 0: score = 0
        case 1...3: score = 1
        case 4...7: score = 2
        case 8...12: score = 3
        default: score = 4
        }

        return ActivityHeatmapData(
            date: date,
            activityScore: score,
            sessionCount: sessionCount,
            focusMinutes: focusMinutes,
            practicesCompleted: practicesCompleted
        )
    }

    /// Overall statistics across the displayed period.
    private struct OverallStats {
        let activeDays: Int
        let totalSessions: Int
        let totalMinutes: Int
        let avgPerWeek: Double
    }

    private func computeOverallStats() -> OverallStats {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -(weeksToShow * 7), to: Date()) ?? Date()

        let recentSessions = sessions.filter { $0.date >= cutoff }
        let activeDays = Set(recentSessions.map { calendar.startOfDay(for: $0.date) }).count
        let totalMinutes = recentSessions.reduce(0) { $0 + $1.durationMinutes }
        let avgPerWeek = Double(recentSessions.count) / Double(weeksToShow)

        return OverallStats(
            activeDays: activeDays,
            totalSessions: recentSessions.count,
            totalMinutes: totalMinutes,
            avgPerWeek: avgPerWeek
        )
    }

    // MARK: - Helpers

    private func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        Calendar.current.isDate(date1, inSameDayAs: date2)
    }
}

// MARK: - Compact Heatmap Card (for Dashboard)

/// A compact version of the heatmap for the Dashboard tab.
struct ActivityHeatmapCard: View {
    @Query private var sessions: [DailySession]

    private let weeksToShow = 8

    var body: some View {
        AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(AMORColorPalette.energy)
                    Text("Activity")
                        .font(AMORTypography.bodyFont.bold())
                    Spacer()
                    Text("\(recentActiveDays) active days")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }

                compactHeatmap
            }
        }
    }

    private var recentActiveDays: Int {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -(weeksToShow * 7), to: Date()) ?? Date()
        let recentSessions = sessions.filter { $0.date >= cutoff }
        return Set(recentSessions.map { calendar.startOfDay(for: $0.date) }).count
    }

    private var compactHeatmap: some View {
        let cells = buildCompactCells()

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(0..<weeksToShow) { week in
                    VStack(spacing: 3) {
                        ForEach(0..<7) { day in
                            let idx = week * 7 + day
                            RoundedRectangle(cornerRadius: 2)
                                .fill(HeatmapIntensity.color(for: cells.indices.contains(idx) ? cells[idx] : 0))
                                .frame(width: 14, height: 14)
                        }
                    }
                }
            }
        }
    }

    private func buildCompactCells() -> [Int] {
        let calendar = Calendar.current
        let today = Date()
        let totalDays = weeksToShow * 7

        let currentWeekday = calendar.component(.weekday, from: today)
        let daysFromSunday = currentWeekday - 1
        guard let thisSunday = calendar.date(byAdding: .day, value: daysFromSunday, to: today),
              let startDate = calendar.date(byAdding: .day, value: -(totalDays - 1), to: thisSunday) else {
            return Array(repeating: 0, count: totalDays)
        }

        var scores: [Int] = []

        for dayOffset in 0..<totalDays {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else {
                scores.append(0)
                continue
            }

            if dayDate > today {
                scores.append(0)
                continue
            }

            let daySessions = sessions.filter { calendar.isDate($0.date, inSameDayAs: dayDate) }
            let sessionCount = daySessions.count
            let focusMinutes = daySessions.reduce(0) { $0 + $1.durationMinutes }

            let rawScore = sessionCount * 2 + (focusMinutes / 30)
            let score: Int
            switch rawScore {
            case 0: score = 0
            case 1...3: score = 1
            case 4...7: score = 2
            case 8...12: score = 3
            default: score = 4
            }
            scores.append(score)
        }

        return scores
    }
}
