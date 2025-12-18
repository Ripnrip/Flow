//
//  WidgetsLiveActivity.swift
//  Widgets
//
//  Created by admin on 12/17/25.
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

// Since FlowAttributes is defined publicly in SharedModels, we rely on it.
// Removed struct WidgetsAttributes: ActivityAttributes { ... }

struct WidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlowAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                expandedLeadingRegion(context: context)
                expandedTrailingRegion(context: context)
                expandedCenterRegion(context: context)
                expandedBottomRegion(context: context)
            } compactLeading: {
                compactLeadingView(context: context)
            } compactTrailing: {
                compactTrailingView(context: context)
            } minimal: {
                minimalView(context: context)
            }
            .widgetURL(URL(string: "flow://task/\(context.attributes.taskId)"))
            .keylineTint(context.state.style.themeAccentColor())
        }
    }
    
    // MARK: - 📱 Lock Screen / Banner UI
    
    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<FlowAttributes>) -> some View {
        ZStack {
            StyleBackground(style: context.state.style)
            
            StyleTransitionWave(style: context.state.style, triggerDate: context.state.lastInteractionDate)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 15) {
                    BreathingEmojiView(
                        emoji: context.state.emoji,
                        style: context.state.style,
                        compact: false,
                        growthLevel: context.state.growthLevel
                    )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.title)
                            .font(context.state.style.themeFont(size: .headline))
                            .foregroundStyle(context.state.style.themeForegroundColor())
                        
                        Text("Started \(context.state.startDate, style: .relative) ago")
                            .font(.caption2)
                            .foregroundStyle(context.state.style.themeForegroundColor().opacity(0.6))
                    }
                    
                    Spacer()
                    
                    StyleMetricView(style: context.state.style, snoozeCount: context.state.snoozeCount, moveCount: context.state.moveCount)
                }
            }
            .padding()
        }
        .activityBackgroundTint(context.state.style.themeBackgroundColor())
        .activitySystemActionForegroundColor(context.state.style.themeForegroundColor())
    }
    
    // MARK: - 🌟 Dynamic Island - Expanded Regions
    
    @DynamicIslandExpandedContentBuilder
    private func expandedLeadingRegion(context: ActivityViewContext<FlowAttributes>) -> DynamicIslandExpandedContent<some View> {
        DynamicIslandExpandedRegion(.leading) {
            HStack {
                BreathingEmojiView(
                    emoji: context.state.emoji,
                    style: context.state.style,
                    compact: false,
                    growthLevel: context.state.growthLevel
                )
                .frame(width: 32, height: 32)
            }
            .padding(.leading, 8)
        }
    }
    
    @DynamicIslandExpandedContentBuilder
    private func expandedTrailingRegion(context: ActivityViewContext<FlowAttributes>) -> DynamicIslandExpandedContent<some View> {
        DynamicIslandExpandedRegion(.trailing) {
            Text(context.state.startDate, style: .timer)
                .font(.system(size: 18, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(context.state.style.themeForegroundColor())
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.trailing, 4)
        }
    }

    @DynamicIslandExpandedContentBuilder
    private func expandedCenterRegion(context: ActivityViewContext<FlowAttributes>) -> DynamicIslandExpandedContent<some View> {
        DynamicIslandExpandedRegion(.center) {
            Text(context.state.title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(context.state.style.themeForegroundColor())
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity)
        }
    }
    
    @DynamicIslandExpandedContentBuilder
    private func expandedBottomRegion(context: ActivityViewContext<FlowAttributes>) -> DynamicIslandExpandedContent<some View> {
        DynamicIslandExpandedRegion(.bottom) {
            VStack(spacing: 8) {
                // Progress Indicator
                StyleProgressView(style: context.state.style)
                    .frame(height: 4)
                    .padding(.horizontal, 16)
                
                // Buttons Row
                HStack(spacing: 8) {
                    // Snooze Button
                    Button(intent: SnoozeIntent(taskId: context.attributes.taskId)) {
                        HStack(spacing: 4) {
                            Image(systemName: "bed.double.fill")
                                .font(.system(size: 14))
                            Text("Snooze")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(context.state.style.themeBackgroundColor().opacity(0.2))
                        .foregroundStyle(context.state.style.themeForegroundColor())
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    // Done Button
                    Button(intent: DoneIntent(taskId: context.attributes.taskId)) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                            Text(doneButtonLabel(for: context.state.style))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(context.state.style.themeAccentColor())
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 8)
        }
    }
    
    // MARK: - 🔸 Dynamic Island - Compact & Minimal
    
    @ViewBuilder
    private func compactLeadingView(context: ActivityViewContext<FlowAttributes>) -> some View {
        BreathingEmojiView(
            emoji: context.state.emoji,
            style: context.state.style,
            compact: true,
            growthLevel: context.state.growthLevel
        )
    }
    
    @ViewBuilder
    private func compactTrailingView(context: ActivityViewContext<FlowAttributes>) -> some View {
        HStack(spacing: 2) {
            Text("\(context.state.snoozeCount)")
                .monospacedDigit()
            Text(compactTrailingIcon(for: context.state.style))
        }
        .font(.caption2.bold())
    }
    
    @ViewBuilder
    private func minimalView(context: ActivityViewContext<FlowAttributes>) -> some View {
        BreathingEmojiView(
            emoji: context.state.emoji,
            style: context.state.style,
            compact: true,
            growthLevel: context.state.growthLevel
        )
    }
    
    // MARK: - 🎨 Helpers
    
    private func doneButtonLabel(for style: TaskStyle) -> String {
        switch style {
        case .questMode: return "Slay"
        case .magicalScroll: return "Cast"
        case .volcanicFlow: return "Extinguish"
        case .livingGarden: return "Harvest"
        case .spaceMission: return "Deploy"
        case .courierPrime: return "Delivered"
        default: return "Done"
        }
    }
    
    private func compactTrailingIcon(for style: TaskStyle) -> String {
        switch style {
        case .livingGarden: return "🌿"
        case .cosmicNebula, .cosmicVoid, .deepSpace: return "✨"
        case .bioLuminescence, .oceanFlow, .liquidMetal: return "🫧"
        case .volcanicFlow, .solarFlare: return "🔥"
        case .spaceMission: return "🚀"
        case .courierPrime: return "📦"
        case .circuitBoard: return "🚥"
        default: return "💤"
        }
    }
}

// MARK: - 🧪 Previews (Updated to use FlowAttributes)

// 1. Create a concrete type alias for FlowAttributes used in the preview
typealias LAAttributes = FlowAttributes

// 2. Add static preview data to LAAttributes
extension FlowAttributes {
    static var preview: FlowAttributes {
        FlowAttributes(taskId: UUID().uuidString)
    }
}
// 3. Define content states using FlowAttributes.ContentState structure
// 3. Define content states using FlowAttributes.ContentState structure
extension LAAttributes.ContentState {
    
    static var focusSession: LAAttributes.ContentState {
       make(emoji: "💻", title: "Review Codebase Logic", style: .cyberpunk)
    }
    
    static var gardenSession: LAAttributes.ContentState {
       make(emoji: "🌿", title: "Write Weekly Report Structure", style: .livingGarden)
    }
    
    // Generate individual states for each TaskStyle
    static var cyberpunk: LAAttributes.ContentState {
        make(emoji: "💻", title: "Cyberpunk Flow", style: .cyberpunk)
    }
    
    static var livingGarden: LAAttributes.ContentState {
        make(emoji: "🌿", title: "Living Garden", style: .livingGarden)
    }
    
    static var volcanicFlow: LAAttributes.ContentState {
        make(emoji: "🌋", title: "Volcanic Flow", style: .volcanicFlow)
    }
    
    static var cosmicNebula: LAAttributes.ContentState {
        make(emoji: "✨", title: "Cosmic Nebula", style: .cosmicNebula)
    }
    
    static var spaceMission: LAAttributes.ContentState {
        make(emoji: "🚀", title: "Space Mission", style: .spaceMission)
    }
    
    static var oceanFlow: LAAttributes.ContentState {
        make(emoji: "🌊", title: "Ocean Flow", style: .oceanFlow)
    }
    
    static var solarFlare: LAAttributes.ContentState {
        make(emoji: "☀️", title: "Solar Flare", style: .solarFlare)
    }
    
    static var bioLuminescence: LAAttributes.ContentState {
        make(emoji: "🦠", title: "Bio Luminescence", style: .bioLuminescence)
    }
    
    static var deepSpace: LAAttributes.ContentState {
        make(emoji: "🌌", title: "Deep Space", style: .deepSpace)
    }
    
    static var cosmicVoid: LAAttributes.ContentState {
        make(emoji: "🕳️", title: "Cosmic Void", style: .cosmicVoid)
    }
    
    static var liquidMetal: LAAttributes.ContentState {
        make(emoji: "💧", title: "Liquid Metal", style: .liquidMetal)
    }
    
    static var circuitBoard: LAAttributes.ContentState {
        make(emoji: "🔌", title: "Circuit Board", style: .circuitBoard)
    }
    
    static var questMode: LAAttributes.ContentState {
        make(emoji: "⚔️", title: "Quest Mode", style: .questMode)
    }
    
    static var magicalScroll: LAAttributes.ContentState {
        make(emoji: "📜", title: "Magical Scroll", style: .magicalScroll)
    }
    
    static var courierPrime: LAAttributes.ContentState {
        make(emoji: "📦", title: "Courier Prime", style: .courierPrime)
    }

    static func make(
        emoji: String,
        title: String,
        style: TaskStyle
    ) -> LAAttributes.ContentState {
        return LAAttributes.ContentState(
            title: title,
            snoozeCount: 0,
            moveCount: 1,
            startDate: Date().addingTimeInterval(-1800), // 30 minutes ago
            emoji: emoji,
            style: style,
            growthLevel: 1
        )
    }
}

// 1. Lock Screen / Banner UI
#Preview("Lock Screen", as: .content, using: LAAttributes.preview) {
   WidgetsLiveActivity()
} contentStates: {
    LAAttributes.ContentState.cyberpunk
    LAAttributes.ContentState.livingGarden
    LAAttributes.ContentState.volcanicFlow
    LAAttributes.ContentState.cosmicNebula
    LAAttributes.ContentState.spaceMission
}

// 2. Dynamic Island - Compact
#Preview("Dynamic Island - Compact", as: .dynamicIsland(.compact), using: LAAttributes.preview) {
   WidgetsLiveActivity()
} contentStates: {
    LAAttributes.ContentState.cyberpunk
    LAAttributes.ContentState.livingGarden
    LAAttributes.ContentState.volcanicFlow
}

// 3. Dynamic Island - Minimal
#Preview("Dynamic Island - Minimal", as: .dynamicIsland(.minimal), using: LAAttributes.preview) {
   WidgetsLiveActivity()
} contentStates: {
    LAAttributes.ContentState.cyberpunk
    LAAttributes.ContentState.livingGarden
    LAAttributes.ContentState.volcanicFlow
}

// 4. Dynamic Island - Expanded
#Preview("Dynamic Island - Expanded", as: .dynamicIsland(.expanded), using: LAAttributes.preview) {
   WidgetsLiveActivity()
} contentStates: {
    LAAttributes.ContentState.cyberpunk
    LAAttributes.ContentState.livingGarden
    LAAttributes.ContentState.volcanicFlow
    LAAttributes.ContentState.cosmicNebula
    LAAttributes.ContentState.spaceMission
}

// 5. All Styles - Lock Screen
#Preview("All Styles - Lock Screen", as: .content, using: LAAttributes.preview) {
   WidgetsLiveActivity()
} contentStates: {
    LAAttributes.ContentState.cyberpunk
    LAAttributes.ContentState.livingGarden
    LAAttributes.ContentState.volcanicFlow
    LAAttributes.ContentState.cosmicNebula
    LAAttributes.ContentState.spaceMission
    LAAttributes.ContentState.oceanFlow
    LAAttributes.ContentState.solarFlare
    LAAttributes.ContentState.bioLuminescence
    LAAttributes.ContentState.deepSpace
    LAAttributes.ContentState.cosmicVoid
    LAAttributes.ContentState.liquidMetal
    LAAttributes.ContentState.circuitBoard
    LAAttributes.ContentState.questMode
    LAAttributes.ContentState.magicalScroll
    LAAttributes.ContentState.courierPrime
}

