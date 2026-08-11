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
import WidgetKit
import UserNotifications
import BackgroundTasks
import OSLog

@main
struct FlowApp: App {

    // MARK: - Shared State

    let sharedModelContainer: ModelContainer

    @State private var taskService: TaskService
    @State private var integrationService: ExternalIntegrationService
    @State private var todoistService: TodoistService
    @State private var amorService: AMORService

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
        
            let schema = Schema([
                Item.self,
                DailySession.self,
                PracticeStreak.self,
                CronJobHealth.self,
                DailySummary.self,
                SecondBrainEntry.self,
                ReflectionEntry.self
            ])

        do {
            let fileManager = FileManager.default
            if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
               !fileManager.fileExists(atPath: appSupport.path) {
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
            self._amorService        = State(initialValue: AMORService(modelContext: ctx))

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
                .environment(amorService)
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

                // v3.3.0: Re-sync Hermes sessions on foreground.
                // The user's Hermes agent keeps producing sessions while the app
                // is backgrounded. Re-syncing on every foreground ensures the
                // dashboard, progress tracker, and briefing engine always see
                // fresh data without requiring manual "Sync Now" taps.
                let hermesEngine = HermesIntegrationEngine()
                if hermesEngine.isHermesAvailable {
                    hermesEngine.performFullSync(into: sharedModelContainer.mainContext)
                    FlowLogger.network.info("🌉 Foreground Hermes sync complete")
                }

                // v3.3.0: Auto-generate daily session dump.
                // Runs after Hermes sync so auto-imported sessions are included.
                autoGenerateDailyDump()

                // v3.4.0: Auto-generate weekly review dump.
                // Deduplicates by ISO week — writes a new file each week.
                autoGenerateWeeklyDump()

                // v3.6.0: Sync AMOR widget snapshot to App Groups.
                // Updates the Home Screen / Lock Screen widgets with fresh data.
                syncAMORWidget()
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

    // MARK: - v3.3.0: Session-Dump Automation

    /// Auto-generates the daily session dump and progress snapshot.
    /// Called on every foreground transition. Deduplicates by date —
    /// updates the existing dump if one already exists for today.
    private func autoGenerateDailyDump() {
        let automation = AMORSessionDumpAutomation()
        guard automation.isAvailable else {
            FlowLogger.lifecycle.info("📄 Dump automation: directory unavailable")
            return
        }

        let ctx = sharedModelContainer.mainContext

        // Fetch all model types the dump needs
        let sessions = (try? ctx.fetch(FetchDescriptor<DailySession>())) ?? []
        let practices = (try? ctx.fetch(FetchDescriptor<PracticeStreak>())) ?? []
        let cronJobs = (try? ctx.fetch(FetchDescriptor<CronJobHealth>())) ?? []
        let summaries = (try? ctx.fetch(FetchDescriptor<DailySummary>())) ?? []
        let reflections = (try? ctx.fetch(FetchDescriptor<ReflectionEntry>())) ?? []

        let result = automation.generateDailyDump(
            sessions: sessions,
            practices: practices,
            cronJobs: cronJobs,
            summaries: summaries,
            reflections: reflections
        )

        if let result = result {
            if result.wasNew {
                FlowLogger.lifecycle.info("📄 Daily dump created: \(result.dumpPath ?? "?")")
            }
            // Silent on updates — no need to log every foreground
        }
    }

    // MARK: - v3.4.0: Weekly Review Automation

    /// Auto-generates the weekly review dump.
    /// Called on every foreground transition. Deduplicates by ISO week —
    /// updates the existing dump if one already exists for this week.
    private func autoGenerateWeeklyDump() {
        let ctx = sharedModelContainer.mainContext

        let sessions = (try? ctx.fetch(FetchDescriptor<DailySession>())) ?? []
        let practices = (try? ctx.fetch(FetchDescriptor<PracticeStreak>())) ?? []
        let cronJobs = (try? ctx.fetch(FetchDescriptor<CronJobHealth>())) ?? []
        let summaries = (try? ctx.fetch(FetchDescriptor<DailySummary>())) ?? []
        let reflections = (try? ctx.fetch(FetchDescriptor<ReflectionEntry>())) ?? []

        let home = FileManager.default.homeDirectoryForCurrentUser
        let dumpsDir = home
            .appendingPathComponent(".hermes")
            .appendingPathComponent("logs")
            .appendingPathComponent("amor-dumps")
        let obsidianDir = home
            .appendingPathComponent("wiki")
            .appendingPathComponent("Journal")

        let result = AMORWeeklyReviewEngine.autoGenerateWeeklyDump(
            sessions: sessions,
            practices: practices,
            cronJobs: cronJobs,
            summaries: summaries,
            reflections: reflections,
            dumpsDir: dumpsDir,
            obsidianJournalDir: obsidianDir
        )

        if let result = result, result.wasNew {
            FlowLogger.lifecycle.info("📊 Weekly review created: \(result.dumpPath ?? "?")")
        }
    }

    // MARK: - v3.6.0: AMOR Widget Snapshot Sync

    /// Builds and writes the AMOR widget snapshot to App Groups UserDefaults.
    /// Called on every foreground transition so Home Screen widgets stay fresh.
    private func syncAMORWidget() {
        let ctx = sharedModelContainer.mainContext

        let sessions = (try? ctx.fetch(FetchDescriptor<DailySession>())) ?? []
        let practices = (try? ctx.fetch(FetchDescriptor<PracticeStreak>())) ?? []
        let cronJobs = (try? ctx.fetch(FetchDescriptor<CronJobHealth>())) ?? []

        AMORWidgetBuilder.syncSnapshot(
            sessions: sessions,
            practices: practices,
            cronJobs: cronJobs
        )

        // Tell WidgetKit to reload timelines
        WidgetCenter.shared.reloadTimelines(ofKind: "AMORWidget")
    }

    // MARK: - Startup

    private func handleStartup() {
        Task {
            // Seed default practices
            amorService.seedDefaultPracticesIfNeeded()

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

            // Hermes integration auto-sync (session-dump automation)
            FlowLogger.network.info("🌉 Syncing Hermes sessions…")
            let hermesEngine = HermesIntegrationEngine()
            if hermesEngine.isHermesAvailable {
                hermesEngine.performFullSync(into: sharedModelContainer.mainContext)
            }

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
    nonisolated static let bgReconcileTaskId = "com.binarybros.Flow.reconcile"

    /// Schedules a background processing task to run within the next hour.
    /// Called after the app reconciles so the system can schedule the next
    /// background wake before the app fully suspends.
    nonisolated static func scheduleNextBGReconcile() {
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

    /// Executed by the system on a background context when the task fires.
    nonisolated static func handleBGReconcileTask(_ task: BGProcessingTask) {
        scheduleNextBGReconcile() // always re-schedule before doing work

        // `BGProcessingTask` is not `Sendable`. The system delivers and only
        // ever touches this handle from a single background context, so we
        // forward it into the completion `Task` via a tiny unchecked box.
        let bgTask = UnsafeBGProcessingTaskBox(task: task)

        let work = Task {
            let success = await performBackgroundReconcile()
            bgTask.task.setTaskCompleted(success: success)
        }

        task.expirationHandler = {
            work.cancel()
            FlowLogger.lifecycle.warning("⚠️ BGTask expired before completion")
        }
    }

    /// Builds a fresh container, reconciles the shared store on the main
    /// actor, and reports whether the pass succeeded.
    @MainActor
    private static func performBackgroundReconcile() async -> Bool {
        do {
            let schema = Schema([Item.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [config])
            let service = TaskService(modelContext: container.mainContext)
            await service.reconcileFromSharedStore()
            FlowLogger.lifecycle.info("🔄 BGTask reconcile complete")
            return true
        } catch {
            FlowLogger.lifecycle.error("💥 BGTask: reconcile failed: \(error.localizedDescription)")
            return false
        }
    }
}

nonisolated private struct UnsafeBGProcessingTaskBox: @unchecked Sendable {
    nonisolated(unsafe) let task: BGProcessingTask
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
