/**
 * 🧘 AMORTheme — Thoughtful, Reflective UI Design
 *
 * "A visual language of calm introspection, where every gradient breathes
 * and every animation invites stillness. This is not productivity porn —
 * this is a digital sanctuary."
 *
 * - The Aesthetic Monastery of Reflection
 */

import SwiftUI

// MARK: - AMORColorPalette

/// AMOR's signature color palette — warm, contemplative, gentle.
enum AMORColorPalette {
    // Primary palette
    static let deepIndigo = Color(red: 0.18, green: 0.22, blue: 0.35)
    static let warmSand = Color(red: 0.92, green: 0.88, blue: 0.82)
    static let softClay = Color(red: 0.85, green: 0.78, blue: 0.72)
    static let twilightPurple = Color(red: 0.45, green: 0.32, blue: 0.52)
    static let dawnOrange = Color(red: 0.95, green: 0.65, blue: 0.42)
    static let sageGreen = Color(red: 0.55, green: 0.68, blue: 0.52)
    static let mutedGold = Color(red: 0.82, green: 0.68, blue: 0.42)
    static let charcoal = Color(red: 0.25, green: 0.25, blue: 0.28)
    
    // Semantic colors
    static let meditation = deepIndigo
    static let accomplishment = mutedGold
    static let growth = sageGreen
    static let energy = dawnOrange
    static let reflection = charcoal
    static let tranquility = warmSand
    
    // Gradients
    static let morningDawn = LinearGradient(
        colors: [deepIndigo, twilightPurple, dawnOrange],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let calmWaters = LinearGradient(
        colors: [Color(red: 0.4, green: 0.6, blue: 0.7),
                 Color(red: 0.6, green: 0.75, blue: 0.8),
                 Color(red: 0.8, green: 0.85, blue: 0.9)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let warmEmbrace = LinearGradient(
        colors: [warmSand, softClay, mutedGold],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - AMORTypography

/// AMOR's typography scale — elegant, readable, contemplative.
enum AMORTypography {
    static let headingFont = Font.system(.largeTitle, design: .serif, weight: .light)
    static let titleFont = Font.system(.title, design: .serif, weight: .regular)
    static let subtitleFont = Font.system(.title3, design: .default, weight: .light)
    static let bodyFont = Font.system(.body, design: .serif, weight: .regular)
    static let captionFont = Font.system(.caption, design: .default, weight: .light)
    static let monospaceFont = Font.system(.caption, design: .monospaced, weight: .regular)
}

// MARK: - AMORAnimations

/// Gentle, breathing animations that invite reflection.
enum AMORAnimations {
    static let gentlePulse = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    static let slowFade = Animation.easeInOut(duration: 1.0)
    static let thoughtfulAppear = Animation.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)
    static let rhythmicBreath = Animation.linear(duration: 4.0).repeatForever(autoreverses: true)
}

// MARK: - AMORComponents

/// Reusable AMOR UI components.
enum AMORComponents {
    
    // MARK: Gradient Background
    struct GradientBackground<Content: View>: View {
        let content: Content
        let gradient: LinearGradient
        
        init(gradient: LinearGradient = AMORColorPalette.morningDawn,
             @ViewBuilder content: () -> Content) {
            self.gradient = gradient
            self.content = content()
        }
        
        var body: some View {
            ZStack {
                gradient.ignoresSafeArea()
                content
            }
        }
    }
    
    // MARK: Contemplative Card
    struct ContemplativeCard<Content: View>: View {
        let content: Content
        let isActive: Bool
        
        init(isActive: Bool = false,
             @ViewBuilder content: () -> Content) {
            self.isActive = isActive
            self.content = content()
        }
        
        var body: some View {
            content
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .shadow(color: AMORColorPalette.charcoal.opacity(0.15), radius: 8, x: 0, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isActive ? AMORColorPalette.mutedGold : Color.clear, lineWidth: 2)
                )
        }
    }
    
    // MARK: Streak Flame
    struct StreakFlame: View {
        let count: Int
        let isBroken: Bool
        
        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(colors: isBroken ? [.gray, .gray] : [.orange, .red, .yellow], startPoint: .top, endPoint: .bottom)
                    )
                    .symbolEffect(.variableColor.iterative.reversing, value: count)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count)")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    
                    Text(count == 1 ? "day" : "days")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isBroken ? Color.gray.opacity(0.1) : AMORColorPalette.dawnOrange.opacity(0.15))
            )
        }
    }
    
    // MARK: Progress Ring
    struct ProgressRing: View {
        let progress: CGFloat
        let size: CGFloat
        let lineWidth: CGFloat
        
        init(progress: CGFloat, size: CGFloat = 80, lineWidth: CGFloat = 8) {
            self.progress = min(max(progress, 0), 1)
            self.size = size
            self.lineWidth = lineWidth
        }
        
        var body: some View {
            ZStack {
                Circle()
                    .stroke(AMORColorPalette.charcoal.opacity(0.15), lineWidth: lineWidth)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(colors: [.orange, .pink, .purple], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: progress)
            }
            .frame(width: size, height: size)
        }
    }
    
    // MARK: Reflective Quote
    struct ReflectiveQuote: View {
        let text: String
        let author: String?
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "quote.opening")
                    .font(.title2)
                    .foregroundStyle(AMORColorPalette.mutedGold)
                
                Text(text)
                    .font(AMORTypography.bodyFont)
                    .italic()
                    .foregroundStyle(.primary)
                
                if let author = author {
                    Text("— \(author)")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - AMORIconSet

/// Curated SF Symbols for AMOR's semantic needs.
enum AMORIconSet {
    static let meditation = "figure.mind.and.body"
    static let accomplishment = "sparkles"
    static let growth = "seedling"
    static let energy = "bolt.fill"
    static let reflection = "brain.head_profile"
    static let tranquility = "leaf.fill"
    static let journal = "journal.text"
    static let streak = "flame.fill"
    static let calendar = "calendar"
    static let clock = "clock"
    static let checkmark = "checkmark.circle.fill"
    static let chart = "chart.bar.fill"
    static let settings = "gearshape"
}