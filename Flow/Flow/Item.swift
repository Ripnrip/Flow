/**
 * 🎭 The Item - The Vessel of Purpose
 *
 * "A singular point in the stream of time, carrying the weight of intention.
 * It tracks its own journey—the delays, the shifts, and the moments of focus."
 *
 * - The Spellbinding Museum Director of Tasks
 */

import Foundation
import SwiftData

@Model
final class Item: TaskProtocol {
    // 🌟 Identity and conformance to TaskProtocol
    var id: UUID = UUID()
    var title: String
    var emoji: String = "🎯"
    var style: TaskStyle = TaskStyle.sleekModern
    var timestamp: Date
    var isCompleted: Bool = false

    // 📊 Analytics: Tracking the lingering soul of the task
    var snoozeCount: Int = 0
    var moveCount: Int = 0

    // ⏳ Temporal markers
    var creationDate: Date
    var lastInteractionDate: Date

    // ✨ Total time the task has 'lingered' in the active state (in seconds)
    var totalLingeringTime: TimeInterval = 0

    init(title: String = "New Task", emoji: String = "🎯", style: TaskStyle = .sleekModern, timestamp: Date = .now) {
        self.title = title
        self.emoji = emoji
        self.style = style
        self.timestamp = timestamp
        self.creationDate = .now
        self.lastInteractionDate = .now
        print("🌟 ✨ NEW ITEM CRYSTALLIZED: \(title) [\(style.rawValue)]")
    }

    // 🌟 The Alchemy of Postponement - When a task is snoozed
    func snooze() {
        snoozeCount += 1
        updateLingeringTime()
        lastInteractionDate = .now
        print("🌙 ✨ SNOOZE RITUAL COMPLETE for [\(title)]! Style: \(style.rawValue)")
    }

    // 🎨 The Dance of Priorities - When a task is moved
    func move() {
        moveCount += 1
        updateLingeringTime()
        lastInteractionDate = .now
        print("🎪 📦 TASK SHIFTED IN THE COSMIC RING: [\(title)]!")
    }

    // 🧪 Calculating the lingering presence
    private func updateLingeringTime() {
        let interval = Date().timeIntervalSince(lastInteractionDate)
        totalLingeringTime += interval
    }
}
