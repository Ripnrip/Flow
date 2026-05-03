/**
 * 🎛️ WidgetsControl — Focus Flow Control Widget
 *
 * Replaces the Xcode boilerplate timer control with a real "Focus Session"
 * toggle that reads live state from SharedTaskStore and lets the user
 * snooze or resume from Control Center (iOS 18+).
 *
 * Architecture
 * ────────────
 * • `FocusControlProvider`     — reads live task state from SharedTaskStore
 * • `FocusControlValue`        — bool + task-name the toggle reflects
 * • `FocusControlConfiguration` — ControlConfigurationIntent (no params needed)
 * • `ToggleFocusIntent`        — SetValueIntent: writes pending flag to
 *   SharedTaskStore; the app reconciles on next foreground via
 *   TaskService.reconcileFromSharedStore()
 *
 * WidgetsBundle.swift registers FlowFocusControl alongside FlowWidget.
 */

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Control Value

struct FocusControlValue {
    /// `true` when a focus session is actively running.
    var isRunning: Bool
    /// Display name of the active task, or a prompt when idle.
    var taskName: String
}

// MARK: - Control Configuration Intent

struct FocusControlConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Focus Flow Control"
}

// MARK: - Toggle Intent

/// Tapping the toggle in Control Center routes through here.
///
/// When turning **off**: writes `pendingSnooze` so the Live Activity and
/// the app both see a snooze request on next reconcile.
///
/// When turning **on**: writes a `controlPendingStart` hint so the app
/// pre-populates the new-task sheet when it comes to the foreground.
struct ToggleFocusIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Toggle Focus Session"

    @Parameter(title: "Is Running")
    var value: Bool

    init() {}

    func perform() async throws -> some IntentResult {
        if value {
            // Signal the app to start a session on next foreground.
            if let defaults = UserDefaults(suiteName: kFlowAppGroup) {
                defaults.set(true, forKey: "com.binarybros.Flow.controlPendingStart")
            }
        } else {
            // Snooze via SharedTaskStore — app reconciles on foreground.
            await SharedTaskStore.shared.snooze()
        }
        ControlCenter.shared.reloadControls(ofKind: FlowFocusControl.kind)
        return .result()
    }
}

// MARK: - Provider

struct FocusControlProvider: AppIntentControlValueProvider {
    typealias Value = FocusControlValue
    typealias Configuration = FocusControlConfiguration

    func previewValue(configuration: FocusControlConfiguration) -> FocusControlValue {
        FocusControlValue(isRunning: true, taskName: "Review PRs")
    }

    func currentValue(configuration: FocusControlConfiguration) async throws -> FocusControlValue {
        let snapshot = await SharedTaskStore.shared.load()
        let running  = snapshot != nil && !(snapshot?.isCompleted ?? true)
        return FocusControlValue(
            isRunning: running,
            taskName: snapshot?.title ?? "No active task"
        )
    }
}

// MARK: - Control Widget

struct FlowFocusControl: ControlWidget {
    static let kind: String = "com.binarybros.Flow.FocusControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: FocusControlProvider()
        ) { value in
            ControlWidgetToggle(
                value.isRunning ? value.taskName : "Start Focus",
                isOn: value.isRunning,
                action: ToggleFocusIntent()
            ) { isRunning in
                Label(
                    isRunning ? "Focusing" : "Idle",
                    systemImage: "target"
                )
                .symbolEffect(.pulse, isActive: isRunning)
            }
        }
        .displayName("Focus Session")
        .description("Start or snooze your active focus task from Control Center.")
    }
}
