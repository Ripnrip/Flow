/**
 * 🎭 The Todoist Service - The Shadow Realm Inhaler
 *
 * "From the depths of the cloud, where the seeker of wisdom
 * organizes their worldly duties, we pull the threads of intent
 * and weave them into the Flow."
 *
 * - The Digital Portal Architect
 */

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
class TodoistService {
    private var modelContext: ModelContext
    private let apiKey = "9fe3eb435d47590292a3c17ee2cde591e2bd5be7"
    private let apiURL = URL(string: "https://api.todoist.com/rest/v2/tasks")!

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        print("🌐 ✨ TODOIST SERVICE AWAKENS!")
    }

    // 🌐 Inhale tasks from Todoist
    func inhaleTasks() async {
        print("📥 ✨ COMMENCING TODOIST INHALATION...")

        var request = URLRequest(url: apiURL)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("🌩️ ⚠️ Todoist portal rejected our request. Status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return
            }

            let decoder = JSONDecoder()
            let todoistTasks = try decoder.decode([TodoistTask].self, from: data)

            print("✨ Found \(todoistTasks.count) tasks in the Shadow Realm.")

            for task in todoistTasks {
                let title = task.content
                let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.title == title })

                let existing = try modelContext.fetch(descriptor)
                if existing.isEmpty {
                    let style = autoPrioritize(priority: task.priority)
                    let newItem = Item(title: title, emoji: "sf:circle.inset.filled", style: style, timestamp: .now)
                    modelContext.insert(newItem)
                    print("💎 Crystallized Todoist task: \(title)")
                }
            }

            try modelContext.save()
            print("🎉 ✨ TODOIST INHALATION COMPLETE!")

        } catch {
            print("💥 😭 TODOIST PORTAL COLLAPSED: \(error.localizedDescription)")
        }
    }

    private func autoPrioritize(priority: Int) -> TaskStyle {
        switch priority {
        case 4: return .neoBrutalism // Urgent
        case 3: return .volcanicFlow // High
        case 2: return .sleekModern  // Medium
        default: return .zenFocus    // Low
        }
    }
}

// MARK: - 📜 Models

struct TodoistTask: Codable {
    let id: String
    let content: String
    let priority: Int
}

