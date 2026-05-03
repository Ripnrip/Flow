/**
 * 📦 WidgetsBundle — The Widget Registry
 *
 * All Widget and ControlWidget types must be declared here.
 * The system discovers them at launch and renders each in its
 * appropriate context (Home Screen, Lock Screen, StandBy, Control Center).
 *
 *  FlowWidget         — Home/Lock Screen task state mirror (.systemSmall/Medium/Large + accessory)
 *  FlowFocusControl   — Control Center focus-session toggle (reads SharedTaskStore)
 *  WidgetsLiveActivity— Dynamic Island + Lock Screen Live Activity
 */

import WidgetKit
import SwiftUI

@main
struct WidgetsBundle: WidgetBundle {
    var body: some Widget {
        // 📱 Task state widget (replaces old placeholder Widgets())
        FlowWidget()

        // 🎛️ Control Center toggle (replaces boilerplate WidgetsControl)
        FlowFocusControl()

        // 🏝️ Live Activity (Dynamic Island + Lock Screen banner)
        WidgetsLiveActivity()
    }
}
