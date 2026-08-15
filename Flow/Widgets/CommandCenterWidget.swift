/**
 * 🎛️ CommandCenterWidget — The Focus Mosaic
 *
 * "A configurable grid of summoning stones on the Home Screen and Lock Screen.
 *  Each tile is a focused deed: start a session, snooze, sync, or reveal stats.
 *  Tap a stone, and the intent awakens — no app launch required."
 *
 * Supported families:
 *   .systemMedium  — 2 command tiles side-by-side
 *   .systemLarge   — 4 command tiles in a 2×2 grid
 *
 * Data source: SharedTaskStore.commandTiles (App Groups)
 * Actions    : ExecuteCommandTileIntent
 *
 * - The Cosmic Mosaic Artisan
 */

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - ✨ Conditional Symbol Effect

/// 🎭 Applies the chosen tile animation only when the tile requests one.
/// WidgetKit shares the view tree with the main app, so we keep the modifier
/// simple and deterministic — no runtime type erasure required.
struct TileSymbolEffect: ViewModifier {
    let animation: CommandTileAnimation

    func body(content: Content) -> some View {
        switch animation {
        case .none:   content
        case .pulse:  content.symbolEffect(.pulse)
        case .bounce: content.symbolEffect(.bounce)
        case .wiggle: content.symbolEffect(.wiggle)
        case .rotate: content.symbolEffect(.rotate)
        }
    }
}

// MARK: - ⚙️ Widget Configuration Intent

/// 🎛️ Configuration knobs for each Command Center placement.
/// Currently lightweight; future fields can filter by tile set or accent theme.
struct CommandCenterConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Focus Command Center"
    static let description = IntentDescription("Quick actions and focus stats at a glance.")
}

// MARK: - 📅 Timeline Entry

struct CommandCenterEntry: TimelineEntry {
    let date: Date
    let tiles: [CommandTile]
    let configuration: CommandCenterConfiguration
}

// MARK: - 📡 Timeline Provider

struct CommandCenterProvider: AppIntentTimelineProvider {
    typealias Entry = CommandCenterEntry
    typealias Intent = CommandCenterConfiguration

    func placeholder(in context: Context) -> CommandCenterEntry {
        CommandCenterEntry(date: .now, tiles: defaultTiles, configuration: CommandCenterConfiguration())
    }

    func snapshot(for configuration: CommandCenterConfiguration, in context: Context) async -> CommandCenterEntry {
        let tiles = await SharedTaskStore.shared.loadCommandTiles()
        return CommandCenterEntry(
            date: .now,
            tiles: tiles.isEmpty ? defaultTiles : tiles,
            configuration: configuration
        )
    }

    func timeline(for configuration: CommandCenterConfiguration, in context: Context) async -> Timeline<CommandCenterEntry> {
        let tiles = await SharedTaskStore.shared.loadCommandTiles()
        let entry = CommandCenterEntry(
            date: .now,
            tiles: tiles.isEmpty ? defaultTiles : tiles,
            configuration: configuration
        )
        let nextUpdate = Date().addingTimeInterval(5 * 60)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    /// Fallback tiles shown before the user configures their command center.
    private var defaultTiles: [CommandTile] {
        [
            .focusOnTask(id: UUID(), title: "Deep Work", emoji: "🎯", style: .cyberpunk),
            .snooze(),
            .syncAll(),
            .showStats()
        ]
    }
}

// MARK: - 🖼️ Entry View

struct CommandCenterEntryView: View {
    let entry: CommandCenterEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let columns = family == .systemLarge ? 2 : 2
        let rows = family == .systemLarge ? 2 : 1
        let visibleTiles = Array(entry.tiles.prefix(columns * rows))

        GeometryReader { geometry in
            let spacing: CGFloat = family == .systemLarge ? 14 : 12
            let totalSpacing = spacing * CGFloat(columns - 1)
            let tileWidth = (geometry.size.width - totalSpacing) / CGFloat(columns)
            let tileHeight = (geometry.size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows)

            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<columns, id: \.self) { col in
                            let index = row * columns + col
                            if visibleTiles.indices.contains(index) {
                                CommandTileButton(
                                    tile: visibleTiles[index],
                                    index: index,
                                    size: CGSize(width: tileWidth, height: tileHeight)
                                )
                            } else {
                                EmptyTileView(size: CGSize(width: tileWidth, height: tileHeight))
                            }
                        }
                    }
                }
            }
        }
        .padding(family == .systemLarge ? 16 : 14)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - 🎛️ Individual Tile Button

struct CommandTileButton: View {
    let tile: CommandTile
    let index: Int
    let size: CGSize

    var body: some View {
        Button(intent: ExecuteCommandTileIntent(tileIndex: index)) {
            VStack(spacing: 6) {
                tileIcon

                Text(tile.title)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundStyle(tile.accentStyle.themeForegroundColor())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(width: size.width, height: size.height)
            .background(tile.accentStyle.themeBackgroundColor().opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(tile.accentStyle.themeAccentColor().opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var tileIcon: some View {
        if tile.isSFSymbol {
            Image(systemName: tile.icon)
                .font(.system(size: iconSize))
                .foregroundStyle(tile.accentStyle.themeAccentColor())
                .modifier(TileSymbolEffect(animation: tile.animation))
        } else {
            Text(tile.icon)
                .font(.system(size: iconSize))
                .foregroundStyle(tile.accentStyle.themeAccentColor())
        }
    }

    private var iconSize: CGFloat {
        min(size.width, size.height) * 0.32
    }

    private var fontSize: CGFloat {
        min(size.width, size.height) * 0.16
    }
}

// MARK: - ⬜ Empty Tile Placeholder

struct EmptyTileView: View {
    let size: CGSize

    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(.fill.quaternary)
            .frame(width: size.width, height: size.height)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.secondary.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - 📦 Widget Declaration

struct CommandCenterWidget: Widget {
    let kind: String = "com.binarybros.Flow.CommandCenter"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: CommandCenterConfiguration.self, provider: CommandCenterProvider()) { entry in
            CommandCenterEntryView(entry: entry)
        }
        .configurationDisplayName("Focus Command Center")
        .description("Quick actions for your focus session.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - 🧪 Previews

#Preview("Command Center — Medium", as: .systemMedium) {
    CommandCenterWidget()
} timeline: {
    CommandCenterEntry(
        date: .now,
        tiles: [
            .focusOnTask(id: UUID(), title: "Deep Work", emoji: "🎯", style: .cyberpunk),
            .snooze()
        ],
        configuration: CommandCenterConfiguration()
    )
}

#Preview("Command Center — Large", as: .systemLarge) {
    CommandCenterWidget()
} timeline: {
    CommandCenterEntry(
        date: .now,
        tiles: [
            .focusOnTask(id: UUID(), title: "Deep Work", emoji: "🎯", style: .cyberpunk),
            .snooze(),
            .syncAll(),
            .showStats()
        ],
        configuration: CommandCenterConfiguration()
    )
}
