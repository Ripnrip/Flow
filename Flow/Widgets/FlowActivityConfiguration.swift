import ActivityKit
import SwiftUI
import WidgetKit // Required for ActivityConfiguration

// This file must reside in the target that hosts the Live Activity Extension.

// This view acts as the entry point for the Live Activity (and lock screen content).
struct FlowActivityConfiguration: Widget {
    // 1. Define the unique kind for this Live Activity
    let kind: String = "FlowActivity"

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlowAttributes.self) { context in
            // Lock Screen/Full Banner Presentation (if space permits, up to iOS 16.1)
            // This is the implementation for the Lock Screen and Notification Center
            FlowLiveActivityView(context: context)
                .activityBackgroundTint(context.state.style.themeBackgroundColor().opacity(0.9))
            
        } dynamicIsland: { context in
            // Dynamic Island Presentation
            
            // Standard compact/minimal UI elements are required here.
            // Since we need to handle all three states (compact, minimal, expanded)
            // we will primarily use the Compact/Minimal representations for the Dynamic Island
            
            DynamicIsland {
                // Expanded region views
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.title).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CompactStateBadge(
                        style: context.state.style,
                        label: "Snooze",
                        icon: "bed.double.fill",
                        count: context.state.snoozeCount
                    )
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        // Style/Theme Indicator
                        Text(context.state.style.rawValue)
                            .font(.caption)
                            .foregroundStyle(context.state.style.themeAccentColor())
                        
                        // Action buttons (Snooze, Complete) would go here, often linked via URL
                        Link(destination: URL(string: "focus://snoozeTask/\(context.attributes.taskId)")!) {
                            Text("Snooze")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(context.state.style.themeAccentColor())
                        
                        Spacer()
                        
                        Text(context.state.startDate, style: .timer)
                            .font(.title3.monospacedDigit()).bold()
                    }
                }
            } compactLeading: {
                // Compact Leading: Emoji and Title start letter
                BreathingEmojiView(
                    emoji: context.state.emoji,
                    style: context.state.style,
                    compact: true,
                    growthLevel: context.state.growthLevel
                )
                .frame(width: 20, height: 20)
                Text(context.state.title.prefix(1))
            } compactTrailing: {
                // Compact Trailing: Timer
                Text(context.state.startDate, style: .timer)
                    .widgetAccentable()
                    .font(.caption.monospacedDigit()).bold()
            } minimal: {
                // Minimal: Emoji
                BreathingEmojiView(
                    emoji: context.state.emoji,
                    style: context.state.style,
                    compact: true,
                    growthLevel: context.state.growthLevel
                )
                .frame(width: 15, height: 15)
            }
            .widgetURL(URL(string: "focus://task/\(context.attributes.taskId)"))
            .keylineTint(context.state.style.themeAccentColor())
        }
    }
}

