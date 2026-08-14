/**
 * 🎙️ AMORAppIntents — Siri Shortcuts & AppIntents Engine
 *
 * "The voice-activated gateway to daily rhythm. Log sessions, complete
 *  practices, check streaks, and query system health — all through Siri,
 *  Shortcuts, and Spotlight. The app speaks, the app listens, the app acts."
 *
 * v3.8.0 — AppIntents & Siri Shortcuts
 *
 * Intents provided:
 *   1. LogSessionIntent     — "Log a 30 minute session on SwiftUI refactoring"
 *   2. CompletePracticeIntent — "Mark my Gita practice as done"
 *   3. CheckStreakIntent    — "What are my current streaks?"
 *   4. SystemHealthIntent   — "How is my system health?"
 *   5. DailySummaryIntent   — "Give me today's summary"
 *   6. SetMoodIntent        — "Set my mood to focused"
 *
 * Architecture:
 *   - AppIntents write to App Groups UserDefaults as a pending action queue
 *   - FlowApp.scenePhase(.active) reconciles pending actions into SwiftData
 *   - This avoids needing a ModelContext in the intent execution context
 *   - AppShortcutsProvider exposes key phrases to Siri automatically
 *
 * App Group: group.com.binarybros.Flow
 */

import Foundation
import AppIntents

// v3.9.0: AMORPendingAction + AMORPendingActionStore moved to AMORWidgetShared.swift
// so the widget extension target can enqueue actions from interactive widget
// buttons. This file now contains only the intents + reconciler (main-app target).

// MARK: - Intent Result Types

/// Snapshot of today's data for intent responses — read from App Groups.
struct AMORTodaySnapshot: Codable, Sendable {
    let date: Date
    let sessionCount: Int
    let totalFocusMinutes: Int
    let activeStreaks: [StreakSnapshot]
    let practicesDue: Int
    let practicesCompleted: Int
    let cronHealthy: Int
    let cronFailed: Int
    let cronTotal: Int
    let mood: String

    static func readFromWidgetSnapshot() -> AMORTodaySnapshot? {
        guard let snap = AMORWidgetStore.readSnapshot() else { return nil }
        let mood = UserDefaults(suiteName: kFlowAppGroup)?
            .string(forKey: "amor.lastKnownMood") ?? "neutral"
        return AMORTodaySnapshot(
            date: snap.date,
            sessionCount: snap.sessionCount,
            totalFocusMinutes: snap.totalFocusMinutes,
            activeStreaks: snap.activeStreaks,
            practicesDue: snap.practicesDue,
            practicesCompleted: snap.practicesCompleted,
            cronHealthy: snap.cronHealthy,
            cronFailed: snap.cronFailed,
            cronTotal: snap.cronTotal,
            mood: mood
        )
    }
}

// MARK: - LogSessionIntent

/// "Hey Siri, log a 30 minute session on SwiftUI refactoring"
struct LogSessionIntent: AppIntent {

    static var title: LocalizedStringResource = "Log Work Session"
    static var description = IntentDescription("Log a focus session with title, duration, and optional mood.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Session Title")
    var title: String

    @Parameter(title: "Duration (minutes)", default: 30, controlStyle: .stepper, inclusiveRange: (1, 480))
    var durationMinutes: Int

    @Parameter(title: "Mood", description: "How you felt during this session", default: "neutral")
    var mood: String

    @Parameter(title: "Tools Used", description: "Comma-separated list of tools (optional)", default: "")
    var tools: String

    static var parameterSummary: some ParameterSummary {
        Summary("Log a \(\($durationMinutes)) minute session: \(\($title))") {
            \($mood)
            \($tools)
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let action = AMORPendingAction(
            type: .logSession,
            parameters: [
                "title": title,
                "durationMinutes": String(durationMinutes),
                "mood": mood,
                "tools": tools
            ]
        )
        AMORPendingActionStore.enqueue(action)

        return .result(dialog: "Session logged: \(title) for \(durationMinutes) minutes. Mood: \(mood).")
    }
}

// MARK: - CompletePracticeIntent

/// "Hey Siri, mark my Gita practice as done"
struct CompletePracticeIntent: AppIntent {

    static var title: LocalizedStringResource = "Complete Daily Practice"
    static var description = IntentDescription("Mark a daily practice (Gita, Gym, Meditation, etc.) as completed.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Practice Name", description: "The practice to complete (e.g., Gita, Gym, Meditation)")
    var practiceName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Complete daily practice: \(\($practiceName))")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let action = AMORPendingAction(
            type: .completePractice,
            parameters: ["practiceName": practiceName]
        )
        AMORPendingActionStore.enqueue(action)

        return .result(dialog: "\(practiceName) marked as complete. Keep the streak alive!")
    }
}

// MARK: - CheckStreakIntent

/// "Hey Siri, what are my current streaks?"
struct CheckStreakIntent: AppIntent {

    static var title: LocalizedStringResource = "Check Practice Streaks"
    static var description = IntentDescription("View your current practice streaks and what's due today.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Read from the widget snapshot (App Groups) — no ModelContext needed
        guard let snapshot = AMORTodaySnapshot.readFromWidgetSnapshot() else {
            return .result(dialog: "I don't have your streak data yet. Open AMOR to sync.")
        }

        let active = snapshot.activeStreaks
        if active.isEmpty {
            return .result(dialog: "No active practices yet. Open AMOR to set up your daily practices.")
        }

        let streakLines = active.map { s in
            let status = s.isCompletedToday ? "done" : (s.isDueToday ? "due" : "active")
            return "\(s.name): \(s.currentStreak) day streak (\(status))"
        }.joined(separator: ". ")

        let due = snapshot.practicesDue
        let summary = due > 0
            ? "\(due) practice\(due > 1 ? "s" : "") still due today. "
            : "All practices complete today. "

        return .result(dialog: "\(summary)\(streakLines).")
    }
}

// MARK: - SystemHealthIntent

/// "Hey Siri, how is my system health?"
struct SystemHealthIntent: AppIntent {

    static var title: LocalizedStringResource = "Check System Health"
    static var description = IntentDescription("Check the health of your cron jobs and automated systems.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snapshot = AMORTodaySnapshot.readFromWidgetSnapshot() else {
            return .result(dialog: "System health data unavailable. Open AMOR to sync.")
        }

        if snapshot.cronTotal == 0 {
            return .result(dialog: "No cron jobs registered yet.")
        }

        let pct = Int(snapshot.cronHealthy * 100 / max(snapshot.cronTotal, 1))
        let base = "System health: \(pct)%. \(snapshot.cronHealthy) of \(snapshot.cronTotal) jobs healthy."

        if snapshot.cronFailed > 0 {
            return .result(dialog: "\(base) \(snapshot.cronFailed) job\(snapshot.cronFailed > 1 ? "s" : "") need\(snapshot.cronFailed > 1 ? "" : "s") attention.")
        }
        return .result(dialog: "\(base) All systems operational.")
    }
}

// MARK: - DailySummaryIntent

/// "Hey Siri, give me today's summary"
struct DailySummaryIntent: AppIntent {

    static var title: LocalizedStringResource = "Today's Summary"
    static var description = IntentDescription("Get a quick summary of today's sessions, practices, and focus time.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snapshot = AMORTodaySnapshot.readFromWidgetSnapshot() else {
            return .result(dialog: "No summary data yet. Open AMOR to sync.")
        }

        let hours = snapshot.totalFocusMinutes / 60
        let mins = snapshot.totalFocusMinutes % 60
        let timeStr = hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"

        var parts: [String] = []
        parts.append("\(snapshot.sessionCount) session\(snapshot.sessionCount != 1 ? "s" : "")")
        parts.append("\(timeStr) focus time")

        if snapshot.practicesDue > 0 {
            parts.append("\(snapshot.practicesDue) practice\(snapshot.practicesDue > 1 ? "s" : "") due")
        } else if snapshot.practicesCompleted > 0 {
            parts.append("all practices done")
        }

        if snapshot.cronFailed > 0 {
            parts.append("\(snapshot.cronFailed) system alert\(snapshot.cronFailed > 1 ? "s" : "")")
        }

        return .result(dialog: "Today: " + parts.joined(separator: ", ") + ".")
    }
}

// MARK: - SetMoodIntent

/// "Hey Siri, set my mood to focused"
struct SetMoodIntent: AppIntent {

    static var title: LocalizedStringResource = "Set Today's Mood"
    static var description = IntentDescription("Record how you're feeling right now.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Mood", description: "How are you feeling?", default: "neutral")
    var mood: String

    static var parameterSummary: some ParameterSummary {
        Summary("Set mood to \(\($mood))")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let action = AMORPendingAction(
            type: .setMood,
            parameters: ["mood": mood]
        )
        AMORPendingActionStore.enqueue(action)

        // Also persist immediately for snapshot reads
        UserDefaults(suiteName: kFlowAppGroup)?.set(mood, forKey: "amor.lastKnownMood")

        return .result(dialog: "Mood set to \(mood). Noted with care.")
    }
}

// MARK: - AppShortcutsProvider

/// Automatically exposes key AMOR intents as Siri phrases.
/// The system discovers these and offers them in the Shortcuts app,
/// Spotlight, and Siri suggestions.
struct AMORShortcutsProvider: AppShortcutsProvider {

    @AppShortcutsBuilder
    static var appShortcuts: some AppShortcut {
        // Core daily actions
        AppShortcut(
            intent: LogSessionIntent(),
            phrases: [
                "Log a session in \(.applicationName)",
                "Log focus time in \(.applicationName)",
                "Record a work session in \(.applicationName)"
            ],
            shortTitle: "Log Session",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: CompletePracticeIntent(),
            phrases: [
                "Complete practice in \(.applicationName)",
                "Mark practice done in \(.applicationName)",
                "Complete \(.applicationName) practice"
            ],
            shortTitle: "Complete Practice",
            systemImageName: "checkmark.circle"
        )

        // Query intents
        AppShortcut(
            intent: DailySummaryIntent(),
            phrases: [
                "Today's summary in \(.applicationName)",
                "AMOR summary",
                "What did I do today in \(.applicationName)"
            ],
            shortTitle: "Today's Summary",
            systemImageName: "doc.text"
        )

        AppShortcut(
            intent: CheckStreakIntent(),
            phrases: [
                "Check my streaks in \(.applicationName)",
                "AMOR streaks",
                "What practices are due in \(.applicationName)"
            ],
            shortTitle: "Check Streaks",
            systemImageName: "flame"
        )

        AppShortcut(
            intent: SystemHealthIntent(),
            phrases: [
                "System health in \(.applicationName)",
                "AMOR system status",
                "Check cron jobs in \(.applicationName)"
            ],
            shortTitle: "System Health",
            systemImageName: "gearshape"
        )

        AppShortcut(
            intent: SetMoodIntent(),
            phrases: [
                "Set my mood in \(.applicationName)",
                "Record mood in \(.applicationName)"
            ],
            shortTitle: "Set Mood",
            systemImageName: "face.smiling"
        )
    }
}

// MARK: - Intent Reconciliation Helper

/// Processes the pending action queue and applies changes to SwiftData.
/// Called from FlowApp on scenePhase .active.
@MainActor
enum AMORIntentReconciler {

    /// Process all pending actions. Returns a summary of what was applied.
    static func reconcile(into context: ModelContext) -> (sessionsLogged: Int, practicesCompleted: Int, moodsSet: Int) {
        let actions = AMORPendingActionStore.readAll()
        guard !actions.isEmpty else { return (0, 0, 0) }

        var sessionsLogged = 0
        var practicesCompleted = 0
        var moodsSet = 0
        var processedIds: Set<UUID> = []

        for action in actions {
            switch action.type {
            case .logSession:
                let title = action.parameters["title"] ?? "Siri Session"
                let duration = Int(action.parameters["durationMinutes"] ?? "30") ?? 30
                let mood = action.parameters["mood"] ?? "neutral"
                let tools = action.parameters["tools"] ?? ""

                let session = DailySession(
                    title: title,
                    durationMinutes: duration,
                    mood: mood,
                    toolsUsed: tools
                )
                context.insert(session)
                sessionsLogged += 1
                processedIds.insert(action.id)

            case .completePractice:
                let practiceName = action.parameters["practiceName"] ?? ""

                // Try to find existing practice
                let descriptor = FetchDescriptor<PracticeStreak>(
                    predicate: #Predicate<PracticeStreak> { $0.practiceName == practiceName }
                )
                if let practice = try? context.fetch(descriptor).first {
                    practice.complete()
                    practicesCompleted += 1
                    processedIds.insert(action.id)
                } else {
                    // Create new practice if it doesn't exist
                    let newPractice = PracticeStreak(practiceName: practiceName, goal: "daily")
                    newPractice.complete()
                    context.insert(newPractice)
                    practicesCompleted += 1
                    processedIds.insert(action.id)
                }

            case .setMood:
                let mood = action.parameters["mood"] ?? "neutral"

                // Update or create today's summary with mood
                let startOfDay = Calendar.current.startOfDay(for: Date())
                let descriptor = FetchDescriptor<DailySummary>(
                    predicate: #Predicate<DailySummary> { $0.date >= startOfDay }
                )
                if let summary = try? context.fetch(descriptor).first {
                    summary.mood = mood
                } else {
                    let summary = DailySummary(mood: mood)
                    context.insert(summary)
                }
                moodsSet += 1
                processedIds.insert(action.id)
            }
        }

        // Persist all changes
        try? context.save()

        // Clear processed actions
        AMORPendingActionStore.remove(ids: processedIds)

        return (sessionsLogged, practicesCompleted, moodsSet)
    }
}
