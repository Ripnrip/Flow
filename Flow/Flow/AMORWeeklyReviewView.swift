/**
 * 🧘 AMORWeeklyReviewView — Weekly Review & Streak Intelligence Dashboard
 *
 * "The seven-day mirror, made visible. Where the week's arc becomes
 * a narrative, where streaks reveal their secrets, and where the
 * contemplative mind finds its weekly reckoning."
 *
 * v3.4.0 — Weekly Review Automation & Streak Intelligence
 */

import SwiftUI
import SwiftData

// MARK: - Weekly Review View

struct AMORWeeklyReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [DailySession]
    /// v5.2.0: engine inputs as Foundation snapshots (engines never touch @Models).
    private var sessionsSnap: [AMORSessionSnapshot] { sessions.map { $0.snapshot } }
    @Query private var practices: [PracticeStreak]
    /// v5.2.0: engine inputs as Foundation snapshots (engines never touch @Models).
    private var practicesSnap: [AMORPracticeSnapshot] { practices.map { $0.snapshot } }
    @Query private var cronJobs: [CronJobHealth]
    /// v5.2.0: engine inputs as Foundation snapshots (engines never touch @Models).
    private var cronJobsSnap: [AMORCronJobSnapshot] { cronJobs.map { $0.snapshot } }
    @Query private var summaries: [DailySummary]
    /// v5.2.0: engine inputs as Foundation snapshots (engines never touch @Models).
    private var summariesSnap: [AMORDailySummarySnapshot] { summaries.map { $0.snapshot } }
    @Query private var reflections: [ReflectionEntry]
    /// v5.2.0: engine inputs as Foundation snapshots (engines never touch @Models).
    private var reflectionsSnap: [AMORReflectionSnapshot] { reflections.map { $0.snapshot } }

    @State private var summary: WeeklyReviewSummary?
    @State private var streakSummary: StreakSummary?
    @State private var milestones: [String] = []
    @State private var markdownPreview: String?
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Quality Score Hero
                if let summary = summary {
                    WeeklyHeroCard(summary: summary)
                }

                // Streak Intelligence
                if let streak = streakSummary {
                    StreakIntelligenceCard(streak: streak)
                }

                // Milestones
                if !milestones.isEmpty {
                    MilestoneCard(milestones: milestones)
                }

                // Week-over-Week Comparison
                if let summary = summary {
                    WoWComparisonCard(summary: summary)
                }

                // Daily Breakdown Chart
                if let summary = summary {
                    DailyBreakdownCard(summary: summary)
                }

                // Tools & Skills
                if let summary = summary {
                    if !summary.topTools.isEmpty || !summary.topSkills.isEmpty {
                        ToolsSkillsCard(summary: summary)
                    }
                }

                // Reflection Prompt
                if let summary = summary {
                    WeeklyReflectionPromptCard(summary: summary)
                }

                // Share / Export
                if markdownPreview != nil {
                    ShareWeeklyCard(showShareSheet: $showShareSheet)
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Weekly Review")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadData()
        }
        .sheet(isPresented: $showShareSheet) {
            if let markdown = markdownPreview {
                ShareSheetView(text: markdown)
            }
        }
    }

    private func loadData() {
        summary = AMORWeeklyReviewEngine.generateWeeklyReview(
            sessions: sessionsSnap,
            practices: practicesSnap,
            cronJobs: cronJobsSnap,
            summaries: summariesSnap,
            reflections: reflectionsSnap
        )
        streakSummary = AMORStreakIntelligence.generateSummary(practices: practices.map { $0.snapshot })
        milestones = AMORStreakIntelligence.detectMilestones(practices: practices.map { $0.snapshot })
        if let summary = summary {
            markdownPreview = AMORWeeklyReviewEngine.generateWeeklyMarkdown(summary: summary)
        }
    }
}

// MARK: - Weekly Hero Card

struct WeeklyHeroCard: View {
    let summary: WeeklyReviewSummary

    var body: some View {
        AMORComponents.ContemplativeCard {
            VStack(spacing: 16) {
                // Quality Score Ring
                HStack(spacing: 20) {
                    AMORComponents.ProgressRing(
                        progress: CGFloat(summary.qualityScore / 100.0),
                        size: 90,
                        lineWidth: 8
                    )
                    .overlay {
                        VStack {
                            Text(String(format: "%.0f", summary.qualityScore))
                                .font(AMORTypography.headingFont)
                                .foregroundStyle(AMORColorPalette.deepIndigo)
                            Text("Score")
                                .font(AMORTypography.captionFont)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(summary.isoWeekLabel)
                            .font(AMORTypography.headingFont)
                            .foregroundStyle(AMORColorPalette.deepIndigo)
                        Text(summary.trendDirection)
                            .font(AMORTypography.subtitleFont)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(formatDuration(summary.totalFocusMinutes))
                                    .font(.title2.bold())
                                    .foregroundStyle(AMORColorPalette.deepIndigo)
                                Text("Focus")
                                    .font(AMORTypography.captionFont)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(summary.totalSessions)")
                                    .font(.title2.bold())
                                    .foregroundStyle(AMORColorPalette.growth)
                                Text("Sessions")
                                    .font(AMORTypography.captionFont)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(summary.longestActiveStreak)")
                                    .font(.title2.bold())
                                    .foregroundStyle(AMORColorPalette.energy)
                                Text("Best Streak")
                                    .font(AMORTypography.captionFont)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Divider()

                // Narrative text
                Text(AMORWeeklyReviewEngine.generateWeeklyMarkdown(summary: summary)
                    .components(separatedBy: "## 🌅 The Week's Arc\n\n")[1]
                    .components(separatedBy: "\n\n")[0])
                    .font(AMORTypography.bodyFont)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(mins)m"
    }
}

// MARK: - Streak Intelligence Card

struct StreakIntelligenceCard: View {
    let streak: StreakSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🔥 Streak Intelligence")
                .font(AMORTypography.titleFont)
                .foregroundStyle(AMORColorPalette.deepIndigo)

            // Health headline
            HStack {
                Text(streak.healthEmoji)
                    .font(.largeTitle)

                VStack(alignment: .leading, spacing: 4) {
                    Text(streak.headline)
                        .font(AMORTypography.bodyFont.bold())
                        .foregroundStyle(.primary)
                    Text(streak.motivationalMessage)
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                        .italic()
                }

                Spacer()

                VStack {
                    Text(String(format: "%.0f", streak.overallHealthScore))
                        .font(.title.bold())
                        .foregroundStyle(scoreColor)
                    Text("Health")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))

            // Active streaks summary
            HStack(spacing: 16) {
                StreakMetric(value: "\(streak.activeStreaks)", label: "Active", color: AMORColorPalette.energy)
                StreakMetric(value: "\(streak.atRiskCount)", label: "At Risk", color: .orange)
                StreakMetric(value: "\(streak.brokenCount)", label: "Broken", color: .red)
                StreakMetric(value: "\(streak.longestStreak)", label: "Longest", color: AMORColorPalette.accomplishment)
            }

            // Priority insights
            ForEach(streak.insights.prefix(4)) { insight in
                InsightRow(insight: insight)
            }
        }
    }

    private var scoreColor: Color {
        switch streak.overallHealthScore {
        case 80...100: return .green
        case 60..<80: return AMORColorPalette.accomplishment
        case 40..<60: return .orange
        default: return .red
        }
    }
}

// MARK: - Streak Metric

struct StreakMetric: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(label)
                .font(AMORTypography.captionFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.1)))
    }
}

// MARK: - Insight Row

struct InsightRow: View {
    let insight: StreakInsight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(insight.riskLevel.emoji)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.message)
                    .font(AMORTypography.bodyFont)
                    .foregroundStyle(.primary)

                Text(insight.suggestion)
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)
                    .italic()
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Milestone Card

struct MilestoneCard: View {
    let milestones: [String]

    var body: some View {
        AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("🏆 Milestones")
                    .font(AMORTypography.titleFont)
                    .foregroundStyle(AMORColorPalette.deepIndigo)

                ForEach(milestones, id: \.self) { milestone in
                    Text(milestone)
                        .font(AMORTypography.bodyFont)
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Week-over-Week Comparison Card

struct WoWComparisonCard: View {
    let summary: WeeklyReviewSummary

    var body: some View {
        AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("📊 Week-over-Week")
                    .font(AMORTypography.titleFont)
                    .foregroundStyle(AMORColorPalette.deepIndigo)

                ComparisonRow(
                    label: "Sessions",
                    current: "\(summary.totalSessions)",
                    delta: summary.sessionsDelta,
                    unit: ""
                )
                ComparisonRow(
                    label: "Focus Time",
                    current: formatDuration(summary.totalFocusMinutes),
                    delta: summary.focusMinutesDelta,
                    unit: "m"
                )
                ComparisonRow(
                    label: "Practices",
                    current: "\(summary.totalPracticeCompletions)",
                    delta: summary.practicesDelta,
                    unit: ""
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 { return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h" }
        return "\(mins)m"
    }
}

struct ComparisonRow: View {
    let label: String
    let current: String
    let delta: Int
    let unit: String

    var body: some View {
        HStack {
            Text(label)
                .font(AMORTypography.bodyFont)
                .foregroundStyle(.secondary)

            Spacer()

            Text(current)
                .font(AMORTypography.bodyFont.bold())
                .foregroundStyle(.primary)

            Text(deltaText)
                .font(AMORTypography.captionFont)
                .foregroundStyle(deltaColor)
                .frame(width: 60, alignment: .trailing)
        }
    }

    private var deltaText: String {
        if delta > 0 { return "+\(delta)\(unit)" }
        if delta < 0 { return "\(delta)\(unit)" }
        return "—"
    }

    private var deltaColor: Color {
        if delta > 0 { return .green }
        if delta < 0 { return .red }
        return .secondary
    }
}

// MARK: - Daily Breakdown Card

struct DailyBreakdownCard: View {
    let summary: WeeklyReviewSummary

    var body: some View {
        AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("📅 Daily Breakdown")
                    .font(AMORTypography.titleFont)
                    .foregroundStyle(AMORColorPalette.deepIndigo)

                if let most = summary.mostProductiveDay {
                    Text("Most productive: **\(most)**")
                        .font(AMORTypography.bodyFont)
                        .foregroundStyle(.secondary)
                }

                // Bar chart
                let maxMinutes = summary.dailyFocusMinutes.max() ?? 1
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<7, id: \.self) { i in
                        VStack(spacing: 4) {
                            // Bar
                            RoundedRectangle(cornerRadius: 4)
                                .fill(barColor(for: i))
                                .frame(height: barHeight(for: i, max: maxMinutes))

                            // Label
                            Text(AMORWeeklyReviewEngine.weekdayName(index: i))
                                .font(AMORTypography.captionFont)
                                .foregroundStyle(.secondary)

                            // Value
                            Text("\(summary.dailySessionCounts[i])")
                                .font(.caption2)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 120)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func barHeight(for index: Int, max: Int) -> CGFloat {
        guard max > 0 else { return 2 }
        let value = summary.dailyFocusMinutes[index]
        return CGFloat(value) / CGFloat(max) * 80 + 2
    }

    private func barColor(for index: Int) -> Color {
        let minutes = summary.dailyFocusMinutes[index]
        if minutes == 0 { return AMORColorPalette.charcoal.opacity(0.1) }
        if minutes >= 120 { return AMORColorPalette.energy }
        if minutes >= 60 { return AMORColorPalette.growth }
        return AMORColorPalette.twilightPurple
    }
}

// MARK: - Tools & Skills Card

struct ToolsSkillsCard: View {
    let summary: WeeklyReviewSummary

    var body: some View {
        AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 12) {
                if !summary.topTools.isEmpty {
                    Text("🔧 Top Tools")
                        .font(AMORTypography.titleFont)
                        .foregroundStyle(AMORColorPalette.deepIndigo)

                    ForEach(summary.topTools, id: \.self) { tool in
                        HStack {
                            Image(systemName: "wrench.fill")
                                .foregroundStyle(AMORColorPalette.twilightPurple)
                                .font(.caption)
                            Text(tool)
                                .font(AMORTypography.bodyFont)
                        }
                    }
                }

                if !summary.topSkills.isEmpty {
                    Divider()
                        .padding(.vertical, 4)

                    Text("🌱 Skills Developed")
                        .font(AMORTypography.titleFont)
                        .foregroundStyle(AMORColorPalette.deepIndigo)

                    ForEach(summary.topSkills, id: \.self) { skill in
                        HStack {
                            Image(systemName: "leaf.fill")
                                .foregroundStyle(AMORColorPalette.growth)
                                .font(.caption)
                            Text(skill)
                                .font(AMORTypography.bodyFont)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Weekly Reflection Prompt

struct WeeklyReflectionPromptCard: View {
    let summary: WeeklyReviewSummary

    @State private var reflectionText = ""

    var body: some View {
        AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("🪞 Weekly Reflection")
                    .font(AMORTypography.titleFont)
                    .foregroundStyle(AMORColorPalette.deepIndigo)

                // Extract the reflection prompt from markdown
                let narrativeParts = AMORWeeklyReviewEngine.generateWeeklyMarkdown(summary: summary)
                    .components(separatedBy: "## 🪞 Reflection\n\n")
                if narrativeParts.count > 1 {
                    Text(narrativeParts[1].trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(AMORTypography.bodyFont)
                        .italic()
                        .foregroundStyle(AMORColorPalette.deepIndigo)
                }

                TextEditor(text: $reflectionText)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AMORColorPalette.softClay, lineWidth: 1)
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Share Weekly Card

struct ShareWeeklyCard: View {
    @Binding var showShareSheet: Bool

    var body: some View {
        Button {
            showShareSheet = true
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share Weekly Review")
            }
            .font(AMORTypography.bodyFont.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(AMORColorPalette.deepIndigo))
        }
    }
}

// MARK: - Streak Dashboard Compact Card (for Dashboard tab)

struct StreakIntelligenceCompactCard: View {
    @Query private var practices: [PracticeStreak]
    /// v5.2.0: engine inputs as Foundation snapshots (engines never touch @Models).
    private var practicesSnap: [AMORPracticeSnapshot] { practices.map { $0.snapshot } }

    @State private var streakSummary: StreakSummary?

    var body: some View {
        if let streak = streakSummary {
            AMORComponents.ContemplativeCard {
                HStack {
                    Text(streak.healthEmoji)
                        .font(.largeTitle)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(streak.headline)
                            .font(AMORTypography.bodyFont.bold())
                            .foregroundStyle(.primary)
                        if streak.atRiskCount > 0 {
                            Text("⚠️ \(streak.atRiskCount) need attention today")
                                .font(AMORTypography.captionFont)
                                .foregroundStyle(.orange)
                        }
                    }

                    Spacer()

                    VStack {
                        Text(String(format: "%.0f", streak.overallHealthScore))
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                        Text("Streak Health")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear {
                if streakSummary == nil {
                    streakSummary = AMORStreakIntelligence.generateSummary(practices: practices.map { $0.snapshot })
                }
            }
        }
    }
}
