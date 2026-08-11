/**
 * 🏠 AMORWidget — Home Screen & Lock Screen Widget Suite
 *
 * "AMOR's presence on the Home Screen — a living window into your
 *  daily rhythm. Streaks that breathe, sessions that accumulate,
 *  systems that whisper their health. Not a notification. A companion."
 *
 * v3.6.0 — AMOR Home Screen Widget Suite
 *
 * Widget Families:
 *   .systemSmall      — Today's briefing card (day, sessions, top streak)
 *   .systemMedium     — Today's dashboard (briefing + streaks row + cron pill)
 *   .accessoryCircular   — Streak flame count (Lock Screen / Watch)
 *   .accessoryRectangular — Day + sessions + practices (Lock Screen / Watch)
 *   .accessoryInline     — "3 sessions · 2/3 practices" (Lock Screen / Watch)
 *
 * Data source: AMORWidgetStore (App Groups UserDefaults)
 * Refresh: every 30 minutes + on app foreground writes
 */

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct AMORWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: AMORWidgetSnapshot?

    var hasData: Bool { snapshot != nil }
}

// MARK: - Timeline Provider

struct AMORWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> AMORWidgetEntry {
        AMORWidgetEntry(date: .now, snapshot: AMORWidgetProvider.previewSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (AMORWidgetEntry) -> Void) {
        let entry = AMORWidgetEntry(date: .now, snapshot: AMORWidgetStore.readSnapshot())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AMORWidgetEntry>) -> Void) {
        let entry = AMORWidgetEntry(date: .now, snapshot: AMORWidgetStore.readSnapshot())
        // Refresh every 30 minutes — the app also pushes updates on foreground
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    // Preview snapshot for placeholder rendering
    static func previewSnapshot() -> AMORWidgetSnapshot {
        AMORWidgetSnapshot(
            date: .now,
            dayString: "Tuesday, Aug 11",
            sessionCount: 3,
            totalFocusMinutes: 145,
            practicesCompleted: 2,
            practicesDue: 1,
            activeStreaks: [
                StreakSnapshot(name: "Gita", currentStreak: 42, longestStreak: 45, isCompletedToday: true, isDueToday: false),
                StreakSnapshot(name: "Gym", currentStreak: 12, longestStreak: 20, isCompletedToday: true, isDueToday: false),
                StreakSnapshot(name: "Meditation", currentStreak: 7, longestStreak: 15, isCompletedToday: false, isDueToday: true)
            ],
            cronHealthy: 10,
            cronFailed: 1,
            cronTotal: 11,
            briefingTitle: "3 sessions logged",
            briefingSubtitle: "2h 25m focus time",
            phase: "midday"
        )
    }
}

// MARK: - AMOR Widget Definition

struct AMORWidget: Widget {
    let kind: String = "AMORWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AMORWidgetProvider()) { entry in
            AMORWidgetView(entry: entry)
                .containerBackground(.fill, for: .widget)
        }
        .configurationDisplayName("AMOR")
        .description("Your daily operating rhythm — streaks, sessions, and system health at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Main Widget View (routes by family)

struct AMORWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AMORWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            AMORSmallWidget(snapshot: entry.snapshot)
        case .systemMedium:
            AMORMediumWidget(snapshot: entry.snapshot)
        case .accessoryCircular:
            AMORAccessoryCircular(snapshot: entry.snapshot)
        case .accessoryRectangular:
            AMORAccessoryRectangular(snapshot: entry.snapshot)
        case .accessoryInline:
            AMORAccessoryInline(snapshot: entry.snapshot)
        default:
            AMORSmallWidget(snapshot: entry.snapshot)
        }
    }
}

// MARK: - Small Widget (Home Screen)

struct AMORSmallWidget: View {
    let snapshot: AMORWidgetSnapshot?

    var body: some View {
        guard let snap = snapshot else {
            return AnyView(AMORWidgetPlaceholder())
        }
        return AnyView(content(snap))
    }

    private func content(_ snap: AMORWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: day + phase icon
            HStack {
                Text(snap.dayString)
                    .font(.system(.caption, design: .default, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                phaseIcon(snap.phase)
            }

            Spacer()

            // Focus time
            if snap.totalFocusMinutes > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundStyle(.tint)
                    Text(formattedDuration(snap.totalFocusMinutes))
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }

            // Sessions
            if snap.sessionCount > 0 {
                Text("\(snap.sessionCount) session\(snap.sessionCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Top streak
            if let topStreak = snap.activeStreaks.first {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("\(topStreak.currentStreak)")
                        .font(.system(.callout, design: .rounded, weight: .bold))
                    Text(topStreak.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // Cron health pill
            if snap.hasFailedCrons {
                HStack(spacing: 2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                    Text("\(snap.cronFailed) cron\(snap.cronFailed > 1 ? "s" : "") failing")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.red)
            }
        }
        .padding(4)
    }

    private func phaseIcon(_ phase: String) -> some View {
        let icon: String
        switch phase {
        case "morning": icon = "sunrise.fill"
        case "midday": icon = "sun.max.fill"
        case "afternoon": icon = "sun.haze.fill"
        case "evening": icon = "moon.stars.fill"
        case "night": icon = "zzz"
        default: icon = "circle.fill"
        }
        return Image(systemName: icon)
            .font(.caption)
            .foregroundStyle(.tint)
    }

    private func formattedDuration(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

// MARK: - Medium Widget (Home Screen)

struct AMORMediumWidget: View {
    let snapshot: AMORWidgetSnapshot?

    var body: some View {
        guard let snap = snapshot else {
            return AnyView(AMORWidgetPlaceholder())
        }
        return AnyView(content(snap))
    }

    private func content(_ snap: AMORWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snap.briefingTitle)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .lineLimit(1)
                    Text(snap.briefingSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                // Cron health ring
                cronHealthRing(snap)
            }

            Divider()

            // Streaks row
            HStack(spacing: 12) {
                ForEach(Array(snap.activeStreaks.prefix(4))) { streak in
                    VStack(spacing: 3) {
                        Image(systemName: streak.displayIcon)
                            .font(.title3)
                        Text("\(streak.currentStreak)")
                            .font(.system(.callout, design: .rounded, weight: .bold))
                        Text(streak.name)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(streak.isCompletedToday ? 1.0 : 0.5)
                    .overlay(
                        streak.isDueToday ?
                            Image(systemName: "circle.dotted")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange.opacity(0.6))
                                .offset(x: 18, y: -18)
                            : nil
                    )
                }
            }

            // Bottom: practices progress
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(snap.allPracticesDone ? .green : .secondary)
                Text(snap.allPracticesDone
                     ? "All \(snap.practicesCompleted) practices complete"
                     : "\(snap.practicesCompleted)/\(snap.practicesCompleted + snap.practicesDue) practices done")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if snap.sessionCount > 0 {
                    Text("\(snap.sessionCount)x")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.tint)
                }
            }
        }
        .padding(4)
    }

    private func cronHealthRing(_ snap: AMORWidgetSnapshot) -> some View {
        ZStack {
            Circle()
                .stroke(.tertiary, lineWidth: 3)
                .frame(width: 32, height: 32)
            Circle()
                .trim(from: 0, to: snap.cronHealthPercentage)
                .stroke(
                    snap.hasFailedCrons ? Color.red : Color.green,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 32, height: 32)
                .rotationEffect(.degrees(-90))
            Text("\(snap.cronHealthy)")
                .font(.system(size: 11, design: .rounded, weight: .bold))
        }
    }
}

// MARK: - Accessory Circular (Lock Screen / Watch)

struct AMORAccessoryCircular: View {
    let snapshot: AMORWidgetSnapshot?

    var body: some View {
        if let snap = snapshot, let topStreak = snap.activeStreaks.first {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .widgetAccentable()
                    Text("\(topStreak.currentStreak)")
                        .font(.system(size: 16, design: .rounded, weight: .bold))
                        .widgetAccentable()
                }
            }
        } else {
            AccessoryWidgetBackground()
            Image(systemName: "flame")
                .font(.title3)
        }
    }
}

// MARK: - Accessory Rectangular (Lock Screen / Watch)

struct AMORAccessoryRectangular: View {
    let snapshot: AMORWidgetSnapshot?

    var body: some View {
        if let snap = snapshot {
            VStack(alignment: .leading, spacing: 2) {
                Text(snap.dayString)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .widgetAccentable()
                if snap.totalFocusMinutes > 0 {
                    let h = snap.totalFocusMinutes / 60
                    let m = snap.totalFocusMinutes % 60
                    Text("\(snap.sessionCount) session\(snap.sessionCount == 1 ? "" : "s") - \(h > 0 ? "\(h)h " : "")\(m)m")
                        .font(.system(size: 11))
                } else {
                    Text("No sessions yet")
                        .font(.system(size: 11))
                }
                let total = snap.practicesCompleted + snap.practicesDue
                Text("\(snap.practicesCompleted)/\(total) practices")
                    .font(.system(size: 11))
                    .foregroundStyle(snap.allPracticesDone ? .green : .secondary)
            }
        } else {
            Text("AMOR")
                .font(.system(.caption, design: .serif))
        }
    }
}

// MARK: - Accessory Inline (Lock Screen / Watch)

struct AMORAccessoryInline: View {
    let snapshot: AMORWidgetSnapshot?

    var body: some View {
        if let snap = snapshot {
            let parts: [String] = [
                snap.sessionCount > 0 ? "\(snap.sessionCount)x" : nil,
                "\(snap.practicesCompleted)/\(snap.practicesCompleted + snap.practicesDue)",
                snap.hasFailedCrons ? "!\(snap.cronFailed)" : nil
            ].compactMap { $0 }
            Text(parts.isEmpty ? "AMOR" : parts.joined(separator: " - "))
        } else {
            Text("AMOR")
        }
    }
}

// MARK: - Placeholder (no data yet)

struct AMORWidgetPlaceholder: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.mind.and.body")
                .font(.title)
                .foregroundStyle(.tint)
            Text("AMOR")
                .font(.system(.title3, design: .serif, weight: .light))
            Text("Open Flow to begin")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
