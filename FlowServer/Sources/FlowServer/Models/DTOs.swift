import Foundation
import Hummingbird

/// 📦 Lightweight task shape returned to the Flow iOS app.
/// Keeps the wire format stable even if the Realm schema evolves.
struct TaskDTO: Codable, Sendable, ResponseEncodable {
    let id: UUID
    let name: String
    let description: String?
    let state: String
    let priority: Int
    let estimatedDuration: Int?
    let actualDuration: Int?
    let dueDate: Date?
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date
}

/// 📝 Payload sent by Flow when it completes a focus session.
struct FocusSessionRequest: Codable, Sendable {
    let durationSeconds: Int
    let completed: Bool
    let endedAt: Date
}

/// ✅ Generic OK response with a sprinkle of theatre.
struct MessageResponse: Codable, Sendable, ResponseEncodable {
    let message: String
}

extension SuperTaskObject {
    /// Converts the Realm object into a stable API DTO.
    func toDTO() -> TaskDTO {
        TaskDTO(
            id: id,
            name: name,
            description: taskDescription,
            state: stateRaw,
            priority: priority,
            estimatedDuration: estimatedDuration,
            actualDuration: actualDuration,
            dueDate: dueDate,
            tags: Array(tags),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
