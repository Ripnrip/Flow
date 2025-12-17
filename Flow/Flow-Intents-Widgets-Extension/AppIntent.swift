/**
 * 🎭 The Intents - The Catalysts of Action
 *
 * "The bridges between the user's touch and the digital realm.
 * Each intent is a decree that reshapes the reality of our tasks."
 *
 * - The Cosmic Ritual Orchestrator
 */

import WidgetKit
import AppIntents
import SwiftData
import Foundation

// MARK: - 🧙‍♂️ SHARED KNOWLEDGE

#if os(iOS)
import ActivityKit
#endif

// 📜 TaskProtocol - Conforming to the cosmic order
protocol TaskProtocol: Sendable {
    var id: UUID { get }
    var title: String { get }
    var emoji: String { get }
    var style: TaskStyle { get }
    var snoozeCount: Int { get }
    var moveCount: Int { get }
    var totalLingeringTime: TimeInterval { get }
    var creationDate: Date { get }
    var growthLevel: Int { get }
}

// 🧙‍♂️ The Item Model - The Vessel of Purpose (Extension-visible definition)
@Model
final class Item: TaskProtocol {
    var id: UUID = UUID()
    var title: String
    var emoji: String = "🎯"
    var style: TaskStyle = TaskStyle.sleekModern
    var timestamp: Date
    var isCompleted: Bool = false
    var snoozeCount: Int = 0
    var moveCount: Int = 0
    var creationDate: Date
    var lastInteractionDate: Date
    var totalLingeringTime: TimeInterval = 0

    var growthLevel: Int {
        if style == .livingGarden || style == .magicalForest {
            if totalLingeringTime > 1800 { return 3 }
            else if totalLingeringTime > 900 { return 2 }
            else if totalLingeringTime > 300 { return 1 }
            else { return 0 }
        }
        return 0
    }

    init(title: String = "New Task", emoji: String = "🎯", style: TaskStyle = TaskStyle.sleekModern, timestamp: Date = .now) {
        self.title = title
        self.emoji = emoji
        self.style = style
        self.timestamp = timestamp
        self.creationDate = .now
        self.lastInteractionDate = .now
        print("🌟 ✨ NEW ITEM CRYSTALLIZED IN EXTENSION: \(title) [\(style.rawValue)]")
    }

    func snooze() {
        snoozeCount += 1
        lastInteractionDate = .now
        print("🌙 ✨ SNOOZE RITUAL COMPLETE via Intent for [\(title)]!")
    }

    func move() {
        moveCount += 1
        lastInteractionDate = .now
        print("🎪 📦 TASK SHIFTED via Intent for [\(title)]!")
    }
}

// MARK: - 🌟 INTENTS

// 🌟 The Configuration Intent - For the standard widget
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is an example widget." }

    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String
}

// 🌟 The Snooze Ritual - Delaying the inevitable with grace
struct SnoozeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Snooze Task"

    @Parameter(title: "Task ID")
    var taskId: String

    init() {}
    init(taskId: String) {
        self.taskId = taskId
    }

    func perform() async throws -> some IntentResult {
        print("🌐 ✨ SNOOZE INTENT AWAKENS for \(taskId)")

        let schema = Schema([Item.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [config])

        await MainActor.run {
            let context = container.mainContext
            let uuid = UUID(uuidString: taskId)

            do {
                if let uuid = uuid, let task = try context.fetch(FetchDescriptor<Item>()).first(where: { $0.id == uuid }) {
                    task.snooze()
                    try context.save()
                    print("🎉 ✨ SNOOZE RITUAL SUCCESS for [\(task.title)]!")
                } else {
                    print("🌙 ⚠️ Task not found in the cosmic registry: \(taskId)")
                }
            } catch {
                print("💥 😭 SNOOZE INTENT FAILED: \(error.localizedDescription)")
            }
        }
        return .result()
    }
}

// ✅ The Done Ritual - Celebrating completion
struct DoneIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete Task"

    @Parameter(title: "Task ID")
    var taskId: String

    init() {}
    init(taskId: String) {
        self.taskId = taskId
    }

    func perform() async throws -> some IntentResult {
        print("🎉 ✨ DONE INTENT AWAKENS for \(taskId)")

        let schema = Schema([Item.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [config])

        await MainActor.run {
            let context = container.mainContext
            let uuid = UUID(uuidString: taskId)

            do {
                if let uuid = uuid, let task = try context.fetch(FetchDescriptor<Item>()).first(where: { $0.id == uuid }) {
                    task.isCompleted = true
                    try context.save()
                    print("🎉 ✨ TASK COMPLETION MASTERPIECE for [\(task.title)]!")
                } else {
                    print("🌙 ⚠️ Task not found: \(taskId)")
                }
            } catch {
                print("💥 😭 DONE INTENT FAILED: \(error.localizedDescription)")
            }
        }
        return .result()
    }
}

// 🎨 The Move Ritual - Shifting focus
struct MoveIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Move Task"

    @Parameter(title: "Task ID")
    var taskId: String

    init() {}
    init(taskId: String) {
        self.taskId = taskId
    }

    func perform() async throws -> some IntentResult {
        print("🎪 📦 MOVE INTENT AWAKENS for \(taskId)")

        let schema = Schema([Item.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [config])

        await MainActor.run {
            let context = container.mainContext
            let uuid = UUID(uuidString: taskId)

            do {
                if let uuid = uuid, let task = try context.fetch(FetchDescriptor<Item>()).first(where: { $0.id == uuid }) {
                    task.move()
                    try context.save()
                    print("🎪 📦 TASK SHIFTED SUCCESS for [\(task.title)]!")
                } else {
                    print("🌙 ⚠️ Task not found: \(taskId)")
                }
            } catch {
                print("💥 😭 MOVE INTENT FAILED: \(error.localizedDescription)")
            }
        }
        return .result()
    }
}
