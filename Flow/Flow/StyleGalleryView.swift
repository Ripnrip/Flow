/**
 * 🎭 The Style Gallery - The Grand Exhibition
 * 
 * "A curated collection of every visual resonance we have crystallized.
 * Here, the seeker of wisdom organizes their worldly duties, we pull the threads of intent
 * and weave them into the Flow."
 * 
 * - The Cosmic Gallery Curator
 */

import SwiftUI

struct StyleGalleryView: View {
    // 🌟 The full spectrum of our artistic endeavors
    private let allStyles = TaskStyle.allCases
    
    // 🎨 Layout configuration for the grand exhibition
    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 20)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 25) {
                ForEach(allStyles, id: \.self) { style in
                    StyleCard(style: style)
                }
            }
            .padding(25)
        }
        .navigationTitle("The Visual Vault")
#if os(iOS)
        .background(Color(uiColor: .systemGroupedBackground))
#elseif (os(macOS))
        .background(Color.teal)
        
#endif
    }
}

// MARK: - 🖼️ Exhibition Components

struct StyleCard: View {
    let style: TaskStyle
    var growthLevel: Int = 0
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // 🎭 The Visual Soul of the Style
            ZStack {
                StyleBackground(style: style)
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .strokeBorder(style.themeForegroundColor().opacity(0.1), lineWidth: 1)
                    )
                
                BreathingEmojiView(emoji: styleEmoji(for: style), style: style, compact: false, growthLevel: growthLevel)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: style.icon)
                        .foregroundStyle(style.themeAccentColor())
                    Text(style.rawValue)
                        .font(.headline)
                        .foregroundStyle(style.themeForegroundColor())
                }
                
                Text(styleDescription(for: style))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 5)
            
            // 🧪 State Permutation Preview
            HStack(spacing: 8) {
                CompactStateBadge(style: style, label: "Compact")
                CompactStateBadge(style: style, label: "Minimal")
            }
        }
        .padding(12)
        .background(style.themeBackgroundColor())
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        #if os(macOS)
        .onHover { hovering in isHovering = hovering }
        #endif
    }
    
    private func styleEmoji(for style: TaskStyle) -> String {
        switch style {
        case .sleekModern: return "✨"
        case .zenFocus: return "🧘‍♂️"
        case .questMode: return "🛡️"
        case .livingGarden: return "🌿"
        case .holographic: return "🔮"
        case .stickyBoard: return "📌"
        case .timeline: return "⌛"
        case .ethereal: return "☁️"
        case .neoBrutalism: return "🏁"
        case .cyberpunk: return "⚡"
        case .softClay: return "🏺"
        case .retroPixel: return "👾"
        case .frostedGlass: return "❄️"
        case .organicNature: return "🍃"
        case .industrialTech: return "🛠️"
        case .popArt: return "🎨"
        case .zenInk: return "🖌️"
        case .cosmicNebula: return "🌌"
        case .blueprint: return "📐"
        case .sunsetSilk: return "🌆"
        case .bioLuminescence: return "🐟"
        case .vintageNewspaper: return "📰"
        case .abstractGeometric: return "🔺"
        case .magicalScroll: return "📜"
        case .crystalPrism: return "💎"
        case .volcanicFlow: return "🌋"
        case .cloudPeak: return "🏔️"
        case .oceanFlow: return "🌊"
        case .spaceMission: return "🚀"
        case .vintageArcade: return "🕹️"
        case .steampunk: return "⚙️"
        case .magicalForest: return "🧚"
        case .midnightMonochrome: return "🌑"
        case .sunsetGlow: return "🌅"
        case .cosmicVoid: return "🕳️"
        case .industrialRust: return "⛓️"
        case .crystalCave: return "💎"
        case .glassmorphism: return "🪟"
        case .opaqueBold: return "📦"
        case .courierPrime: return "🚚"
        case .pixelArtHero: return "⚔️"
        case .circuitBoard: return "💾"
        case .liquidMetal: return "💧"
        case .velvetNight: return "💜"
        case .sketchbook: return "✏️"
        case .solarFlare: return "🌞"
        case .deepSpace: return "🛸"
        }
    }
    
    private func styleDescription(for style: TaskStyle) -> String {
        // Reuse the description logic from StylePreviewSnippet if possible
        // For now, providing a mapping here
        switch style {
        case .sleekModern: return "Elegant gradient design"
        case .zenFocus: return "Minimalist breathing interface"
        case .questMode: return "Gamified RPG experience"
        case .livingGarden: return "Nature-inspired growth"
        case .holographic: return "Futuristic sci-fi interface"
        case .stickyBoard: return "Physical sticky notes"
        case .timeline: return "Time-based visualization"
        case .ethereal: return "Calm, flow-state, weightless"
        case .cyberpunk: return "High-contrast neon"
        case .neoBrutalism: return "Bold, high-contrast grid"
        case .softClay: return "Soft, tactile depth"
        case .retroPixel: return "Chunky 8-bit nostalgia"
        case .frostedGlass: return "Blurred translucency"
        case .organicNature: return "Earthly tones and organic shapes"
        case .industrialTech: return "Raw metal and functional lines"
        case .popArt: return "Vibrant dots and bold colors"
        case .zenInk: return "Traditional brush strokes"
        case .cosmicNebula: return "Galactic dust and pulsing stars"
        case .blueprint: return "Architectural draft lines"
        case .sunsetSilk: return "Flowing twilight gradients"
        case .bioLuminescence: return "Glow of the deep ocean"
        case .vintageNewspaper: return "Ink-stained chronicle"
        case .abstractGeometric: return "Sharp angles and primary hues"
        case .magicalScroll: return "Enchanted parchment and spells"
        case .crystalPrism: return "Refracted light and shards"
        case .volcanicFlow: return "Molten lava and charcoal"
        case .cloudPeak: return "Airy heights and lightning"
        case .oceanFlow: return "Submerged deep-sea focus"
        case .spaceMission: return "Celestial starship command"
        case .vintageArcade: return "Neon-drenched high score"
        case .steampunk: return "Brass gears and steam"
        case .magicalForest: return "Glow of enchanted fireflies"
        case .midnightMonochrome: return "Ultra-minimal dark contrast"
        case .sunsetGlow: return "Warm twilight tranquility"
        case .cosmicVoid: return "Vast, empty starfields"
        case .industrialRust: return "Weathered metallic grit"
        case .crystalCave: return "Prismatic subterranean shards"
        case .glassmorphism: return "Frosted glass and soft blurs"
        case .opaqueBold: return "Solid, high-impact contrast"
        case .courierPrime: return "Delivery-grade tracking layout"
        case .pixelArtHero: return "16-bit hero's journey"
        case .circuitBoard: return "Electronic traces and data flow"
        case .liquidMetal: return "Flowing, reflective surfaces"
        case .velvetNight: return "Deep purple plush textures"
        case .sketchbook: return "Rough pencil and paper grain"
        case .solarFlare: return "Intense heat and solar radiation"
        case .deepSpace: return "The ultimate dark void focus"
        }
    }
}


// MARK: - 🧪 Gallery Previews

#Preview("The Grand Exhibition") {
    NavigationStack {
        StyleGalleryView()
    }
}
