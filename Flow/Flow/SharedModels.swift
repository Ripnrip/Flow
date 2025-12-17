/**
 * 🎭 The Shared Models - The Universal Language
 *
 * "The common tongue spoken by both the main realm and the peripheral islands.
 * It ensures that intent is understood across all boundaries."
 *
 * - The Cosmic Language Maestro
 */

import Foundation
#if os(iOS)
import ActivityKit
#endif
import SwiftUI

// MARK: - 🎨 Visual Concept Alchemy

enum TaskStyle: String, Codable, CaseIterable, Sendable {
    // 🌟 Original Classics
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

    // 🚀 Cosmic & Atmospheric
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

    // 🌊 Themed Expeditions
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

    // 💎 Figma-Inspired & New Horizons
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

// MARK: - 🧙‍♂️ Theme Engine

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
        case .retroPixel, .vintageArcade, .pixelArtHero: 
            return .system(size == .headline ? .title3 : size, design: .monospaced).weight(.bold)
        case .neoBrutalism: 
            return .system(size == .headline ? .title2 : size, design: .default).weight(.black)
        case .cyberpunk, .blueprint, .industrialRust, .circuitBoard: 
            return .system(size == .headline ? .headline : size, design: .monospaced).italic().weight(.semibold)
        case .vintageNewspaper, .steampunk, .sketchbook: 
            return .system(size == .headline ? .title3 : size, design: .serif).weight(.medium)
        case .sleekModern, .glassmorphism, .ethereal:
            return .system(size == .headline ? .headline : size, design: .default).weight(.light)
        default: 
            return size.weight(.medium)
        }
    }
}

protocol TaskProtocol: Sendable {
    var id: UUID { get }
    var title: String { get }
    var emoji: String { get }
    var style: TaskStyle { get }
    var snoozeCount: Int { get }
    var moveCount: Int { get }
    var totalLingeringTime: TimeInterval { get }
    var creationDate: Date { get }
    var growthLevel: Int { get }
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
#endif
