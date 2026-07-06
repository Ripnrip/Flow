/**
 * 🎛️ CommandTile — The Summoning Stone
 *
 * "A single, configurable tile in the great command mosaic.
 *  Each stone carries an intent: start focus, snooze, complete,
 *  or reach beyond the app itself into URLs and Shortcuts."
 *
 * - The Cosmic Command Center Architect
 */

import Foundation
import SwiftUI

// MARK: - 🎬 Tile Animation Flavors

/// The animation personality of a command tile.
/// Kept as a plain String-backed enum so it survives the App Groups bridge.
enum CommandTileAnimation: String, Codable, Sendable, CaseIterable {
    case none    = "none"
    case pulse   = "pulse"
    case bounce  = "bounce"
    case wiggle  = "wiggle"
    case rotate  = "rotate"
}

// MARK: - 🎯 Tile Action Verbs

/// The universe of actions a command tile can perform.
/// Each case is a verb the system can invoke without opening Flow.
enum CommandTileAction: String, Codable, Sendable, CaseIterable {
    case startFocus   = "startFocus"
    case snooze       = "snooze"
    case complete     = "complete"
    case openInbox    = "openInbox"
    case syncAll      = "syncAll"
    case showStats    = "showStats"
    case openURL      = "openURL"
    case runShortcut  = "runShortcut"

    /// Human-readable title used in the editor and Shortcuts.
    var displayTitle: String {
        switch self {
        case .startFocus:  return "Start Focus"
        case .snooze:      return "Snooze"
        case .complete:    return "Complete"
        case .openInbox:   return "Open Inbox"
        case .syncAll:     return "Sync All"
        case .showStats:   return "Show Stats"
        case .openURL:     return "Open URL"
        case .runShortcut: return "Run Shortcut"
        }
    }

    /// Default SF Symbol for each action.
    var defaultIcon: String {
        switch self {
        case .startFocus:  return "target"
        case .snooze:      return "bed.double.fill"
        case .complete:    return "checkmark.circle.fill"
        case .openInbox:   return "tray.full.fill"
        case .syncAll:     return "arrow.triangle.2.circlepath"
        case .showStats:   return "chart.bar.fill"
        case .openURL:     return "link"
        case .runShortcut: return "bolt.fill"
        }
    }
}

// MARK: - 🎛️ The Tile Itself

/// A lightweight, cross-process command tile.
/// Lives in SwiftData (in-app editor) and is mirrored to App Groups for widgets.
struct CommandTile: Identifiable, Codable, Sendable, Hashable {

    var id: UUID
    var title: String
    var icon: String
    var action: CommandTileAction
    var targetTaskID: String?   // UUID string when action == .startFocus
    var accentStyleRawValue: String
    var animation: CommandTileAnimation
    var isSFSymbol: Bool        // false = emoji, true = SF Symbol name
    var payload: String?        // URL string or Shortcut name for openURL/runShortcut

    var accentStyle: TaskStyle {
        get {
            TaskStyle(rawValue: accentStyleRawValue) ?? .sleekModern
        }
        set {
            accentStyleRawValue = newValue.rawValue
        }
    }

    init(
        id: UUID = UUID(),
        title: String,
        icon: String,
        action: CommandTileAction,
        targetTaskID: String? = nil,
        accentStyle: TaskStyle = .sleekModern,
        animation: CommandTileAnimation = .pulse,
        isSFSymbol: Bool = true,
        payload: String? = nil
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.action = action
        self.targetTaskID = targetTaskID
        self.accentStyleRawValue = accentStyle.rawValue
        self.animation = animation
        self.isSFSymbol = isSFSymbol
        self.payload = payload
    }
}

// MARK: - 🏭 Preset Tiles

extension CommandTile {

    /// Focus on a specific task — the hero stone of the command center.
    static func focusOnTask(
        id: UUID,
        title: String,
        emoji: String,
        style: TaskStyle
    ) -> CommandTile {
        CommandTile(
            title: title,
            icon: emoji,
            action: .startFocus,
            targetTaskID: id.uuidString,
            accentStyle: style,
            animation: .pulse,
            isSFSymbol: false
        )
    }

    /// The gentle postponement ritual.
    static func snooze(accentStyle: TaskStyle = .volcanicFlow) -> CommandTile {
        CommandTile(
            title: "Snooze",
            icon: CommandTileAction.snooze.defaultIcon,
            action: .snooze,
            accentStyle: accentStyle,
            animation: .wiggle
        )
    }

    /// The triumphant completion ritual.
    static func complete(accentStyle: TaskStyle = .livingGarden) -> CommandTile {
        CommandTile(
            title: "Done",
            icon: CommandTileAction.complete.defaultIcon,
            action: .complete,
            accentStyle: accentStyle,
            animation: .bounce
        )
    }

    /// Open the Flow inbox from anywhere.
    static func openInbox() -> CommandTile {
        CommandTile(
            title: "Inbox",
            icon: CommandTileAction.openInbox.defaultIcon,
            action: .openInbox,
            accentStyle: .cyberpunk,
            animation: .none
        )
    }

    /// Pull fresh tasks from Calendar, Reminders, Todoist, and FlowServer.
    static func syncAll() -> CommandTile {
        CommandTile(
            title: "Sync",
            icon: CommandTileAction.syncAll.defaultIcon,
            action: .syncAll,
            accentStyle: .oceanFlow,
            animation: .rotate
        )
    }

    /// Reveal today’s focus statistics.
    static func showStats() -> CommandTile {
        CommandTile(
            title: "Stats",
            icon: CommandTileAction.showStats.defaultIcon,
            action: .showStats,
            accentStyle: .cosmicNebula,
            animation: .pulse
        )
    }

    /// Open an arbitrary URL — perfect for deep-linking to Notion, Slack, etc.
    static func openURL(_ urlString: String, title: String = "Open Link") -> CommandTile {
        CommandTile(
            title: title,
            icon: CommandTileAction.openURL.defaultIcon,
            action: .openURL,
            accentStyle: .sleekModern,
            animation: .none,
            payload: urlString
        )
    }

    /// Run a named iOS Shortcut.
    static func runShortcut(_ name: String) -> CommandTile {
        CommandTile(
            title: name,
            icon: CommandTileAction.runShortcut.defaultIcon,
            action: .runShortcut,
            accentStyle: .solarFlare,
            animation: .bounce,
            payload: name
        )
    }
}
