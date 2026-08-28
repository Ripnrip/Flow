/**
 * 🧘 AMORInsightsView — Weekly Insights & Progress Visualization
 *
 * "The mirror that reveals patterns unseen. Where data becomes wisdom,
 * and the week's labor finds its meaning in the arc of time."
 */

import SwiftUI
import SwiftData

struct AMORInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [DailySession]
    @Query private var practices: [PracticeStreak]
    @Query private var cronJobs: [CronJobHealth]

    @State private var tracker = AMORProgressTracker()
    @State private var selectedWeeksAgo = 0

    private var insights: WeeklyInsights {
        tracker.computeWeeklyInsights(
            sessions: sessions,
            practices: practices,
            cronJobs: cronJobs,
            weeksAgo: selectedWeeksAgo
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Week selector
                WeekSelector(weeksAgo: $selectedWeeksAgo, weekStart: insights.weekStart)

                // Summary stats grid
                SummaryStatsGrid(insights: insights)

                // Focus time chart
                WeeklyFocusChart(insights: insights)

                // Top tools & skills
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading) {
                        ToolsBreakdown(tools: insights.topTools)
                    }
                    VStack(alignment: .leading) {
                        SkillsBreakdown(skills: insights.topSkills)
                    }
                }

                // Mood distribution
                if !insights.moodDistribution.isEmpty {
                    MoodDistributionView(moods: insights.moodDistribution)
                }

                // Streak stats
                StreakSummaryView(stats: tracker.computeStreakStats(practices: practices))

                // Recovery desk — v4.7.0: the compiled-but-never-dispensed medicine, wired.
                RecoveryDeskView(actions: AMORStreakIntelligence.recoveryActions(for: practices))

                // Monthly mirror — v4.7.0: computeMonthlyReport was dead since forging.
                MonthlyMirrorView(report: tracker.computeMonthlyReport(sessions: sessions, practices: practices))

                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Insights")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Week Selector

struct WeekSelector: View {
    @Binding var weeksAgo: Int
    let weekStart: Date

    var body: some View {
        HStack {
            Button {
                weeksAgo += 1
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }
            .disabled(weeksAgo >= 4)

            Spacer()

            VStack {
                Text(weeksAgo == 0 ? "This Week" : "\(weeksAgo) week\(weeksAgo > 1 ? "s" : "") ago")
                    .font(AMORTypography.titleFont)
                    .foregroundStyle(AMORColorPalette.deepIndigo)
                Text(formattedRange)
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                weeksAgo -= 1
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
            .disabled(weeksAgo <= 0)
        }
        .padding(.horizontal)
    }

    private var formattedRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        let calendar = Calendar.current
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        return "\(formatter.string(from: weekStart)) – \(formatter.string(from: weekEnd))"
    }
}

// MARK: - Summary Stats Grid

struct SummaryStatsGrid: View {
    let insights: WeeklyInsights

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            InsightStatCard(
                icon: "clock.fill",
                label: "Focus Time",
                value: formatDuration(insights.totalFocusMinutes),
                color: AMORColorPalette.energy
            )

            InsightStatCard(
                icon: "checkmark.circle.fill",
                label: "Tasks Done",
                value: "\(insights.totalTasksCompleted)",
                color: AMORColorPalette.growth
            )

            InsightStatCard(
                icon: "flame.fill",
                label: "Best Streak",
                value: "\(insights.longestStreak)d",
                color: .orange
            )

            InsightStatCard(
                icon: "heart.fill",
                label: "System Health",
                value: String(format: "%.0f%%", insights.cronHealthPercentage),
                color: insights.cronHealthPercentage >= 80 ? .green : .orange
            )
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        return String(format: "%.1fh", Double(minutes) / 60.0)
    }
}

struct InsightStatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        AMORComponents.ContemplativeCard {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)

                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                Text(label)
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Weekly Focus Chart

struct WeeklyFocusChart: View {
    let insights: WeeklyInsights

    private var maxMinutes: Int {
        insights.sessionsPerDay.map { $0.minutes }.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Focus Time")
                    .font(AMORTypography.titleFont)
                    .foregroundStyle(AMORColorPalette.deepIndigo)

                Spacer()

                if insights.focusTrend != .flat {
                    Text(insights.focusTrend.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(insights.focusTrend.color)
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(insights.sessionsPerDay) { day in
                    VStack(spacing: 4) {
                        Text(day.minutes > 0 ? "\(day.minutes)" : "")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [AMORColorPalette.dawnOrange.opacity(0.6), AMORColorPalette.dawnOrange],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(height: barHeight(for: day.minutes))

                        Text(day.dayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
    }

    private func barHeight(for minutes: Int) -> CGFloat {
        guard maxMinutes > 0 else { return 2 }
        return max(2, CGFloat(minutes) / CGFloat(maxMinutes) * 80)
    }
}

// MARK: - Tools Breakdown

struct ToolsBreakdown: View {
    let tools: [ToolCount]

    private var maxCount: Int {
        tools.map { $0.count }.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Tools")
                .font(AMORTypography.titleFont)
                .foregroundStyle(AMORColorPalette.deepIndigo)

            if tools.isEmpty {
                Text("No tools logged")
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tools) { tool in
                    HStack {
                        Text(tool.tool)
                            .font(AMORTypography.captionFont)
                            .lineLimit(1)
                        Spacer()
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AMORColorPalette.sageGreen.opacity(0.6))
                            .frame(width: barWidth(tool.count), height: 8)
                        Text("\(tool.count)")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        .frame(maxWidth: .infinity)
    }

    private func barWidth(_ count: Int) -> CGFloat {
        return max(8, CGFloat(count) / CGFloat(maxCount) * 60)
    }
}

// MARK: - Skills Breakdown

struct SkillsBreakdown: View {
    let skills: [SkillCount]

    private var maxCount: Int {
        skills.map { $0.count }.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Skills Learned")
                .font(AMORTypography.titleFont)
                .foregroundStyle(AMORColorPalette.deepIndigo)

            if skills.isEmpty {
                Text("No skills logged")
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(skills) { skill in
                    HStack {
                        Text(skill.skill)
                            .font(AMORTypography.captionFont)
                            .lineLimit(1)
                        Spacer()
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AMORColorPalette.twilightPurple.opacity(0.6))
                            .frame(width: barWidth(skill.count), height: 8)
                        Text("\(skill.count)")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        .frame(maxWidth: .infinity)
    }

    private func barWidth(_ count: Int) -> CGFloat {
        return max(8, CGFloat(count) / CGFloat(maxCount) * 60)
    }
}

// MARK: - Mood Distribution

struct MoodDistributionView: View {
    let moods: [MoodCount]

    private var maxCount: Int {
        moods.map { $0.count }.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mood Distribution")
                .font(AMORTypography.titleFont)
                .foregroundStyle(AMORColorPalette.deepIndigo)

            ForEach(moods) { mood in
                HStack {
                    Text(mood.mood.capitalized)
                        .font(AMORTypography.captionFont)
                        .frame(width: 80, alignment: .leading)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(moodColor(mood.mood))
                            .frame(width: barWidth(mood.count, total: geo.size.width))
                            .frame(height: 16)
                    }
                    .frame(height: 16)

                    Text("\(mood.count)")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
    }

    private func barWidth(_ count: Int, total: CGFloat) -> CGFloat {
        return max(8, CGFloat(count) / CGFloat(maxCount) * (total - 120))
    }

    private func moodColor(_ mood: String) -> Color {
        switch mood.lowercased() {
        case "energized", "focused": return AMORColorPalette.sageGreen
        case "calm", "neutral": return AMORColorPalette.warmSand
        case "tired": return .gray
        case "stressed": return .red.opacity(0.7)
        default: return AMORColorPalette.twilightPurple
        }
    }
}

// MARK: - Streak Summary

struct StreakSummaryView: View {
    let stats: StreakStats

    var body: some View {
        AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Practice Streaks")
                    .font(AMORTypography.titleFont)
                    .foregroundStyle(AMORColorPalette.deepIndigo)

                HStack(spacing: 20) {
                    VStack {
                        Text("\(stats.activeCount)/\(stats.totalPractices)")
                            .font(.title2.bold())
                        Text("Active")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                        .frame(height: 40)

                    VStack {
                        Text("\(stats.longestStreak)")
                            .font(.title2.bold())
                        Text("Longest")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                        .frame(height: 40)

                    VStack {
                        Text("\(stats.dueTodayCount)")
                            .font(.title2.bold())
                            .foregroundStyle(stats.dueTodayCount > 0 ? .orange : .green)
                        Text("Due Today")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                // Progress bar
                if stats.totalPractices > 0 {
                    ProgressView(value: stats.activePercentage / 100)
                        .tint(stats.activePercentage >= 50 ? AMORColorPalette.sageGreen : AMORColorPalette.dawnOrange)
                        .frame(height: 6)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Insights") {
    NavigationStack {
        AMORInsightsView()
            .modelContainer(for: [Item.self, DailySession.self, PracticeStreak.self, CronJobHealth.self, DailySummary.self, SecondBrainEntry.self])
    }
}
#endif

// MARK: - Recovery Desk (v4.7.0)

/// Dispenses the streak-recovery medicine that AMORStreakIntelligence.recoveryActions()
/// has computed since v3.x but nothing ever rendered. Shows only when a practice
/// needs attention (due today / at risk / broken) — silent when all is well.
struct RecoveryDeskView: View {
    let actions: [String]

    var body: some View {
        if !actions.isEmpty {
            AMORComponents.ContemplativeCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Recovery Desk", systemImage: "lifepreserver")
                        .font(AMORTypography.titleFont)
                        .foregroundStyle(AMORColorPalette.deepIndigo)

                    Text("Your rhythm needs attention here — small moves now, streaks saved.")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)

                    ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(AMORColorPalette.dawnOrange)
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            Text(action)
                                .font(AMORTypography.captionFont)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Monthly Mirror (v4.7.0)

/// Renders the monthly aggregation that AMORProgressTracker.computeMonthlyReport()
/// has computed since forging but nothing ever displayed. The month-scale mirror
/// for a rhythm tracked daily.
struct MonthlyMirrorView: View {
    let report: MonthlyReport

    var body: some View {
        AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("This Month", systemImage: "calendar")
                        .font(AMORTypography.titleFont)
                        .foregroundStyle(AMORColorPalette.deepIndigo)
                    Spacer()
                    Text("\(report.monthName) \(report.year)")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [
                    GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())
                ], spacing: 12) {
                    MonthlyStat(value: "\(report.totalSessions)", label: "Sessions")
                    MonthlyStat(value: formatDuration(report.totalFocusMinutes), label: "Focus")
                    MonthlyStat(value: "\(report.totalTasksCompleted)", label: "Tasks")
                    MonthlyStat(value: "\(report.uniqueTools)", label: "Tools")
                    MonthlyStat(value: "\(report.uniqueSkills)", label: "Skills")
                    MonthlyStat(value: "\(report.activeDays)", label: "Active Days")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        return String(format: "%.1fh", Double(minutes) / 60.0)
    }
}

private struct MonthlyStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.primary)
            Text(label)
                .font(AMORTypography.captionFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
