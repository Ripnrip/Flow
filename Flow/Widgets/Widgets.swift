/**
 * 📱 FlowWidget — The Task-State Mirror
 *
 * "A glanceable reflection of your active focus session.
 * Every size tells the same truth: what you're working on right now."
 *
 * Supported widget families:
 *   .systemSmall         — emoji + title + elapsed timer
 *   .systemMedium        — above + Snooze / Done buttons (interactive)
 *   .systemLarge         — above + snooze count + style badge
 *   .accessoryCircular   — emoji, for Lock Screen / Watch
 *   .accessoryRectangular— title + timer, for Lock Screen / Watch
 *   .accessoryInline     — single-line emoji + title
 *
 * Data source: SharedTaskStore (App Groups UserDefaults)
 * Actions    : SnoozeIntent, DoneIntent (no app launch required)
 *
 * HIG ref: developer.apple.com/design/human-interface-guidelines/widgets
 * API ref: developer.apple.com/documentation/widgetkit
 */

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - 📅 Timeline Entry

struct FlowWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: ActiveTaskSnapshot?
    let configuration: FlowWidgetConfiguration

    /// Placeholder shown while WidgetKit renders for the first time.
    static var placeholder: FlowWidgetEntry {
        FlowWidgetEntry(
            date: .now,
            snapshot: ActiveTaskSnapshot(
                taskId: UUID().uuidString,
                title: "Review the codebase",
                emoji: "💻",
                styleRawValue: TaskStyle.cyberpunk.rawValue,
                snoozeCount: 1,
                moveCount: 2,
                startDate: Date().addingTimeInterval(-1800),
                growthLevel: 1,
                lastInteractionDate: .now,
                isCompleted: false
            ),
            configuration: FlowWidgetConfiguration()
        )
    }
}

// MARK: - 📡 Timeline Provider

struct FlowWidgetProvider: AppIntentTimelineProvider {
    typealias Entry  = FlowWidgetEntry
    typealias Intent = FlowWidgetConfiguration

    func placeholder(in context: Context) -> FlowWidgetEntry {
        FlowLogger.widget.info("📱 [FlowWidget] Generating placeholder")
        return .placeholder
    }

    func snapshot(for configuration: FlowWidgetConfiguration, in context: Context) async -> FlowWidgetEntry {
        FlowLogger.widget.info("📱 [FlowWidget] Generating snapshot")
        return await makeEntry(configuration: configuration)
    }

    func timeline(for configuration: FlowWidgetConfiguration, in context: Context) async -> Timeline<FlowWidgetEntry> {
        FlowLogger.widget.info("📱 [FlowWidget] Building timeline")
        let entry = await makeEntry(configuration: configuration)

        // Refresh more frequently when a task is actively running.
        let nextRefresh: Date
        if entry.snapshot != nil && !(entry.snapshot?.isCompleted ?? true) {
            nextRefresh = Date().addingTimeInterval(5 * 60) // 5 min while active
        } else {
            nextRefresh = Date().addingTimeInterval(60 * 60) // 1 hr when idle
        }

        FlowLogger.widget.info("📱 [FlowWidget] Next refresh: \(nextRefresh.formatted())")
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    // MARK: Private

    private func makeEntry(configuration: FlowWidgetConfiguration) async -> FlowWidgetEntry {
        let snapshot = await SharedTaskStore.shared.load()
        // Filter out completed tasks so the widget shows empty-state.
        let active = snapshot.flatMap { $0.isCompleted ? nil : $0 }
        return FlowWidgetEntry(date: .now, snapshot: active, configuration: configuration)
    }
}

// MARK: - 🖼️ Root Entry View

struct FlowWidgetEntryView: View {
    let entry: FlowWidgetEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        if let snapshot = entry.snapshot {
            activeView(snapshot)
        } else {
            emptyStateView
        }
    }

    // MARK: Active Task View (family-dispatched)

    @ViewBuilder
    private func activeView(_ snapshot: ActiveTaskSnapshot) -> some View {
        let style = snapshot.style
        switch family {
        case .accessoryCircular:
            accessoryCircularView(snapshot, style: style)
        case .accessoryRectangular:
            accessoryRectangularView(snapshot, style: style)
        case .accessoryInline:
            accessoryInlineView(snapshot)
        case .systemSmall:
            smallView(snapshot, style: style)
        case .systemMedium:
            mediumView(snapshot, style: style)
        case .systemLarge:
            largeView(snapshot, style: style)
        default:
            smallView(snapshot, style: style)
        }
    }

    // MARK: Accessory — Lock Screen / StandBy / Watch

    private func accessoryCircularView(_ snapshot: ActiveTaskSnapshot, style: TaskStyle) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            Text(snapshot.emoji)
                .font(.title2)
        }
        .widgetURL(FlowRoute.focus(taskId: UUID(uuidString: snapshot.taskId) ?? UUID()).customURL)
    }

    private func accessoryRectangularView(_ snapshot: ActiveTaskSnapshot, style: TaskStyle) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(snapshot.emoji).font(.caption)
                Text(snapshot.title)
                    .font(.caption.bold())
                    .lineLimit(1)
            }
            if entry.configuration.showElapsedTime {
                Text(snapshot.startDate, style: .timer)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL(FlowRoute.focus(taskId: UUID(uuidString: snapshot.taskId) ?? UUID()).customURL)
    }

    private func accessoryInlineView(_ snapshot: ActiveTaskSnapshot) -> some View {
        Label {
            Text(snapshot.title).lineLimit(1)
        } icon: {
            Text(snapshot.emoji)
        }
        .widgetURL(FlowRoute.focus(taskId: UUID(uuidString: snapshot.taskId) ?? UUID()).customURL)
    }

    // MARK: System Small

    private func smallView(_ snapshot: ActiveTaskSnapshot, style: TaskStyle) -> some View {
        ZStack(alignment: .bottomLeading) {
            StyleBackground(style: style)

            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.emoji)
                    .font(.largeTitle)
                    .symbolEffect(.pulse, isActive: true)

                Text(snapshot.title)
                    .font(style.themeFont(size: .subheadline))
                    .foregroundStyle(style.themeForegroundColor())
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                if entry.configuration.showElapsedTime {
                    Text(snapshot.startDate, style: .timer)
                        .font(.caption2.monospacedDigit().bold())
                        .foregroundStyle(style.themeAccentColor())
                }
            }
            .padding(12)
        }
        .containerBackground(style.themeBackgroundColor(), for: .widget)
        .widgetURL(FlowRoute.focus(taskId: UUID(uuidString: snapshot.taskId) ?? UUID()).customURL)
    }

    // MARK: System Medium

    private func mediumView(_ snapshot: ActiveTaskSnapshot, style: TaskStyle) -> some View {
        ZStack {
            StyleBackground(style: style)

            HStack(spacing: 12) {
                // Left: emoji + timer
                VStack(spacing: 8) {
                    Text(snapshot.emoji)
                        .font(.system(size: 40))
                    if entry.configuration.showElapsedTime {
                        Text(snapshot.startDate, style: .timer)
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(style.themeAccentColor())
                    }
                }
                .frame(maxWidth: 64)

                // Right: title + style badge + action buttons
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(style.rawValue.uppercased())
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(style.themeAccentColor())
                        Text(snapshot.title)
                            .font(style.themeFont(size: .subheadline))
                            .foregroundStyle(style.themeForegroundColor())
                            .lineLimit(2)
                    }

                    if entry.configuration.showActions {
                        HStack(spacing: 6) {
                            Button(intent: SnoozeIntent(taskId: snapshot.taskId)) {
                                Label("Snooze", systemImage: "bed.double.fill")
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .background(style.themeBackgroundColor().opacity(0.3))
                            .foregroundStyle(style.themeForegroundColor())
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            Button(intent: DoneIntent(taskId: snapshot.taskId)) {
                                Label("Done", systemImage: "checkmark.circle.fill")
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .background(style.themeAccentColor())
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
        }
        .containerBackground(style.themeBackgroundColor(), for: .widget)
        .widgetURL(FlowRoute.focus(taskId: UUID(uuidString: snapshot.taskId) ?? UUID()).customURL)
    }

    // MARK: System Large

    private func largeView(_ snapshot: ActiveTaskSnapshot, style: TaskStyle) -> some View {
        ZStack(alignment: .topLeading) {
            StyleBackground(style: style)

            VStack(alignment: .leading, spacing: 14) {
                // Header row
                HStack(spacing: 10) {
                    Text(snapshot.emoji).font(.system(size: 48))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(style.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(style.themeAccentColor())
                        Text(snapshot.title)
                            .font(style.themeFont(size: .title3))
                            .foregroundStyle(style.themeForegroundColor())
                            .lineLimit(2)
                    }
                }

                // Stats row
                HStack(spacing: 16) {
                    statPill(icon: "zzz", label: "Snoozed", value: "\(snapshot.snoozeCount)", style: style)
                    statPill(icon: "arrow.right.circle", label: "Moved", value: "\(snapshot.moveCount)", style: style)
                    if entry.configuration.showElapsedTime {
                        VStack(spacing: 1) {
                            Image(systemName: "timer")
                                .symbolEffect(.pulse)
                                .font(.caption2)
                                .foregroundStyle(style.themeAccentColor())
                            Text(snapshot.startDate, style: .timer)
                                .font(.caption2.monospacedDigit().bold())
                                .foregroundStyle(style.themeForegroundColor())
                        }
                    }
                }

                Spacer()

                // Action buttons
                if entry.configuration.showActions {
                    HStack(spacing: 10) {
                        Button(intent: SnoozeIntent(taskId: snapshot.taskId)) {
                            HStack(spacing: 6) {
                                Image(systemName: "bed.double.fill")
                                Text("Snooze")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                        .background(style.themeBackgroundColor().opacity(0.25))
                        .foregroundStyle(style.themeForegroundColor())
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(style.themeForegroundColor().opacity(0.15), lineWidth: 1)
                        )

                        Button(intent: DoneIntent(taskId: snapshot.taskId)) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .symbolEffect(.bounce, value: true)
                                Text(doneLabel(for: style))
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                        .background(style.themeAccentColor())
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(16)
        }
        .containerBackground(style.themeBackgroundColor(), for: .widget)
        .widgetURL(FlowRoute.focus(taskId: UUID(uuidString: snapshot.taskId) ?? UUID()).customURL)
    }

    // MARK: Empty State

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "target")
                .font(.title)
                .symbolEffect(.pulse)
                .foregroundStyle(.secondary)
            Text("No active task")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: Helpers

    private func statPill(icon: String, label: String, value: String, style: TaskStyle) -> some View {
        VStack(spacing: 1) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(style.themeAccentColor())
            Text(value)
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(style.themeForegroundColor())
        }
    }

    private func doneLabel(for style: TaskStyle) -> String {
        switch style {
        case .questMode:     return "Slay"
        case .magicalScroll: return "Cast"
        case .volcanicFlow:  return "Extinguish"
        case .livingGarden:  return "Harvest"
        case .spaceMission:  return "Deploy"
        case .courierPrime:  return "Delivered"
        default:             return "Done"
        }
    }
}

// MARK: - 📦 Widget Declaration

struct FlowWidget: Widget {
    let kind: String = "com.binarybros.Flow.FlowWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: FlowWidgetConfiguration.self,
            provider: FlowWidgetProvider()
        ) { entry in
            FlowWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Flow Task")
        .description("See your active focus task and act on it without opening the app.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
        .contentMarginsDisabled()
    }
}

// MARK: - 🧪 Previews

#Preview("Small — Active", as: .systemSmall) {
    FlowWidget()
} timeline: {
    FlowWidgetEntry.placeholder
    FlowWidgetEntry(date: .now, snapshot: nil, configuration: FlowWidgetConfiguration())
}

#Preview("Medium — Active", as: .systemMedium) {
    FlowWidget()
} timeline: {
    FlowWidgetEntry.placeholder
}

#Preview("Large — Active", as: .systemLarge) {
    FlowWidget()
} timeline: {
    FlowWidgetEntry.placeholder
}

#Preview("Accessory Circular", as: .accessoryCircular) {
    FlowWidget()
} timeline: {
    FlowWidgetEntry.placeholder
}

#Preview("Accessory Rectangular", as: .accessoryRectangular) {
    FlowWidget()
} timeline: {
    FlowWidgetEntry.placeholder
}
