/**
 * 🧪 Xcode Previews - The Looking Glass
 *
 * "A glimpse into the many facets of our creation.
 * It allows us to witness the dance of pixels across all states and modes."
 */

import ActivityKit
import WidgetKit
import SwiftUI

#Preview("Cosmic Nebula - Expanded", as: .dynamicIsland(.expanded), using: FlowAttributes.preview) {
   Flow_Intents_Widgets_ExtensionLiveActivity()
} contentStates: {
    FlowAttributes.ContentState(title: "Star Gazing", snoozeCount: 0, moveCount: 0, startDate: .now, emoji: "🌌", style: .cosmicNebula)
}

#Preview("Blueprint - Compact", as: .dynamicIsland(.compact), using: FlowAttributes.preview) {
   Flow_Intents_Widgets_ExtensionLiveActivity()
} contentStates: {
    FlowAttributes.ContentState(title: "Building Skyscrapers", snoozeCount: 1, moveCount: 0, startDate: .now, emoji: "🏗️", style: .blueprint)
}

#Preview("Courier Prime - Lock Screen", as: .content, using: FlowAttributes.preview) {
   Flow_Intents_Widgets_ExtensionLiveActivity()
} contentStates: {
    FlowAttributes.ContentState(title: "Package Delivery", snoozeCount: 0, moveCount: 0, startDate: .now, emoji: "📦", style: .courierPrime)
}

#Preview("Circuit Board - Minimal", as: .dynamicIsland(.minimal), using: FlowAttributes.preview) {
   Flow_Intents_Widgets_ExtensionLiveActivity()
} contentStates: {
    FlowAttributes.ContentState(title: "Kernel Logic", snoozeCount: 3, moveCount: 0, startDate: .now, emoji: "🚥", style: .circuitBoard)
}

#Preview("Glassmorphism - Expanded", as: .dynamicIsland(.expanded), using: FlowAttributes.preview) {
   Flow_Intents_Widgets_ExtensionLiveActivity()
} contentStates: {
    FlowAttributes.ContentState(title: "Translucent Focus", snoozeCount: 2, moveCount: 1, startDate: .now, emoji: "🪟", style: .glassmorphism)
}

#Preview("Pixel Art Hero - Quest", as: .dynamicIsland(.expanded), using: FlowAttributes.preview) {
   Flow_Intents_Widgets_ExtensionLiveActivity()
} contentStates: {
    FlowAttributes.ContentState(title: "Leveling Up", snoozeCount: 0, moveCount: 0, startDate: .now, emoji: "⚔️", style: .pixelArtHero)
}

#Preview("Liquid Metal - Flow", as: .dynamicIsland(.expanded), using: FlowAttributes.preview) {
   Flow_Intents_Widgets_ExtensionLiveActivity()
} contentStates: {
    FlowAttributes.ContentState(title: "Mercury State", snoozeCount: 4, moveCount: 2, startDate: .now, emoji: "💧", style: .liquidMetal)
}

#Preview("Solar Flare - Heat", as: .dynamicIsland(.expanded), using: FlowAttributes.preview) {
   Flow_Intents_Widgets_ExtensionLiveActivity()
} contentStates: {
    FlowAttributes.ContentState(title: "Core Meltdown", snoozeCount: 1, moveCount: 0, startDate: .now, emoji: "☀️", style: .solarFlare)
}

#Preview("Sketchbook - Hand Drawn", as: .dynamicIsland(.expanded), using: FlowAttributes.preview) {
   Flow_Intents_Widgets_ExtensionLiveActivity()
} contentStates: {
    FlowAttributes.ContentState(title: "Drawing Dreams", snoozeCount: 0, moveCount: 0, startDate: .now, emoji: "🖍️", style: .sketchbook)
}

#Preview("Deep Space - Void", as: .dynamicIsland(.expanded), using: FlowAttributes.preview) {
   Flow_Intents_Widgets_ExtensionLiveActivity()
} contentStates: {
    FlowAttributes.ContentState(title: "Eternal Focus", snoozeCount: 0, moveCount: 0, startDate: .now, emoji: "🖤", style: .deepSpace)
}
