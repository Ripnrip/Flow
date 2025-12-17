/**
 * 🎭 The Live Activity - The Stage of Ambient Productivity
 *
 * "A window into the soul of the current moment, pulsing at the top of the world.
 * It transforms the Dynamic Island into a beacon of intentional action."
 *
 * - The Theatrical Task Virtuoso
 */

#if os(iOS)
import ActivityKit
#endif
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - 🎨 Visual Concept Alchemy (Duplicated for Extension Visibility)

enum TaskStyle: String, Codable, CaseIterable, Sendable {
    case sleekModern = "Sleek Modern"
    case zenFocus = "Zen Focus"
    case questMode = "Quest Mode"
    case livingGarden = "Living Garden"
    case holographic = "Holographic"
    case stickyBoard = "Sticky Board"
    case timeline = "Timeline"
    case ethereal = "Ethereal"
    case neoBrutalism = "Neo-Brutalism"
    case cyberpunk = "Cyberpunk"
    case softClay = "Soft Clay"
    case retroPixel = "Retro Pixel"
    case frostedGlass = "Frosted Glass"
    case organicNature = "Organic Nature"
    case industrialTech = "Industrial Tech"
    case popArt = "Pop Art"
    case zenInk = "Zen Ink"
    case cosmicNebula = "Cosmic Nebula"
    case blueprint = "Blueprint"
    case sunsetSilk = "Sunset Silk"
    case bioLuminescence = "Bio-Luminescence"
    case vintageNewspaper = "Vintage Newspaper"
    case abstractGeometric = "Abstract Geometric"
    case magicalScroll = "Magical Scroll"
    case crystalPrism = "Crystal Prism"
    case volcanicFlow = "Volcanic Flow"
    case cloudPeak = "Cloud Peak"
    case oceanFlow = "Ocean Flow"
    case spaceMission = "Space Mission"
    case vintageArcade = "Vintage Arcade"
    case steampunk = "Steampunk"
    case magicalForest = "Magical Forest"
    case midnightMonochrome = "Midnight Monochrome"
    case sunsetGlow = "Sunset Glow"
    case cosmicVoid = "Cosmic Void"
    case industrialRust = "Industrial Rust"
    case crystalCave = "Crystal Cave"
    case glassmorphism = "Glassmorphism"
    case opaqueBold = "Opaque Bold"
    case courierPrime = "Courier Prime"
    case pixelArtHero = "Pixel Art Hero"
    case circuitBoard = "Circuit Board"
    case liquidMetal = "Liquid Metal"
    case velvetNight = "Velvet Night"
    case sketchbook = "Sketchbook"
    case solarFlare = "Solar Flare"
    case deepSpace = "Deep Space"

    var icon: String {
        switch self {
        case .sleekModern: return "sparkles"
        case .zenFocus: return "leaf"
        case .questMode: return "shield.fill"
        case .livingGarden: return "tree"
        case .holographic: return "square.stack.3d.up"
        case .stickyBoard: return "note"
        case .timeline: return "clock"
        case .ethereal: return "cloud"
        case .neoBrutalism: return "square.fill"
        case .cyberpunk: return "bolt.fill"
        case .softClay: return "circle.fill"
        case .retroPixel: return "gamecontroller"
        case .frostedGlass: return "drop"
        case .organicNature: return "sun.max"
        case .industrialTech: return "gear"
        case .popArt: return "paintpalette"
        case .zenInk: return "pencil.tip"
        case .cosmicNebula: return "star.fill"
        case .blueprint: return "ruler"
        case .sunsetSilk: return "sunset.fill"
        case .bioLuminescence: return "fish.fill"
        case .vintageNewspaper: return "newspaper"
        case .abstractGeometric: return "skew"
        case .magicalScroll: return "scroll.fill"
        case .crystalPrism: return "prism"
        case .volcanicFlow: return "flame.fill"
        case .cloudPeak: return "smoke.fill"
        case .oceanFlow: return "water.waves"
        case .spaceMission: return "rocket.fill"
        case .vintageArcade: return "joystick.fill"
        case .steampunk: return "gearshape.2.fill"
        case .magicalForest: return "camera.macro"
        case .midnightMonochrome: return "moon.fill"
        case .sunsetGlow: return "sun.horizon.fill"
        case .cosmicVoid: return "circle.dotted"
        case .industrialRust: return "hammer.fill"
        case .crystalCave: return "mountain.2.fill"
        case .glassmorphism: return "blur"
        case .opaqueBold: return "square.fill"
        case .courierPrime: return "shippingbox.fill"
        case .pixelArtHero: return "suit.heart.fill"
        case .circuitBoard: return "cpu"
        case .liquidMetal: return "drop.fill"
        case .velvetNight: return "moon.stars.fill"
        case .sketchbook: return "pencil.and.outline"
        case .solarFlare: return "sun.max.fill"
        case .deepSpace: return "infinity"
        }
    }
}

// MARK: - 🧙‍♂️ Theme Engine (Duplicated for Extension Visibility)

extension TaskStyle {
    func themeBackgroundColor() -> Color {
        switch self {
        case .cyberpunk, .midnightMonochrome, .deepSpace: return .black
        case .neoBrutalism, .sketchbook: return .white
        case .ethereal, .cosmicVoid, .cosmicNebula, .velvetNight: return Color(red: 0.05, green: 0.0, blue: 0.15)
        case .livingGarden, .magicalForest: return Color(red: 0.05, green: 0.1, blue: 0.05)
        case .softClay: return Color(red: 0.95, green: 0.9, blue: 0.9)
        case .blueprint: return Color(red: 0.0, green: 0.1, blue: 0.3)
        case .vintageNewspaper: return Color(red: 0.9, green: 0.85, blue: 0.7)
        case .volcanicFlow, .sunsetGlow, .solarFlare: return Color(red: 0.1, green: 0.05, blue: 0.0)
        case .oceanFlow, .liquidMetal: return Color(red: 0.0, green: 0.05, blue: 0.1)
        case .industrialRust: return Color(red: 0.1, green: 0.08, blue: 0.05)
        case .steampunk: return Color(red: 0.15, green: 0.1, blue: 0.05)
        case .courierPrime: return Color(red: 0.1, green: 0.1, blue: 0.1)
        case .circuitBoard: return Color(red: 0.0, green: 0.1, blue: 0.0)
        case .glassmorphism: return .clear
        default: return .black.opacity(0.8)
        }
    }

    func themeForegroundColor() -> Color {
        switch self {
        case .neoBrutalism, .softClay, .vintageNewspaper, .sketchbook: return .black
        case .cyberpunk, .vintageArcade, .courierPrime: return .yellow
        case .livingGarden, .magicalForest, .circuitBoard: return .green
        case .blueprint, .oceanFlow, .crystalCave, .liquidMetal: return .cyan
        case .volcanicFlow, .solarFlare: return .orange
        case .crystalPrism: return .blue
        case .steampunk: return Color(red: 0.8, green: 0.6, blue: 0.2)
        case .pixelArtHero: return .pink
        default: return .white
        }
    }

    func themeAccentColor() -> Color {
        switch self {
        case .cyberpunk: return .cyan
        case .popArt, .pixelArtHero: return .pink
        case .questMode: return .orange
        case .cosmicNebula, .velvetNight: return .purple
        case .crystalPrism, .crystalCave: return .white
        case .bioLuminescence: return .teal
        case .courierPrime: return .yellow
        default: return .blue
        }
    }

    func themeFont(size: Font = .headline) -> Font {
        switch self {
        case .retroPixel, .vintageArcade, .pixelArtHero: return .system(.headline, design: .monospaced)
        case .neoBrutalism: return .system(.headline, design: .default).weight(.black)
        case .cyberpunk, .blueprint, .industrialRust, .circuitBoard: return .system(.headline, design: .monospaced).italic()
        case .vintageNewspaper, .steampunk, .sketchbook: return .system(.headline, design: .serif)
        default: return size
        }
    }
}

#if os(iOS)
struct FlowAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var snoozeCount: Int
        var moveCount: Int
        var startDate: Date
        var emoji: String
        var style: TaskStyle
        var lastInteractionDate: Date = .now
        var growthLevel: Int = 0
    }
    var taskId: String
}

// MARK: - 🎭 Live Activity Stage

struct Flow_Intents_Widgets_ExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlowAttributes.self) { context in
            // 📱 Lock Screen / Banner UI
            ZStack {
                StyleBackground(style: context.state.style)

                // 🌊 Kinetic Motion Ripple
                StyleTransitionWave(style: context.state.style, triggerDate: context.state.lastInteractionDate)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 15) {
                        BreathingEmojiView(emoji: context.state.emoji, style: context.state.style, growthLevel: context.state.growthLevel)

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

        } dynamicIsland: { context in
            DynamicIsland {
                // 🌟 Expanded State
                DynamicIslandExpandedRegion(.leading) {
                    BreathingEmojiView(emoji: context.state.emoji, style: context.state.style, growthLevel: context.state.growthLevel)
                        .padding(.leading, 8)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        StyleMetadataView(style: context.state.style, snoozeCount: context.state.snoozeCount)
                    }
                    .padding(.trailing, 8)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(context.state.style.themeFont())
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ZStack {
                        // 🌊 Kinetic Motion Ripple
                        StyleTransitionWave(style: context.state.style, triggerDate: context.state.lastInteractionDate)

                        VStack(spacing: 12) {
                            StyleProgressView(style: context.state.style)

                            HStack(spacing: 15) {
                                Button(intent: SnoozeIntent(taskId: context.attributes.taskId)) {
                                    Label("Snooze", systemImage: "zzz")
                                        .font(.caption.bold())
                                }
                                .buttonStyle(ThemeButtonStyle(style: context.state.style, color: .orange))

                                Button(intent: DoneIntent(taskId: context.attributes.taskId)) {
                                    Label(doneButtonLabel(for: context.state.style), systemImage: "checkmark.circle.fill")
                                        .font(.caption.bold())
                                }
                                .buttonStyle(ThemeButtonStyle(style: context.state.style, color: .green, prominent: true))
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                BreathingEmojiView(emoji: context.state.emoji, style: context.state.style, compact: true, growthLevel: context.state.growthLevel)
            } compactTrailing: {
                HStack(spacing: 2) {
                    Text("\(context.state.snoozeCount)")
                        .monospacedDigit()
                    Text(compactTrailingIcon(for: context.state.style))
                }
                .font(.caption2.bold())
            } minimal: {
                BreathingEmojiView(emoji: context.state.emoji, style: context.state.style, compact: true, growthLevel: context.state.growthLevel)
            }
            .widgetURL(URL(string: "flow://task/\(context.attributes.taskId)"))
            .keylineTint(context.state.style.themeAccentColor())
        }
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
#endif

// MARK: - 🌊 Theme Views

struct StyleMetricView: View {
    let style: TaskStyle
    let snoozeCount: Int
    let moveCount: Int

    var body: some View {
        Group {
            if style == .questMode {
                VStack(alignment: .trailing) {
                    Text("LVL 5").font(.system(size: 12, weight: .black, design: .monospaced))
                    Text("XP 450").font(.caption2)
                }.foregroundStyle(.orange)
            } else if style == .cosmicNebula || style == .cosmicVoid || style == .deepSpace {
                VStack(alignment: .trailing) {
                    Image(systemName: "sparkles").symbolEffect(.pulse).foregroundStyle(.white)
                    Text("ASTRA").font(.system(size: 8, weight: .bold))
                }
            } else if style == .spaceMission {
                VStack(alignment: .trailing) {
                    Text("FUEL 88%").font(.system(size: 8, design: .monospaced))
                    Text("ALT 400K").font(.system(size: 8, design: .monospaced))
                }.foregroundStyle(.cyan)
            } else if style == .courierPrime {
                VStack(alignment: .trailing) {
                    Text("ROUTE 7").font(.system(size: 8, weight: .black))
                    Text("ETA 12m").font(.caption2.monospaced())
                }.foregroundStyle(.yellow)
            } else if style == .circuitBoard {
                VStack(alignment: .trailing) {
                    Text("CPU 12%").font(.system(size: 8, design: .monospaced))
                    Text("RAM OK").font(.system(size: 8, design: .monospaced))
                }.foregroundStyle(.green)
            } else {
                HStack(spacing: 8) {
                    Label("\(snoozeCount)", systemImage: "zzz")
                    Label("\(moveCount)", systemImage: "arrow.right.circle")
                }
                .font(.caption2.bold())
            }
        }
    }
}

struct StyleMetadataView: View {
    let style: TaskStyle
    let snoozeCount: Int

    var body: some View {
        Group {
            metadataText
                .font(.system(size: 8, weight: .bold, design: .monospaced))

            HStack(spacing: 4) {
                Text("\(snoozeCount)").bold()
                Text(styleIcon)
            }
            .font(.caption2)
        }
    }

    @ViewBuilder
    private var metadataText: some View {
        switch style {
        case .livingGarden: Text("🌱 GROWING").foregroundStyle(.green)
        case .cyberpunk: Text("SYS_ACTIVE").foregroundStyle(.yellow)
        case .blueprint: Text("DRAFT_V1").foregroundStyle(.cyan)
        case .cosmicNebula: Text("ORBITAL").foregroundStyle(.purple)
        case .oceanFlow: Text("DEPTH_400m").foregroundStyle(.blue)
        case .industrialRust: Text("MAINT_REQ").foregroundStyle(.orange)
        case .steampunk: Text("PRESSURE_OK").foregroundStyle(.brown)
        case .courierPrime: Text("OUT_FOR_DELIV").foregroundStyle(.yellow)
        case .circuitBoard: Text("LINK_STABLE").foregroundStyle(.green)
        case .liquidMetal: Text("TEMP_900C").foregroundStyle(.cyan)
        default: EmptyView()
        }
    }

    private var styleIcon: String {
        switch style {
        case .cosmicNebula, .cosmicVoid, .deepSpace: return "✨"
        case .bioLuminescence, .oceanFlow, .liquidMetal: return "🫧"
        case .volcanicFlow, .solarFlare: return "🔥"
        case .livingGarden, .magicalForest: return "🌿"
        case .spaceMission: return "🚀"
        case .courierPrime: return "📦"
        default: return "💤"
        }
    }
}

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
                    RadialGradient(colors: [style.themeAccentColor().opacity(0.4), .clear], center: .center, startRadius: 0, endRadius: 200)
                }
            case .sunsetSilk, .sunsetGlow, .solarFlare:
                LinearGradient(colors: [.orange.opacity(0.4), .pink.opacity(0.4), .purple.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .oceanFlow, .bioLuminescence, .liquidMetal:
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
            case .glassmorphism:
                Rectangle().fill(.ultraThinMaterial)
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

struct StyleProgressView: View {
    let style: TaskStyle

    var body: some View {
        switch style {
        case .retroPixel, .vintageArcade, .pixelArtHero:
            ProgressView(value: 0.6).tint(.green).scaleEffect(x: 1, y: 2, anchor: .center)
        case .neoBrutalism, .opaqueBold:
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(.black)
                    Rectangle().fill(style == .neoBrutalism ? .yellow : .blue).frame(width: geo.size.width * 0.6)
                }.border(.black, width: 2)
            }.frame(height: 10)
        case .holographic, .crystalPrism, .crystalCave, .glassmorphism:
            ProgressView(value: 0.7).tint(.cyan).shadow(color: .cyan, radius: 5)
        case .circuitBoard:
            ProgressView(value: 0.8).tint(.green)
        default:
            ProgressView(value: 0.4).tint(progressColor)
        }
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
    let style: TaskStyle
    let color: Color
    var prominent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                if style == .neoBrutalism || style == .opaqueBold {
                    Rectangle().fill(prominent ? color : .white).border(.black, width: 2).offset(x: configuration.isPressed ? 0 : 2, y: configuration.isPressed ? 0 : 2)
                } else if style == .softClay {
                    Capsule().fill(prominent ? color.opacity(0.8) : .white).shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 4)
                } else if style == .vintageNewspaper || style == .steampunk || style == .sketchbook {
                    Rectangle().fill(prominent ? .black : .clear).border(.black, width: 1)
                } else if style == .glassmorphism {
                    Capsule().fill(.ultraThinMaterial).overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                } else {
                    Capsule().fill(prominent ? color : color.opacity(0.2))
                }
            }
            .foregroundStyle(buttonForegroundColor)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }

    private var buttonForegroundColor: Color {
        if style == .neoBrutalism || style == .softClay || ((style == .vintageNewspaper || style == .steampunk || style == .sketchbook) && !prominent) {
            return .black
        }
        return .white
    }
}

struct BreathingEmojiView: View {
    let emoji: String
    var style: TaskStyle = .sleekModern
    var compact: Bool = false
    var growthLevel: Int = 0
    @State private var isBreathing = false
    @State private var symbolTrigger = false

    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(style.themeAccentColor().opacity(0.3), lineWidth: 2)
                    .scaleEffect(isBreathing ? 1.5 : 1.0)
                    .opacity(isBreathing ? 0 : 0.5)
                    .animation(.easeInOut(duration: breathingDuration).repeatForever(autoreverses: false).delay(Double(index) * 0.5), value: isBreathing)
            }

            if style == .livingGarden || style == .magicalForest {
                Text(gardenEmoji)
                    .font(compact ? .body : .largeTitle)
                    .scaleEffect(isBreathing ? 1.1 : 0.9)
                    .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: isBreathing)
            } else if isSFSymbol {
                Image(systemName: emojiName)
                    .font(style.themeFont(size: compact ? 20 : 40))
                    .symbolEffect(.bounce, value: symbolTrigger)
                    .symbolEffect(.variableColor.iterative, options: .repeat(.infinite), value: isBreathing)
                    .symbolEffect(.pulse, options: .repeat(.infinite), value: isBreathing)
                    .foregroundStyle(style.themeForegroundColor())
            } else {
                Text(emoji)
                    .font(compact ? .body : (style == .retroPixel || style == .vintageArcade || style == .pixelArtHero ? .system(size: 30, design: .monospaced) : .largeTitle))
                    .scaleEffect(isBreathing ? 1.15 : 0.85)
                    .shadow(color: style == .holographic || style == .glassmorphism ? .cyan.opacity(0.5) : .clear, radius: 10)
                    .animation(.easeInOut(duration: style == .zenFocus ? 3.0 : 2.0).repeatForever(autoreverses: true), value: isBreathing)
            }
        }
        .onAppear {
            isBreathing = true
            // Periodically trigger bounce for SF Symbols
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                symbolTrigger.toggle()
            }
        }
    }

    private var gardenEmoji: String {
        switch growthLevel {
        case 0: return "🌱"
        case 1: return "🌿"
        case 2: return "🌳"
        case 3: return "🍎"
        default: return "🌱"
        }
    }

    private var isSFSymbol: Bool {
        emoji.hasPrefix("sf:")
    }

    private var emojiName: String {
        isSFSymbol ? String(emoji.dropFirst(3)) : emoji
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

struct StyleTransitionWave: View {
    let style: TaskStyle
    var triggerDate: Date = .now
    @State private var trigger = false

    var body: some View {
        ZStack {
            if trigger {
                FluidWaveView(color: style.themeAccentColor())
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity))
                    .ignoresSafeArea()
            }
        }
        .onChange(of: triggerDate) { _, _ in
            activateWave()
        }
        .onChange(of: style) { _, _ in
            activateWave()
        }
    }

    private func activateWave() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            trigger = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                trigger = false
            }
        }
    }
}

struct FluidWaveView: View {
    let color: Color
    @State private var phase = 0.0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let angle = now * 2.0

                let path = Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height))

                    for xPosition in stride(from: 0, to: size.width, by: 1) {
                        let relativeX = xPosition / size.width
                        let sine = sin(angle + (relativeX * .pi * 2))
                        let yPosition = size.height * 0.5 + (sine * 10)
                        path.addLine(to: CGPoint(x: xPosition, y: yPosition))
                    }

                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.closeSubpath()
                }

                context.fill(path, with: .color(color.opacity(0.3)))
            }
        }
    }
}

// MARK: - 🧪 Previews

extension FlowAttributes {
    static var preview: FlowAttributes { FlowAttributes(taskId: UUID().uuidString) }
}
