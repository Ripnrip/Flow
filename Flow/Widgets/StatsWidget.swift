/**
 * 📊 StatsWidget — The Daily Focus Scoreboard
 *
 * "A glanceable dashboard of today's focus wins:
 *  total time, sessions, completed tasks, and streak.
 *  Each number is a tiny trophy for your attention."
 *
 * Supported families:
 *   .systemSmall  — big focus-time number + streak spark
 *   .systemMedium — 2×2 stat grid
 *   .systemLarge  — expanded grid + future mini-chart home
 *
 * Data source: SharedTaskStore.dailyFocusSummary (App Groups)
 *
 * - The Cosmic Scoreboard Keeper
 */

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - ⚙️ Widget Configuration

/// 🎛️ Knobs for each Stats placement. Light now, room for theme later.
struct StatsWidgetConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Focus Stats"
    static let description = IntentDescription("Today's focus summary at a glance.")
}

// MARK: - 📅 Timeline Entry

struct StatsWidgetEntry: TimelineEntry {
    let date: Date
    let summary: DailyFocusSummary
    let configuration: StatsWidgetConfiguration
}

// MARK: - 📡 Timeline Provider

struct StatsProvider: AppIntentTimelineProvider {
    typealias Entry = StatsWidgetEntry
    typealias Intent = StatsWidgetConfiguration

    func placeholder(in context: Context) -> StatsWidgetEntry {
        StatsWidgetEntry(date: .now, summary: .empty, configuration: StatsWidgetConfiguration())
    }

    func snapshot(for configuration: StatsWidgetConfiguration, in context: Context) async -> StatsWidgetEntry {
        let summary = await SharedTaskStore.shared.loadDailySummary()
        return StatsWidgetEntry(date: .now, summary: summary, configuration: configuration)
    }

    func timeline(for configuration: StatsWidgetConfiguration, in context: Context) async -> Timeline<StatsWidgetEntry> {
        let summary = await SharedTaskStore.shared.loadDailySummary()
        let entry = StatsWidgetEntry(date: .now, summary: summary, configuration: configuration)
        let nextUpdate = Date().addingTimeInterval(5 * 60)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// MARK: - 🖼️ Entry View

struct StatsWidgetEntryView: View {
    let entry: StatsWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .systemLarge:
            largeView
        default:
            smallView
        }
    }

    // MARK: - 🏆 Small: Hero number + streak spark
    private var smallView: some View {
        VStack(spacing: 4) {
            Text(entry.summary.formattedDuration)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                    .symbolEffect(.pulse)
                Text("\(entry.summary.streakDays)d")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - 🏅 Medium: Compact 2×2 stat grid
    private var mediumView: some View {
        HStack(spacing: 12) {
            statCell(value: entry.summary.formattedDuration, label: "Focused", icon: "clock.fill", color: .blue)
            statCell(value: "\(entry.summary.sessionsCount)", label: "Sessions", icon: "bolt.fill", color: .green)
            statCell(value: "\(entry.summary.completed)", label: "Done", icon: "checkmark.circle.fill", color: .purple)
            statCell(value: "\(entry.summary.streakDays)", label: "Streak", icon: "flame.fill", color: .orange)
        }
        .padding(.horizontal, 12)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - 🎖️ Large: Spacious dashboard grid
    private var largeView: some View {
        VStack(spacing: 16) {
            Text("Today's Focus")
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            HStack(spacing: 16) {
                statCell(value: entry.summary.formattedDuration, label: "Focused", icon: "clock.fill", color: .blue)
                statCell(value: "\(entry.summary.sessionsCount)", label: "Sessions", icon: "bolt.fill", color: .green)
            }

            HStack(spacing: 16) {
                statCell(value: "\(entry.summary.completed)", label: "Done", icon: "checkmark.circle.fill", color: .purple)
                statCell(value: "\(entry.summary.streakDays)", label: "Streak", icon: "flame.fill", color: .orange)
            }
        }
        .padding(16)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - 🧩 Reusable stat cell
    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .symbolEffect(.pulse)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 📦 Widget Declaration

struct StatsWidget: Widget {
    let kind: String = "com.binarybros.Flow.Stats"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: StatsWidgetConfiguration.self, provider: StatsProvider()) { entry in
            StatsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Focus Stats")
        .description("Today's focus time, sessions, completed tasks, and streak.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - 🧪 Previews

#Preview("Stats — Small", as: .systemSmall) {
    StatsWidget()
} timeline: {
    StatsWidgetEntry(
        date: .now,
        summary: DailyFocusSummary(totalFocusSeconds: 7420, sessionsCount: 3, snoozes: 1, completed: 2, streakDays: 5),
        configuration: StatsWidgetConfiguration()
    )
}

#Preview("Stats — Medium", as: .systemMedium) {
    StatsWidget()
} timeline: {
    StatsWidgetEntry(
        date: .now,
        summary: DailyFocusSummary(totalFocusSeconds: 7420, sessionsCount: 3, snoozes: 1, completed: 2, streakDays: 5),
        configuration: StatsWidgetConfiguration()
    )
}

#Preview("Stats — Large", as: .systemLarge) {
    StatsWidget()
} timeline: {
    StatsWidgetEntry(
        date: .now,
        summary: DailyFocusSummary(totalFocusSeconds: 7420, sessionsCount: 3, snoozes: 1, completed: 2, streakDays: 5),
        configuration: StatsWidgetConfiguration()
    )
}
