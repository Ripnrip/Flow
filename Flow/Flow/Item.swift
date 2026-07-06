/**
 * 🎭 The Item - The Vessel of Purpose
 *
 * "A singular point in the stream of time, carrying the weight of intention.
 * It tracks its own journey—the delays, the shifts, and the moments of focus."
 *
 * - The Spellbinding Museum Director of Tasks
 */

import Foundation
import OSLog
import SwiftData

@Model
final class Item {
    // 🌟 Identity and conformance to TaskProtocol
    var id: UUID = UUID()
    var title: String
    var emoji: String = "🎯"

    // 🎨 Style stored as String for SwiftData compatibility, accessed via computed property
    var styleRawValue: String = TaskStyle.sleekModern.rawValue

    var style: TaskStyle {
        get {
            TaskStyle(rawValue: styleRawValue) ?? .sleekModern
        }
        set {
            styleRawValue = newValue.rawValue
        }
    }

    var timestamp: Date
    var isCompleted: Bool = false

    // 📊 Analytics: Tracking the lingering soul of the task
    var snoozeCount: Int = 0
    var moveCount: Int = 0

    // ⏳ Temporal markers
    var creationDate: Date
    var lastInteractionDate: Date

    // 🔗 External source linkage (e.g., SuperProductivity task UUID)
    var externalSourceId: String?
    var externalSourceType: String?

    // ✨ Total time the task has 'lingered' in the active state (in seconds)
    var totalLingeringTime: TimeInterval = 0

    // 🌱 Growth logic for styles like Living Garden
    var growthLevel: Int {
        if style == .livingGarden || style == .magicalForest {
            // Growth thresholds in seconds (e.g., 5 mins, 15 mins, 30 mins)
            if totalLingeringTime > 1800 { return 3 }      // 🍎 Mature/Fruit
            else if totalLingeringTime > 900 { return 2 }   // 🌳 Tree
            else if totalLingeringTime > 300 { return 1 }   // 🌿 Plant
            else { return 0 }                               // 🌱 Seedling
        }
        return 0
    }

    init(title: String = "New Task", emoji: String = "🎯", style: TaskStyle = .sleekModern, timestamp: Date = .now) {
        self.title = title
        self.emoji = emoji
        self.styleRawValue = style.rawValue
        self.timestamp = timestamp
        self.creationDate = .now
        self.lastInteractionDate = .now
        FlowLogger.task.debug("🌟 New item crystallized: \(title, privacy: .public) [\(self.style.rawValue, privacy: .public)]")
    }

    // 🌟 The Alchemy of Postponement - When a task is snoozed
    /// Records one or more snooze gestures without changing lingering time.
    ///
    /// TaskService owns time accounting through `TaskLingeringActor`, so this
    /// method only updates interaction metadata and counters. Keeping the timer
    /// out of the model prevents a single snooze from being counted twice — the
    /// bug goblin tried to invoice us twice, and we politely declined. 🧾✨
    func snooze(times count: Int = 1, at date: Date = .now) {
        let safeCount = max(0, count)
        guard safeCount > 0 else {
            FlowLogger.task.debug("🌙 Snooze skipped for '\(self.title, privacy: .public)' because count was zero")
            return
        }

        snoozeCount += safeCount
        lastInteractionDate = date
        FlowLogger.task.info("🌙 Snooze recorded for '\(self.title, privacy: .public)' (+\(safeCount), count=\(self.snoozeCount))")
    }

    // 🎨 The Dance of Priorities - When a task is moved
    /// Records one move gesture without changing lingering time.
    ///
    /// Movement is an analytics event, while elapsed focus time is measured by
    /// `TaskLingeringActor`; separating them keeps counters crisp and avoids
    /// temporal soup. Chronos brought a ladle anyway. 🥣⏳
    func move(at date: Date = .now) {
        moveCount += 1
        lastInteractionDate = date
        FlowLogger.task.info("🎪 Move recorded for '\(self.title, privacy: .public)' (count=\(self.moveCount))")
    }
}
