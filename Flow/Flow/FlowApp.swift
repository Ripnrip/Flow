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
    @State private var todoistService: TodoistService

    init() {
        print("🌐 ✨ FLOW APP AWAKENS!")
        
        let schema = Schema([
            Item.self
        ])
        
        do {
            // 🛠️ Healing the path for SwiftData - ensuring Application Support exists
            let fileManager = FileManager.default
            let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            if !fileManager.fileExists(atPath: appSupportURL.path) {
                print("🏗️ Creating Application Support sanctuary...")
                try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
            }

            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.sharedModelContainer = container
            let context = container.mainContext
            
            // 🧙‍♂️ Services initialized with the main context
            self._taskService = State(initialValue: TaskService(modelContext: context))
            self._integrationService = State(initialValue: ExternalIntegrationService(modelContext: context))
            self._todoistService = State(initialValue: TodoistService(modelContext: context))
            
            print("✅ ✨ MODEL CONTAINER CRYSTALLIZED!")
            
        } catch {
            // --- FIX FOR AMBIGUOUS INIT ERROR: Initialize all properties before fatalError ---
            print("🌩️ CRITICAL FAILURE: Could not create ModelContainer: \(error)")
            
            // Create a temporary, in-memory container configuration for placeholder initialization
            let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            
            do {
                let tempContainer = try ModelContainer(for: schema, configurations: [fallbackConfiguration])
                self.sharedModelContainer = tempContainer
                let context = tempContainer.mainContext
                
                // Initialize @State properties with placeholder services (will be immediately destroyed by fatalError)
                self._taskService = State(initialValue: TaskService(modelContext: context))
                self._integrationService = State(initialValue: ExternalIntegrationService(modelContext: context))
                self._todoistService = State(initialValue: TodoistService(modelContext: context))
                
            } catch {
                // If the fallback fails, we must use a minimal, manual fallback
                // This path should ideally never be hit.
                fatalError("Double Critical Failure: Cannot even create in-memory ModelContainer: \(error)")
            }
            
            // Terminate the application after ensuring properties are initialized
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(taskService)
                .environment(integrationService)
                .environment(todoistService)
                .onAppear {
                    // 🔔 ✨ REQUESTING THE GIFT OF NOTIFICATIONS
                    requestNotificationPermissions()

                    Task {
                        // Restore Live Activity session if a task is already in focus or if there is a primary task awaiting focus.
                        await taskService.restoreActiveFocusSession()
                        
                        await integrationService.requestPermissions()
                        if integrationService.isAuthorized {
                            await integrationService.inhaleCalendarEvents()
                            await integrationService.inhaleReminders()
                        }
                        await todoistService.inhaleTasks()
                    }
                }
        }
        .modelContainer(sharedModelContainer)

        #if os(macOS)
        MenuBarExtra("Focus Flow", systemImage: "target") {
            VStack {
                Text("Focus Flow")
                    .font(.headline)
                Divider()
                Button("Sync All") {
                    Task {
                        await integrationService.inhaleCalendarEvents()
                        await integrationService.inhaleReminders()
                        await todoistService.inhaleTasks()
                    }
                }
                Divider()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        #endif
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
