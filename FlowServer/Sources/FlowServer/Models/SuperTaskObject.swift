import Foundation
import RealmSwift

/// 🗄️ Realm mirror of a SuperProductivity task.
/// Lives on the Hummingbird server so Flow has a fast, local-first backend.
final class SuperTaskObject: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var id: UUID
    @Persisted var name: String
    @Persisted var taskDescription: String?
    @Persisted var stateRaw: String
    @Persisted var priority: Int
    @Persisted var superChecklistId: UUID
    @Persisted var parentTaskId: UUID?
    @Persisted var estimatedDuration: Int?
    @Persisted var actualDuration: Int?
    @Persisted var startedAt: Date?
    @Persisted var completedAt: Date?
    @Persisted var originalCreatedDate: Date
    @Persisted var lastCarryoverDate: Date?
    @Persisted var carryoverCount: Int
    @Persisted var tags: List<String>
    @Persisted var dueDate: Date?
    @Persisted var position: Double
    @Persisted var createdAt: Date
    @Persisted var updatedAt: Date
    @Persisted var trelloId: String?
    @Persisted var userId: UUID?
    @Persisted var reminderDate: Date?
    @Persisted var alertDate: Date?
    @Persisted var addToCalendar: Bool
    @Persisted var sessions: List<FocusSessionObject>

    /// Convenience computed state enum for the server 🎭
    var state: TaskState {
        get { TaskState(rawValue: stateRaw) ?? .open }
        set { stateRaw = newValue.rawValue }
    }
}

/// 🧘 A single focus session reported by the Flow iOS app.
final class FocusSessionObject: EmbeddedObject {
    @Persisted var startedAt: Date
    @Persisted var endedAt: Date
    @Persisted var durationSeconds: Int
    @Persisted var completedTask: Bool
}

/// 📊 SuperProductivity task states, mirrored server-side.
enum TaskState: String, Codable {
    case open = "open"
    case inProgress = "in_progress"
    case done = "done"
    case cancelled = "cancelled"
}
