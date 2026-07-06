/**
 * 📌 PinnedTasksWidget — The Focus Launchpad
 *
 * "Pinned missions, one tap away. Each row is a promise:
 *  Focus to begin, Done to finish, or tap the body to open Flow.
 *  The launchpad never sleeps — it waits, ready for your next move."
 *
 * Supported families:
 *   .systemMedium — up to 2 pinned tasks
 *   .systemLarge  — up to 4 pinned tasks
 *
 * Data source: SharedTaskStore.pinnedTasks (App Groups)
 * Actions    : StartPinnedTaskIntent, CompletePinnedTaskIntent, OpenInboxIntent
 *
 * - The Cosmic Launchpad Keeper
 */

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - ⚙️ Widget Configuration

/// 🎛️ Configuration for each Pinned Tasks placement.
struct PinnedTasksWidgetConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Pinned Tasks"
    static let description = IntentDescription("Quick actions for your pinned Flow tasks.")
}

// MARK: - 📅 Timeline Entry

struct PinnedTasksWidgetEntry: TimelineEntry {
    let date: Date
    let tasks: [PinnedTaskSnapshot]
    let configuration: PinnedTasksWidgetConfiguration
}

// MARK: - 📡 Timeline Provider

struct PinnedTasksProvider: AppIntentTimelineProvider {
    typealias Entry = PinnedTasksWidgetEntry
    typealias Intent = PinnedTasksWidgetConfiguration

    func placeholder(in context: Context) -> PinnedTasksWidgetEntry {
        PinnedTasksWidgetEntry(date: .now, tasks: placeholderTasks, configuration: PinnedTasksWidgetConfiguration())
    }

    func snapshot(for configuration: PinnedTasksWidgetConfiguration, in context: Context) async -> PinnedTasksWidgetEntry {
        let tasks = await SharedTaskStore.shared.loadPinnedTasks()
        return PinnedTasksWidgetEntry(date: .now, tasks: tasks.isEmpty ? placeholderTasks : tasks, configuration: configuration)
    }

    func timeline(for configuration: PinnedTasksWidgetConfiguration, in context: Context) async -> Timeline<PinnedTasksWidgetEntry> {
        let tasks = await SharedTaskStore.shared.loadPinnedTasks()
        let entry = PinnedTasksWidgetEntry(date: .now, tasks: tasks.isEmpty ? placeholderTasks : tasks, configuration: configuration)
        let nextUpdate = Date().addingTimeInterval(5 * 60)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    /// Demo tasks shown before the user pins anything.
    private var placeholderTasks: [PinnedTaskSnapshot] {
        [
            PinnedTaskSnapshot(taskId: UUID().uuidString, title: "Deep Work", emoji: "🎯", styleRawValue: TaskStyle.cyberpunk.rawValue, isCompleted: false),
            PinnedTaskSnapshot(taskId: UUID().uuidString, title: "Email", emoji: "📧", styleRawValue: TaskStyle.sleekModern.rawValue, isCompleted: false)
        ]
    }
}

// MARK: - 🖼️ Entry View

struct PinnedTasksEntryView: View {
    let entry: PinnedTasksWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var maxTasks: Int {
        family == .systemLarge ? 4 : 2
    }

    var body: some View {
        let visible = Array(entry.tasks.prefix(maxTasks))
        VStack(spacing: 8) {
            ForEach(Array(visible.enumerated()), id: \.offset) { index, task in
                PinnedTaskRow(task: task, index: index)
            }
        }
        .padding(family == .systemLarge ? 14 : 12)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - 📌 Individual Row

struct PinnedTaskRow: View {
    let task: PinnedTaskSnapshot
    let index: Int

    var body: some View {
        Button(intent: OpenInboxIntent()) {
            HStack(spacing: 10) {
                Text(task.emoji)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(task.isCompleted ? "Done" : "Ready to focus")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !task.isCompleted {
                    HStack(spacing: 6) {
                        Button(intent: StartPinnedTaskIntent(taskIndex: index)) {
                            Image(systemName: "play.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(task.style.themeAccentColor()))
                        }
                        .buttonStyle(.plain)

                        Button(intent: CompletePinnedTaskIntent(taskIndex: index)) {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(.green))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(task.style.themeBackgroundColor().opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 📦 Widget Declaration

struct PinnedTasksWidget: Widget {
    let kind: String = "com.binarybros.Flow.PinnedTasks"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: PinnedTasksWidgetConfiguration.self, provider: PinnedTasksProvider()) { entry in
            PinnedTasksEntryView(entry: entry)
        }
        .configurationDisplayName("Pinned Tasks")
        .description("Focus on or complete your pinned Flow tasks.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - 🧪 Previews

#Preview("Pinned Tasks — Medium", as: .systemMedium) {
    PinnedTasksWidget()
} timeline: {
    PinnedTasksWidgetEntry(
        date: .now,
        tasks: [
            PinnedTaskSnapshot(taskId: UUID().uuidString, title: "Deep Work", emoji: "🎯", styleRawValue: TaskStyle.cyberpunk.rawValue, isCompleted: false),
            PinnedTaskSnapshot(taskId: UUID().uuidString, title: "Email", emoji: "📧", styleRawValue: TaskStyle.sleekModern.rawValue, isCompleted: false)
        ],
        configuration: PinnedTasksWidgetConfiguration()
    )
}

#Preview("Pinned Tasks — Large", as: .systemLarge) {
    PinnedTasksWidget()
} timeline: {
    PinnedTasksWidgetEntry(
        date: .now,
        tasks: [
            PinnedTaskSnapshot(taskId: UUID().uuidString, title: "Deep Work", emoji: "🎯", styleRawValue: TaskStyle.cyberpunk.rawValue, isCompleted: false),
            PinnedTaskSnapshot(taskId: UUID().uuidString, title: "Email", emoji: "📧", styleRawValue: TaskStyle.sleekModern.rawValue, isCompleted: false),
            PinnedTaskSnapshot(taskId: UUID().uuidString, title: "Workout", emoji: "💪", styleRawValue: TaskStyle.retroPixel.rawValue, isCompleted: true),
            PinnedTaskSnapshot(taskId: UUID().uuidString, title: "Read", emoji: "📚", styleRawValue: TaskStyle.organicNature.rawValue, isCompleted: false)
        ],
        configuration: PinnedTasksWidgetConfiguration()
    )
}
