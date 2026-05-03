/**
 * 🎭 FlowApp — The Grand Entrance
 *
 * "The portal through which the user enters the realm of Focus Flow.
 * It initialises the shared ModelContainer, services, and routing layer,
 * then stands ready to receive Universal Links and App Clip handoffs."
 *
 * Universal Links & Deep Links
 * ────────────────────────────
 *  1. System delivers URL to `.onOpenURL`
 *  2. `FlowRoute(url:)` parses it into a typed route
 *  3. `activeRoute` state drives navigation in ContentView
 *
 * App Clip → Full App handoff
 * ────────────────────────────
 *  App Clip writes a `pendingTaskName` into App Groups UserDefaults
 *  before promoting to the full app. `FlowApp.onAppear` reads it and
 *  pre-populates the new-task sheet.
 *
 * Foreground reconciliation
 * ────────────────────────────
 *  `scenePhase` change to `.active` triggers
 *  `taskService.reconcileFromSharedStore()` so any SnoozeIntent /
 *  DoneIntent actions taken while the app was backgrounded are
 *  committed to SwiftData before the user sees the UI.
 */

import SwiftUI
import SwiftData
import UserNotifications
import BackgroundTasks

@main
struct FlowApp: App {

    // MARK: - Shared State

    let sharedModelContainer: ModelContainer

    @State private var taskService: TaskService
    @State private var integrationService: ExternalIntegrationService
    @State private var todoistService: TodoistService

    /// The pending route derived from an incoming Universal Link or deep link.
    /// Consumed by ContentView's `.onChange(of: activeRoute)` to navigate.
    @State private var activeRoute: FlowRoute?

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Init

    init() {
        FlowLogger.lifecycle.info("🌐 ✨ FlowApp awakening…")

        // Register background processing task so the system can wake the app
        // to reconcile SharedTaskStore changes committed by AppIntents.
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: FlowApp.bgReconcileTaskId,
            using: nil
        ) { task in
            guard let task = task as? BGProcessingTask else { return }
            FlowApp.handleBGReconcileTask(task)
        }

        let schema = Schema([Item.self])

        do {
            let fileManager = FileManager.default
            let appSupport  = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            if !fileManager.fileExists(atPath: appSupport.path) {
                try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
                FlowLogger.local.info("🏗️ Created Application Support directory")
            }

            let config    = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [config])
            self.sharedModelContainer = container
            let ctx = container.mainContext

            self._taskService        = State(initialValue: TaskService(modelContext: ctx))
            self._integrationService = State(initialValue: ExternalIntegrationService(modelContext: ctx))
            self._todoistService     = State(initialValue: TodoistService(modelContext: ctx))

            FlowLogger.lifecycle.info("✅ ModelContainer crystallised")

        } catch {
            FlowLogger.lifecycle.critical("💥 ModelContainer creation failed: \(error.localizedDescription)")

            // Fallback: in-memory container so all @State properties can be initialised
            // before the inevitable fatalError.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                let tmp = try ModelContainer(for: schema, configurations: [fallback])
                self.sharedModelContainer = tmp
                let ctx = tmp.mainContext
                self._taskService        = State(initialValue: TaskService(modelContext: ctx))
                self._integrationService = State(initialValue: ExternalIntegrationService(modelContext: ctx))
                self._todoistService     = State(initialValue: TodoistService(modelContext: ctx))
            } catch {
                fatalError("Double critical failure — cannot create in-memory ModelContainer: \(error)")
            }
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            ContentView(activeRoute: $activeRoute)
                .environment(taskService)
                .environment(integrationService)
                .environment(todoistService)
                .onAppear {
                    requestNotificationPermissions()
                    handleStartup()
                }
                // ── Universal Link / deep-link ingestion ──────────────
                .onOpenURL { url in
                    FlowLogger.deepLink.info("🔗 Received URL: \(url.absoluteString)")
                    if let route = FlowRoute(url: url) {
                        FlowLogger.deepLink.info("🔗 Resolved route: \(String(describing: route))")
                        activeRoute = route
                    } else {
                        FlowLogger.deepLink.warning("⚠️ No route matched for: \(url.absoluteString)")
                    }
                }
                // ── NSUserActivity continuation (Handoff / Spotlight) ──
                .onContinueUserActivity(NSUserActivityTypes.browsingWeb) { activity in
                    guard let url = activity.webpageURL,
                          let route = FlowRoute(url: url) else { return }
                    FlowLogger.deepLink.info("🔗 NSUserActivity route: \(String(describing: route))")
                    activeRoute = route
                }
        }
        .modelContainer(sharedModelContainer)
        // Reconcile on every foreground (catches intent-pending changes)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                FlowLogger.lifecycle.info("🔄 Scene became active — reconciling shared store")
                Task { await taskService.reconcileFromSharedStore() }
            case .background:
                // Schedule a background processing task so the system can
                // wake us proactively if intents fired while we were suspended.
                FlowApp.scheduleNextBGReconcile()
            default:
                break
            }
        }

        #if os(macOS)
        MenuBarExtra("Focus Flow", systemImage: "target") {
            MacMenuBarView(
                taskService: taskService,
                integrationService: integrationService,
                todoistService: todoistService
            )
        }
        #endif
    }

    // MARK: - Startup

    private func handleStartup() {
        Task {
            // Restore any active focus session (also reconciles SharedTaskStore)
            await taskService.restoreActiveFocusSession()

            // Sync external integrations
            await integrationService.requestPermissions()
            if integrationService.isAuthorized {
                FlowLogger.network.info("🌐 Syncing Calendar & Reminders…")
                await integrationService.inhaleCalendarEvents()
                await integrationService.inhaleReminders()
            }

            FlowLogger.network.info("🌐 Syncing Todoist…")
            await todoistService.inhaleTasks()

            // Handle App Clip → Full App handoff task name
            if let defaults  = UserDefaults(suiteName: kFlowAppGroup),
               let taskName  = defaults.string(forKey: "com.binarybros.Flow.pendingTaskName"),
               !taskName.isEmpty {
                FlowLogger.deepLink.info("🔗 App Clip handoff: pending task '\(taskName)'")
                activeRoute = .inbox // Navigate to inbox; ContentView surfaces the sheet
                defaults.removeObject(forKey: "com.binarybros.Flow.pendingTaskName")
            }
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermissions() {
        FlowLogger.lifecycle.info("🔔 Requesting notification authorisation…")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                FlowLogger.lifecycle.info("🎉 Notifications authorised")
            } else if let error {
                FlowLogger.lifecycle.warning("⚠️ Notification auth error: \(error.localizedDescription)")
            } else {
                FlowLogger.lifecycle.info("🌙 User declined notifications")
            }
        }
    }
}

// MARK: - Background Task

extension FlowApp {
    static let bgReconcileTaskId = "com.binarybros.Flow.reconcile"

    /// Schedules a background processing task to run within the next hour.
    /// Called after the app reconciles so the system can schedule the next
    /// background wake before the app fully suspends.
    static func scheduleNextBGReconcile() {
        let request = BGProcessingTaskRequest(identifier: bgReconcileTaskId)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 30) // 30 min
        do {
            try BGTaskScheduler.shared.submit(request)
            FlowLogger.lifecycle.info("📅 BGProcessingTask scheduled")
        } catch {
            FlowLogger.lifecycle.warning("⚠️ BGTask schedule error: \(error.localizedDescription)")
        }
    }

    /// Executed by the system when the background task fires.
    static func handleBGReconcileTask(_ task: BGProcessingTask) {
        scheduleNextBGReconcile() // always re-schedule before doing work

        let container: ModelContainer
        do {
            let schema = Schema([Item.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            FlowLogger.lifecycle.error("💥 BGTask: failed to create ModelContainer: \(error.localizedDescription)")
            task.setTaskCompleted(success: false)
            return
        }

        let work = Task {
            let service = await TaskService(modelContext: container.mainContext)
            await service.reconcileFromSharedStore()
            FlowLogger.lifecycle.info("🔄 BGTask reconcile complete")
        }

        task.expirationHandler = {
            work.cancel()
            FlowLogger.lifecycle.warning("⚠️ BGTask expired before completion")
        }

        Task {
            await work.value
            task.setTaskCompleted(success: true)
        }
    }
}

// MARK: - NSUserActivityTypes helper

private enum NSUserActivityTypes {
    static let browsingWeb = "NSUserActivityTypeBrowsingWeb"
}

// MARK: - macOS Menu Bar View

#if os(macOS)
private struct MacMenuBarView: View {
    let taskService: TaskService
    let integrationService: ExternalIntegrationService
    let todoistService: TodoistService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Focus Flow")
                .font(.headline)
                .padding(.horizontal)

            Divider()

            Button("Sync Integrations") {
                Task {
                    FlowLogger.network.info("🌐 macOS menu: syncing integrations")
                    await integrationService.inhaleCalendarEvents()
                    await integrationService.inhaleReminders()
                    await todoistService.inhaleTasks()
                }
            }

            Divider()

            Button("Quit") {
                FlowLogger.lifecycle.info("👋 macOS menu: quitting app")
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 6)
        .frame(minWidth: 200)
    }
}
#endif
