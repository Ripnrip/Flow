/**
 * 🎭 Common Views - The Shared Visual Language
 *
 * "A collection of UI elements that transcend boundaries,
 * appearing in both the main gallery and the pulsing islands."
 */

import SwiftUI

struct StyleBackground: View {
    let style: TaskStyle

    var body: some View {
        Group {
            switch style {
            case .cyberpunk, .vintageArcade:
                Color.black.overlay(gridOverlay(color: style == .cyberpunk ? .yellow : .pink))
            case .blueprint:
                Color(red: 0.0, green: 0.1, blue: 0.3).overlay(gridOverlay(color: .cyan.opacity(0.2)))
            case .cosmicNebula, .cosmicVoid, .deepSpace, .velvetNight:
                ZStack {
                    Color(red: 0.05, green: 0.0, blue: 0.15)
                    CosmicParticleSystem(color: style.themeAccentColor())
                    RadialGradient(colors: [style.themeAccentColor().opacity(0.4), .clear], center: .center, startRadius: 0, endRadius: 200)
                }
            case .sunsetSilk, .sunsetGlow, .solarFlare:
                LinearGradient(colors: [.orange.opacity(0.4), .pink.opacity(0.4), .purple.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .oceanFlow, .liquidMetal:
                LinearGradient(colors: [.blue.opacity(0.4), .teal.opacity(0.2)], startPoint: .top, endPoint: .bottom)
            case .volcanicFlow:
                Color(red: 0.1, green: 0.05, blue: 0.0).overlay(RadialGradient(colors: [.orange.opacity(0.2), .clear], center: .bottom, startRadius: 0, endRadius: 150))
            case .industrialRust, .steampunk, .courierPrime:
                Color(red: 0.1, green: 0.08, blue: 0.05).overlay(noiseOverlay())
            case .vintageNewspaper, .sketchbook:
                Color(red: 0.9, green: 0.85, blue: 0.7).overlay(noiseOverlay())
            case .neoBrutalism, .opaqueBold:
                Color.white
            case .circuitBoard:
                Color.black.overlay(circuitOverlay())
            case .livingGarden, .magicalForest:
                ZStack {
                    Color(red: 0.05, green: 0.1, blue: 0.05)
                    ForestParticleSystem(color: style == .magicalForest ? .yellow : .green)
                }
            case .bioLuminescence:
                ZStack {
                    Color(red: 0.0, green: 0.05, blue: 0.1)
                    ForestParticleSystem(color: .teal, isGlow: true)
                }
            case .glassmorphism, .holographic, .crystalCave:
                ZStack {
                    if style == .glassmorphism {
                        Rectangle().fill(.ultraThinMaterial)
                    } else {
                        Color.black
                    }
                    CosmicParticleSystem(color: .cyan.opacity(0.3))
                }
            default:
                Color.clear
            }
        }
    }

    private func gridOverlay(color: Color) -> some View {
        Path { path in
            for index in 0..<20 {
                path.move(to: CGPoint(x: 0, y: CGFloat(index * 20)))
                path.addLine(to: CGPoint(x: 500, y: CGFloat(index * 20)))
                path.move(to: CGPoint(x: CGFloat(index * 20), y: 0))
                path.addLine(to: CGPoint(x: CGFloat(index * 20), y: 500))
            }
        }
        .stroke(color.opacity(0.1), lineWidth: 0.5)
    }

    private func circuitOverlay() -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 10, y: 10))
                path.addLine(to: CGPoint(x: 100, y: 10))
                path.addLine(to: CGPoint(x: 120, y: 30))
                path.move(to: CGPoint(x: 200, y: 50))
                path.addLine(to: CGPoint(x: 250, y: 50))
            }.stroke(Color.green.opacity(0.2), lineWidth: 1)
            Circle().fill(Color.green.opacity(0.3)).frame(width: 4, height: 4).position(x: 10, y: 10)
            Circle().fill(Color.green.opacity(0.3)).frame(width: 4, height: 4).position(x: 120, y: 30)
        }
    }

    private func noiseOverlay() -> some View {
        Color.black.opacity(0.05)
            .overlay(
                Image(systemName: "circle.fill")
                    .resizable()
                    .opacity(0.02)
                    .scaleEffect(10)
            )
    }
}

// MARK: - Component Alchemy

/// A small, themed badge used to display state information (e.g., snooze count, time)
struct CompactStateBadge: View {
    let style: TaskStyle
    let label: String
    let icon: String?
    let count: Int?

    init(style: TaskStyle, label: String, icon: String? = nil, count: Int? = 0) {
        self.style = style
        self.label = label
        self.icon = icon
        self.count = count
    }
    
    init(style: TaskStyle, label: String) {
        // Simpler initializer for use in StyleGalleryView preview
        self.init(style: style, label: label, icon: nil, count: nil)
    }
    
    var displayText: String {
        if let count = count {
            return count > 0 ? "\(label) (\(count))" : label
        }
        return label
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(displayText)
                .font(.caption2).bold()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(style.themeAccentColor().opacity(style == .neoBrutalism ? 1.0 : 0.2))
        .cornerRadius(4)
        .foregroundColor(style.themeForegroundColor())
        .colorMultiply(style == .neoBrutalism ? style.themeBackgroundColor() : .white) // Brutalism high contrast fix
        .transition(.scale)
    }
}


struct BreathingEmojiView: View {
    // Properties must be defined without default values if initialized externally,
    // which is the case in FlowLiveActivityView.
    let emoji: String
    let style: TaskStyle
    var compact: Bool
    var growthLevel: Int 
    @State private var breath: CGFloat = 1.0 

    var body: some View {
        Text(emoji)
            .font(compact ? .title2 : .largeTitle)
            .scaleEffect(1 + (breath * 0.1))
            .onAppear {
                withAnimation(.easeInOut(duration: breathingDuration).repeatForever(autoreverses: true)) {
                    breath = 0.0
                }
            }
    }

    private var breathingDuration: Double {
        switch style {
        case .zenFocus, .magicalScroll: return 4.0
        case .cyberpunk, .retroPixel: return 1.5
        case .volcanicFlow, .solarFlare: return 1.0
        default: return 2.5
        }
    }
}

struct StyleProgressView: View {
    // Placeholder definition to fulfill references
    let progress: Double = 0.5
    let style: TaskStyle = .sleekModern
    var body: some View {
        ProgressView(value: progress)
            .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
    }
    private var progressColor: Color {
        switch style {
        case .livingGarden, .magicalForest: return .green
        case .volcanicFlow, .industrialRust, .solarFlare: return .orange
        case .cosmicNebula, .cosmicVoid, .deepSpace, .velvetNight: return .purple
        case .oceanFlow, .liquidMetal: return .blue
        case .blueprint: return .cyan
        case .courierPrime: return .yellow
        default: return .blue
        }
    }
}

struct ThemeButtonStyle: ButtonStyle {
    // Placeholder definition to fulfill references
    let style: TaskStyle = .sleekModern
    var prominent: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(buttonBackgroundColor)
            .foregroundColor(buttonForegroundColor)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }

    private var buttonBackgroundColor: Color {
        if prominent {
            return style.themeAccentColor()
        }
        return style.themeBackgroundColor().opacity(0.5)
    }

    private var buttonForegroundColor: Color {
        if style == .neoBrutalism || style == .softClay || ((style == .vintageNewspaper || style == .steampunk || style == .sketchbook) && !prominent) {
            return .black
        }
        return .white
    }
}

// MARK: - 📱 Live Activities (The Peripheral Island UI)

#if os(iOS)
import Foundation // Added import to ensure all base types are resolved
import ActivityKit
import WidgetKit

// Assuming the module containing FlowAttributes is named 'Flow'
// We use the explicit module name prefix to resolve potential ambiguity 
// between the main app target and a widget extension target.
public typealias LiveActivityAttributes = FlowAttributes

public struct FlowLiveActivityView: View {
    // Note: We cannot rely on State/ObservedObject in Live Activities.
    // The view uses DynamicContent, but we accept the full state here for previews/easier implementation.
    let context: ActivityViewContext<LiveActivityAttributes>

    var state: LiveActivityAttributes.ContentState {
        context.state
    }

    var style: TaskStyle {
        state.style
    }

    // Since Live Activities don't support complex UI like Canvas or TimelineView,
    // we focus on utilizing the style engine for colors, fonts, and simple elements.

    public var body: some View {
        // Use the large background structure but keep it simple enough for Live Activities
        ZStack {
            // Background Layer: Use a simple color or material suitable for Live Activities
            style.themeBackgroundColor().opacity(0.9)
            
            // Dynamic Island Compact/Minimal Presentation
            // Note: Exact layout depends on the ActivityConfiguration, but here is the general content area
            HStack(spacing: 8) {
                // Focus Symbol
                BreathingEmojiView(
                    emoji: state.emoji,
                    style: style,
                    compact: true,
                    growthLevel: state.growthLevel
                )
                .frame(width: 30, height: 30)

                // Task Title
                VStack(alignment: .leading, spacing: 2) {
                    Text(style.rawValue)
                        .font(.caption)
                        .foregroundStyle(style.themeAccentColor())

                    Text(state.title) // Use state.title as content
                        .font(style.themeFont(size: .system(size: 14))).bold() // Apply font using modifier
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                // State Badges
                VStack(alignment: .trailing) {
                    CompactStateBadge(
                        style: style,
                        label: "Snooze",
                        icon: "bed.double.fill",
                        count: state.snoozeCount
                    )
                    
                    // Simple elapsed time indicator (Live Activities handle time display)
                    Text(state.startDate, style: .timer)
                        .font(.caption.monospacedDigit()).bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(style.themeForegroundColor().opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding(12)
        }
        .widgetURL(URL(string: "focus://task/\(context.attributes.taskId)")) // Deep linking support
    }
}
#endif


// MARK: - ✨ Particle Alchemy (Lottie-inspired Native SwiftUI)

struct CosmicParticleSystem: View {
    let color: Color
    
    var body: some View {
        // Simple placeholder for a complex particle effect
        // In a real app, this would use Canvas, GeometryReader, or a custom Metal/SpriteKit view.
        Circle()
            .fill(color)
            .frame(width: 1, height: 1)
            .opacity(0.1)
            .blur(radius: 0.5)
            .modifier(MovingParticle(delay: Double.random(in: 0...2)))
    }
}

struct ForestParticleSystem: View {
    let color: Color
    var isGlow: Bool = false

    var body: some View {
        // Simple placeholder for a complex particle effect (fireflies/garden glints)
        // Similar to CosmicParticleSystem, this structure requires a more complex implementation
        // for a realistic effect.
        if isGlow {
            Rectangle()
                .fill(color)
                .brightness(0.5)
                .frame(width: 5, height: 5)
                .opacity(0.05)
                .blur(radius: 5)
                .modifier(MovingParticle(delay: Double.random(in: 0...3)))
        } else {
            Rectangle()
                .fill(color)
                .brightness(-0.1)
                .frame(width: 2, height: 2)
                .opacity(0.05)
                .modifier(MovingParticle(delay: Double.random(in: 0...1)))
        }
    }
}

// Helper modifier for particle movement placeholder
private struct MovingParticle: ViewModifier {
    @State private var phase: CGFloat = 0
    let delay: Double

    func body(content: Content) -> some View {
        content
            .offset(x: sin(phase * 0.5) * 50, y: cos(phase * 0.7) * 50)
            .onAppear {
                withAnimation(.linear(duration: 5.0).delay(delay).repeatForever(autoreverses: true)) {
                    phase = .pi * 2
                }
            }
    }
}
