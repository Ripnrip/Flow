/**
 * 🌐 The FlowServer Service - The Hummingbird Whisperer
 *
 * "A bridge between the Flow iOS app and its Swift Hummingbird backend,
 * where tasks are summoned and focus sessions are chronicled."
 *
 * - The Celestial Network Conjurer
 */

import Foundation
import OSLog
import SwiftData
import Observation

/// 🎭 Identifies which external system a Flow task originated from.
enum ExternalSourceType: String, CaseIterable {
    case superProductivity = "superproductivity"
    case todoist = "todoist"
    case calendar = "calendar"
    case reminders = "reminders"
    case manual = "manual"
}

/// 📦 Task shape returned by the FlowServer `/api/v1/tasks` endpoint.
struct FlowServerTask: Codable, Sendable {
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

/// 📝 Payload sent to the FlowServer when a focus session ends.
struct FocusSessionPayload: Codable, Sendable {
    let durationSeconds: Int
    let completed: Bool
    let endedAt: Date
}

/// ✅ Generic server confirmation.
struct FlowServerMessage: Codable, Sendable {
    let message: String
}

@MainActor
@Observable
class FlowServerService {
    private var modelContext: ModelContext

    /// 🌐 Base URL for the Hummingbird backend, read from Info.plist (`FlowServerBaseURL`).
    /// Defaults to localhost for development shenanigans.
    private var baseURL: String {
        Bundle.main.object(forInfoDictionaryKey: "FlowServerBaseURL") as? String ?? "http://localhost:8085"
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        FlowLogger.lifecycle.info("🌐 FlowServerService initialised")
    }

    // 🌐 Pull tasks from the Hummingbird backend and import them into SwiftData.
    func inhaleTasks() async {
        FlowLogger.network.info("📥 Importing tasks from FlowServer…")

        guard let url = URL(string: "\(baseURL)/api/v1/tasks") else {
            FlowLogger.network.error("💥 Invalid FlowServer tasks URL")
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                FlowLogger.network.warning("🌩️ FlowServer tasks request rejected. Status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let serverTasks = try decoder.decode([FlowServerTask].self, from: data)

            FlowLogger.network.info("✨ Found \(serverTasks.count) tasks on FlowServer")

            for serverTask in serverTasks {
                let externalId: String? = serverTask.id.uuidString
                let descriptor = FetchDescriptor<Item>(
                    predicate: #Predicate { $0.externalSourceId == externalId }
                )
                let existing = try? modelContext.fetch(descriptor).first

                if let existing {
                    existing.title = serverTask.name
                    existing.id = serverTask.id
                    existing.lastInteractionDate = .now
                    FlowLogger.local.info("🔄 Updated FlowServer task: \(serverTask.name, privacy: .public)")
                } else {
                    let style = autoPrioritize(priority: serverTask.priority)
                    let newItem = Item(
                        title: serverTask.name,
                        emoji: "sf:bolt.circle.fill",
                        style: style,
                        timestamp: serverTask.dueDate ?? .now
                    )
                    // 🌉 Bridge the server identity into SwiftData so deep links
                    // like flow://task/<server-id> resolve to this local item.
                    newItem.id = serverTask.id
                    newItem.externalSourceId = serverTask.id.uuidString
                    newItem.externalSourceType = ExternalSourceType.superProductivity.rawValue
                    modelContext.insert(newItem)
                    FlowLogger.local.info("💎 Imported FlowServer task: \(serverTask.name, privacy: .public)")
                }
            }

            try modelContext.save()
            FlowLogger.network.info("🎉 FlowServer import complete")

        } catch {
            FlowLogger.network.error("💥 FlowServer import failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // ⏱️ Report a completed focus session back to the Hummingbird backend.
    func reportFocusSession(taskId: UUID, durationSeconds: Int, completed: Bool) async {
        FlowLogger.network.info("📤 Reporting focus session for \(taskId)")

        guard let url = URL(string: "\(baseURL)/api/v1/tasks/\(taskId.uuidString)/sessions") else {
            FlowLogger.network.error("💥 Invalid FlowServer session URL")
            return
        }

        let payload = FocusSessionPayload(
            durationSeconds: durationSeconds,
            completed: completed,
            endedAt: .now
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let body = try encoder.encode(payload)

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                FlowLogger.network.warning("🌩️ FlowServer session report rejected. Status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return
            }

            FlowLogger.network.info("🎉 Focus session reported to FlowServer")
        } catch {
            FlowLogger.network.error("💥 FlowServer session report failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // 🎨 Map SuperProductivity priority to Flow TaskStyle.
    private func autoPrioritize(priority: Int) -> TaskStyle {
        switch priority {
        case 4: return .neoBrutalism
        case 3: return .volcanicFlow
        case 2: return .sleekModern
        default: return .zenFocus
        }
    }
}
