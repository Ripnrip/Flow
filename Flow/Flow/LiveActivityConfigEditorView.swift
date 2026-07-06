/**
 * ✨ LiveActivityConfigEditorView — The Lock Screen Ritual
 *
 * "Choose the spirits that attend your focus ritual:
 *  two actions, a progress ring, and the intensity of the magic."
 */

import SwiftUI
import WidgetKit

struct LiveActivityConfigEditorView: View {
    @State private var config = LiveActivityConfiguration.default

    var body: some View {
        Form {
            Section("Action Buttons") {
                Picker("Leading", selection: $config.leadingAction) {
                    ForEach(LiveActivityAction.allCases, id: \.self) { action in
                        Text(action.displayName).tag(action)
                    }
                }

                Picker("Trailing", selection: $config.trailingAction) {
                    ForEach(LiveActivityAction.allCases, id: \.self) { action in
                        Text(action.displayName).tag(action)
                    }
                }
            }

            Section("Appearance") {
                Toggle("Show Progress Ring", isOn: $config.showProgressRing)

                Picker("Animation Intensity", selection: $config.animationIntensity) {
                    ForEach(LiveActivityAnimationIntensity.allCases, id: \.self) { intensity in
                        Text(intensity.displayName).tag(intensity)
                    }
                }
            }
        }
        .navigationTitle("Live Activity")
        .onAppear(perform: loadConfig)
        .onChange(of: config) { _, _ in
            Task { await saveConfig() }
        }
    }

    private func loadConfig() {
        Task {
            let loaded = await SharedTaskStore.shared.loadLiveActivityConfiguration()
            await MainActor.run {
                config = loaded
            }
        }
    }

    private func saveConfig() async {
        await SharedTaskStore.shared.saveLiveActivityConfiguration(config)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension LiveActivityAction {
    var displayName: String {
        switch self {
        case .snooze:      "Snooze"
        case .done:        "Done"
        case .pauseResume: "Pause / Resume"
        case .extend:      "Extend 5 min"
        }
    }
}

extension LiveActivityAnimationIntensity {
    var displayName: String {
        switch self {
        case .calm:   "Calm"
        case .normal: "Normal"
        case .lively: "Lively"
        }
    }
}
