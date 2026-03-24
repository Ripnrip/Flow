/**
 * ⚙️ FlowWidget Configuration Intent
 *
 * "The user's preferences for what the Flow widget shows and how.
 * Backed by AppIntentConfiguration so the widget adapts per-placement."
 *
 * Note: The old ConfigurationAppIntent / favoriteEmoji placeholder is replaced
 * with the production FlowWidgetConfiguration.
 * WidgetsControl.swift keeps its own TimerConfiguration separately.
 */

import AppIntents
import WidgetKit

// MARK: - 🎛️ Widget Configuration

struct FlowWidgetConfiguration: WidgetConfigurationIntent {

    static var title: LocalizedStringResource = "Flow Task Widget"
    static var description = IntentDescription(
        "Show your active focus task with live state and quick actions."
    )

    /// Show elapsed time counter in the widget body.
    @Parameter(title: "Show Elapsed Time", default: true)
    var showElapsedTime: Bool

    /// Show Snooze / Done action buttons (medium and large sizes only).
    @Parameter(title: "Show Action Buttons", default: true)
    var showActions: Bool
}
