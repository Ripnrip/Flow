/**
 * 🎛️ AMORWidgetIntents — Interactive Widget Button Intents
 *
 * "One tap on the Home Screen. The streak breathes, the practice is
 *  honored, the rhythm continues — no app launch, no friction, no
 *  excuse. The distance between intention and action collapses to zero."
 *
 * v3.9.0 — Interactive Widgets
 *
 * Architecture (pending-action queue, co-located execution):
 *   • Widget buttons fire these intents INSIDE the widget extension process
 *   • The intent enqueues an AMORPendingAction to App Groups UserDefaults
 *   • The intent ALSO optimistically rewrites the widget snapshot so the
 *     UI feedback is instant (streak +1, checkmark, practices counter)
 *   • WidgetCenter reload re-renders the widget from the optimistic snapshot
 *   • FlowApp.scenePhase(.active) → AMORIntentReconciler commits the real
 *     SwiftData mutation, then syncAMORWidget() overwrites with ground truth
 *
 * Widget interactivity rules honored:
 *   • Only system families (systemSmall / systemMedium) get buttons —
 *     accessory families (Lock Screen / Watch / StandBy) do NOT support
 *     interactive controls and remain display-only
 *   • All intents: openAppWhenRun = false (background, no app launch)
 *
 * App Group: group.com.binarybros.Flow (shared via AMORWidgetShared.swift)
 */

import Foundation
import AppIntents
import WidgetKit

// MARK: - Complete Practice (Widget Button)

/// Taps a practice chip on the Home Screen widget → marks it complete.
/// Used by both the small widget (top streak) and the medium widget
/// (each streak chip in the row).
struct CompletePracticeWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Practice"
    static var description = IntentDescription("Mark a daily practice as complete from the Home Screen widget.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Practice")
    var practiceName: String

    init() {}

    init(practiceName: String) {
        self.practiceName = practiceName
    }

    // No parameterSummary: this intent is only constructed by widget buttons
    // with a fully-resolved parameter — it never shows Shortcuts parameter UI.

    func perform() async throws -> some IntentResult {
        // 1. Queue the real action for SwiftData reconciliation on next foreground
        AMORPendingActionStore.enqueue(
            AMORPendingAction(type: .completePractice, parameters: ["practiceName": practiceName])
        )

        // 2. Optimistically update the App Groups snapshot for instant feedback
        if let snap = AMORWidgetStore.readSnapshot() {
            AMORWidgetStore.writeSnapshot(snap.completingPractice(named: practiceName))
        }

        // 3. Re-render the widget from the optimistic snapshot
        WidgetCenter.shared.reloadTimelines(ofKind: "AMORWidget")

        return .result()
    }
}

// MARK: - Quick Log Session (Widget Button)

/// Tap the "+30m" pill on the medium widget → logs a 30-minute session
/// instantly. Zero-parameter by design: widget buttons must have all
/// parameters resolved at render time, so defaults are baked in.
struct QuickLogSessionWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Log Session"
    static var description = IntentDescription("Log a 30-minute focus session from the Home Screen widget.")
    static var openAppWhenRun: Bool = false

    /// Duration is fixed at 30 minutes for one-tap logging. Users who need
    /// variable durations use the Siri LogSessionIntent or the app itself.
    static let quickLogMinutes = 30

    init() {}

    func perform() async throws -> some IntentResult {
        // 1. Queue the real action for SwiftData reconciliation on next foreground
        AMORPendingActionStore.enqueue(
            AMORPendingAction(
                type: .logSession,
                parameters: [
                    "title": "Quick Log (Widget)",
                    "durationMinutes": String(Self.quickLogMinutes),
                    "mood": "focused"
                ]
            )
        )

        // 2. Optimistically update the App Groups snapshot for instant feedback
        if let snap = AMORWidgetStore.readSnapshot() {
            AMORWidgetStore.writeSnapshot(
                snap.loggingQuickSession(title: "Quick Log (Widget)", minutes: Self.quickLogMinutes)
            )
        }

        // 3. Re-render the widget from the optimistic snapshot
        WidgetCenter.shared.reloadTimelines(ofKind: "AMORWidget")

        return .result()
    }
}
