//
//  AMORSessionDumpViews.swift
//  Flow — AMOR v5.2.0
//
//  Split from AMORSessionDumpAutomation.swift in v5.2.0 (The Full
//  Illumination): the engine is Foundation-only and compiles into the
//  live-fire harness; the views stay SwiftUI. Mirror of the v5.0.0
//  AMORPracticeSnapshot split.
//

import SwiftUI

// MARK: - Dashboard Card

/// Compact dashboard card showing the latest auto-dump status.
/// Placed on the Today tab so the user can see their daily dump at a glance.
struct AutoDumpStatusCard: View {
    @State private var automation = AMORSessionDumpAutomation()
    @State private var latestSnapshot: ProgressSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(AMORColorPalette.deepIndigo)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Dump")
                        .font(AMORTypography.bodyFont.bold())
                    Text(automation.isAvailable ? "Auto-generated daily" : "Dump directory unavailable")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let snapshot = latestSnapshot {
                    VStack(alignment: .trailing) {
                        Text("\(snapshot.sessionCount)")
                            .font(AMORTypography.titleFont.bold())
                            .foregroundStyle(AMORColorPalette.deepIndigo)
                        Text("sessions")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let snapshot = latestSnapshot {
                HStack(spacing: 16) {
                    dumpMetric(
                        icon: "clock.fill",
                        value: Self.formatFocus(snapshot.totalFocusMinutes),
                        label: "Focus"
                    )
                    Divider().frame(height: 30)
                    dumpMetric(
                        icon: "checkmark.circle.fill",
                        value: "\(snapshot.tasksCompleted)",
                        label: "Tasks"
                    )
                    Divider().frame(height: 30)
                    dumpMetric(
                        icon: "flame.fill",
                        value: "\(snapshot.activeStreaks)",
                        label: "Streaks"
                    )
                    Divider().frame(height: 30)
                    dumpMetric(
                        icon: "heart.fill",
                        value: String(format: "%.0f%%", snapshot.cronHealthPercentage),
                        label: "Health"
                    )
                }

                if !snapshot.topTools.isEmpty {
                    HStack {
                        Text("Top tools:")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                        ForEach(snapshot.topTools.prefix(3), id: \.self) { tool in
                            Text(tool)
                                .font(AMORTypography.captionFont)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.thinMaterial)
                                .clipShape(Capsule())
                        }
                    }
                }
            } else if automation.isAvailable {
                Text("No dumps generated yet. Sessions will be captured automatically.")
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            latestSnapshot = automation.loadLatestSnapshot()
        }
    }

    private func dumpMetric(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(AMORColorPalette.deepIndigo)
            Text(value)
                .font(AMORTypography.captionFont.bold())
            Text(label)
                .font(AMORTypography.captionFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private static func formatFocus(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let mins = minutes % 60
        return mins == 0 ? "\(hours)h" : "\(hours)h\(mins)"
    }
}

// MARK: - Progress Timeline View

/// A timeline view showing the last 14 days of progress snapshots.
/// Accessed from the Review tab sub-navigation.
struct AMORProgressTimelineView: View {
    @State private var automation = AMORSessionDumpAutomation()
    @State private var snapshots: [ProgressSnapshot] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if snapshots.isEmpty {
                        ContentUnavailableView(
                            "No Progress Data",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text("Progress snapshots are generated automatically when you open AMOR.")
                        )
                        .padding(.top, 40)
                    } else {
                        // Weekly average card
                        if snapshots.count >= 7 {
                            weeklyAverageCard
                        }

                        // Timeline
                        Text("Daily Timeline")
                            .font(AMORTypography.titleFont)
                            .foregroundStyle(AMORColorPalette.deepIndigo)
                            .padding(.top, 8)

                        ForEach(snapshots.prefix(30)) { snapshot in
                            ProgressSnapshotRow(snapshot: snapshot)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Progress Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                snapshots = automation.loadProgressSnapshots()
            }
        }
    }

    private var weeklyAverageCard: some View {
        let recent7 = Array(snapshots.prefix(7))
        let avgSessions = recent7.reduce(0) { $0 + $1.sessionCount } / recent7.count
        let avgMinutes = recent7.reduce(0) { $0 + $1.totalFocusMinutes } / recent7.count
        let totalTasks = recent7.reduce(0) { $0 + $1.tasksCompleted }
        let avgPractices = recent7.reduce(0) { $0 + $1.practicesCompleted } / recent7.count

        return AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("7-Day Average")
                    .font(AMORTypography.titleFont)
                    .foregroundStyle(AMORColorPalette.deepIndigo)

                HStack {
                    weeklyStat(value: "\(avgSessions)", label: "Sessions/day")
                    Divider().frame(height: 40)
                    weeklyStat(value: Self.formatFocus(avgMinutes), label: "Focus/day")
                    Divider().frame(height: 40)
                    weeklyStat(value: "\(totalTasks)", label: "Tasks (7d)")
                    Divider().frame(height: 40)
                    weeklyStat(value: "\(avgPractices)", label: "Practices/day")
                }
            }
        }
    }

    private func weeklyStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AMORTypography.titleFont.bold())
                .foregroundStyle(AMORColorPalette.deepIndigo)
            Text(label)
                .font(AMORTypography.captionFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private static func formatFocus(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        return String(format: "%.1fh", Double(minutes) / 60.0)
    }
}

// MARK: - Progress Snapshot Row

struct ProgressSnapshotRow: View {
    let snapshot: ProgressSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(snapshot.formattedDate)
                    .font(AMORTypography.bodyFont.bold())

                Spacer()

                // Mood indicator
                Text(moodEmoji)
                    .font(.title3)
            }

            HStack(spacing: 12) {
                metricBadge(icon: "clock", value: "\(snapshot.totalFocusMinutes)m", color: AMORColorPalette.deepIndigo)
                metricBadge(icon: "doc.text", value: "\(snapshot.sessionCount)", color: AMORColorPalette.growth)
                metricBadge(icon: "checkmark.circle", value: "\(snapshot.tasksCompleted)", color: AMORColorPalette.accomplishment)
                metricBadge(icon: "flame.fill", value: "\(snapshot.practicesCompleted)", color: AMORColorPalette.energy)
            }

            if !snapshot.topTools.isEmpty {
                HStack(spacing: 4) {
                    ForEach(snapshot.topTools.prefix(4), id: \.self) { tool in
                        Text(tool)
                            .font(AMORTypography.captionFont)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var moodEmoji: String {
        switch snapshot.mood.lowercased() {
        case "energized", "happy": return "⚡"
        case "focused": return "🎯"
        case "calm": return "🧘"
        case "tired": return "😴"
        case "stressed": return "😰"
        case "neutral": return "⚪"
        default: return "📝"
        }
    }

    private func metricBadge(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(value)
                .font(AMORTypography.captionFont.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}
