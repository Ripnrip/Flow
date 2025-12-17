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

struct BreathingEmojiView: View {
    let emoji: String
    var style: TaskStyle = .sleekModern
    var compact: Bool = false
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

            if isSFSymbol {
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

// MARK: - ✨ Particle Alchemy (Lottie-inspired Native SwiftUI)

struct Particle: Identifiable {
    let id = UUID()
    var xPos: Double
    var yPos: Double
    var size: Double
    var opacity: Double
    var speed: Double
}

struct CosmicParticleSystem: View {
    let color: Color
    @State private var particles: [Particle] = []

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for particle in particles {
                    let rect = CGRect(x: particle.xPos * size.width, y: particle.yPos * size.height, width: particle.size, height: particle.size)
                    context.opacity = particle.opacity
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
            .onAppear {
                createParticles()
            }
            .onChange(of: timeline.date) { _, _ in
                updateParticles()
            }
        }
    }

    private func createParticles() {
        for _ in 0..<30 {
            particles.append(Particle(
                xPos: Double.random(in: 0...1),
                yPos: Double.random(in: 0...1),
                size: Double.random(in: 2...6),
                opacity: Double.random(in: 0.1...0.6),
                speed: Double.random(in: 0.001...0.005)
            ))
        }
    }

    private func updateParticles() {
        for index in 0..<particles.count {
            particles[index].yPos -= particles[index].speed
            if particles[index].yPos < 0 {
                particles[index].yPos = 1
                particles[index].xPos = Double.random(in: 0...1)
            }
        }
    }
}

// MARK: - 🌊 Kinetic Motion Alchemy

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



