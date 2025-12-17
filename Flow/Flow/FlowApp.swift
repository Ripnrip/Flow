/**
 * 🎭 The FlowApp - The Grand Entrance
 *
 * "The portal through which the user enters the realm of Focus Flow.
 * It initializes the shared wisdom of the Model Container and the Task Service."
 *
 * - The Cosmic Process Orchestrator
 */

import SwiftUI
import SwiftData
import UserNotifications

@main
struct FlowApp: App {
    // 💎 The crystallized wisdom of our data model
    let sharedModelContainer: ModelContainer

    @State private var taskService: TaskService
    @State private var integrationService: ExternalIntegrationService

    init() {
        print("🌐 ✨ FLOW APP AWAKENS!")

        // 🛠️ Healing the path for SwiftData - ensuring Application Support exists
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        if !fileManager.fileExists(atPath: appSupportURL.path) {
            print("🏗️ Creating Application Support sanctuary...")
            try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        }

        let schema = Schema([
            Item.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.sharedModelContainer = container
            let context = container.mainContext
            // 🧙‍♂️ Services initialized with the main context
            self._taskService = State(initialValue: TaskService(modelContext: context))
            self._integrationService = State(initialValue: ExternalIntegrationService(modelContext: context))
            print("✅ ✨ MODEL CONTAINER CRYSTALLIZED!")
        } catch {
            print("🌩️ CRITICAL FAILURE: Could not create ModelContainer: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(taskService)
                .environment(integrationService)
                .onAppear {
                    // 🔔 ✨ REQUESTING THE GIFT OF NOTIFICATIONS
                    requestNotificationPermissions()

                    Task {
                        await integrationService.requestPermissions()
                        if integrationService.isAuthorized {
                            await integrationService.inhaleCalendarEvents()
                            await integrationService.inhaleReminders()
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    // 🔔 The Ritual of Permission - Seeking the user's blessing for awareness
    private func requestNotificationPermissions() {
        print("🔍 🧙‍♂️ PEERING INTO NOTIFICATION BLESSINGS...")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("🎉 ✨ USER HAS BLESSED US WITH AWARENESS!")
            } else if let error = error {
                print("🌩️ Temporary setback in seeking blessing: \(error.localizedDescription)")
            } else {
                print("🌙 ⚠️ User has declined the gift of notifications.")
            }
        }
    }
}
