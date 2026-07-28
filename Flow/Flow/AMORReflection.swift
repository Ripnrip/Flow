/**
 * 🧘 AMORReflectionView — Guided Reflection & Contemplation
 *
 * "The sacred pause between action and awareness. Where the day's
 * experiences are woven into meaning, and the seeker finds clarity
 * through structured introspection."
 *
 * v2.8.0 — Guided Reflection Engine
 *
 * Features:
 * - Daily reflection prompts that rotate through themes
 * - Guided multi-step reflection flow
 * - Past reflections archive
 * - Integration with Second Brain vault filing
 */

import SwiftUI
import SwiftData

// MARK: - Reflection Model

/// A saved reflection entry.
@Model
nonisolated final class ReflectionEntry {
    var id: UUID = UUID()
    var date: Date
    var prompt: String
    var response: String
    var theme: String      // "gratitude", "growth", "challenge", "vision", "presence"
    var moodBefore: String
    var moodAfter: String
    var timestamp: Date

    init(
        date: Date = .now,
        prompt: String,
        response: String = "",
        theme: String = "presence",
        moodBefore: String = "neutral",
        moodAfter: String = "neutral",
        timestamp: Date = .now
    ) {
        self.date = date
        self.prompt = prompt
        self.response = response
        self.theme = theme
        self.moodBefore = moodBefore
        self.moodAfter = moodAfter
        self.timestamp = timestamp
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Reflection Prompt System

/// Curated reflection prompts organized by theme.
enum ReflectionPrompts {
    struct Prompt: Identifiable {
        let id = UUID()
        let theme: String
        let icon: String
        let question: String
        let followUp: String?
    }

    static let prompts: [Prompt] = [
        // Gratitude
        Prompt(theme: "gratitude", icon: "heart.fill",
               question: "What are three things that went well today?",
               followUp: "What made each of these moments meaningful?"),
        Prompt(theme: "gratitude", icon: "sun.max.fill",
               question: "Who or what are you most grateful for right now?",
               followUp: "How can you express this gratitude tomorrow?"),

        // Growth
        Prompt(theme: "growth", icon: "leaf.fill",
               question: "What did you learn today that surprised you?",
               followUp: "How will this change what you do tomorrow?"),
        Prompt(theme: "growth", icon: "arrow.up.right.square",
               question: "What's one skill or habit you're actively cultivating?",
               followUp: "What evidence of progress did you see today?"),

        // Challenge
        Prompt(theme: "challenge", icon: "flame.fill",
               question: "What was the hardest part of today, and how did you meet it?",
               followUp: "What would you do differently if you faced it again?"),
        Prompt(theme: "challenge", icon: "bolt.fill",
               question: "What resistance did you feel today, and what was it protecting?",
               followUp: "Is this resistance serving you or limiting you?"),

        // Vision
        Prompt(theme: "vision", icon: "mountain.2.fill",
               question: "If you continue on this trajectory, where will you be in 90 days?",
               followUp: "Is that where you want to be? What needs to change?"),
        Prompt(theme: "vision", icon: "star.fill",
               question: "What would you attempt today if you knew you could not fail?",
               followUp: "What's the smallest step toward that you can take tomorrow?"),

        // Presence
        Prompt(theme: "presence", icon: "circle.grid.3x3.fill",
               question: "When did you feel most present and alive today?",
               followUp: "What conditions created that state of presence?"),
        Prompt(theme: "presence", icon: "wind",
               question: "What is your body telling you right now?",
               followUp: "What does it need from you?"),

        // System / Rhythm
        Prompt(theme: "rhythm", icon: "clock.fill",
               question: "How did your daily rhythm serve you today?",
               followUp: "What one adjustment would make tomorrow's rhythm better?"),
        Prompt(theme: "rhythm", icon: "gearshape.2.fill",
               question: "Which of your systems (tools, habits, automations) added the most leverage today?",
               followUp: "Which system felt like friction rather than flow?")
    ]

    /// Get today's prompt based on day-of-year rotation.
    static func promptForToday() -> Prompt {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = (dayOfYear - 1) % prompts.count
        return prompts[index]
    }

    /// Get prompts by theme.
    static func prompts(forTheme theme: String) -> [Prompt] {
        prompts.filter { $0.theme == theme }
    }

    /// All unique themes.
    static let themes: [(name: String, icon: String)] = [
        ("gratitude", "heart.fill"),
        ("growth", "leaf.fill"),
        ("challenge", "flame.fill"),
        ("vision", "star.fill"),
        ("presence", "circle.grid.3x3.fill"),
        ("rhythm", "clock.fill")
    ]
}

// MARK: - Reflection View

struct AMORReflectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReflectionEntry.date, order: .reverse) private var reflections: [ReflectionEntry]

    @State private var showingNewReflection = false
    @State private var selectedTheme: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Today's prompt call-to-action
                    todayPromptCard

                    // Theme filter chips
                    themeFilterChips

                    // Recent reflections
                    if filteredReflections.isEmpty {
                        emptyStateView
                    } else {
                        reflectionsList
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Reflection")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingNewReflection) {
                GuidedReflectionFlow()
            }
        }
    }

    // MARK: - Today's Prompt Card

    private var todayPromptCard: some View {
        let prompt = ReflectionPrompts.promptForToday()

        return AMORComponents.ContemplativeCard(isActive: true) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: prompt.icon)
                        .font(.title2)
                        .foregroundStyle(AMORColorPalette.twilightPurple)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's Reflection")
                            .font(AMORTypography.subtitleFont)
                            .foregroundStyle(.secondary)
                        Text(prompt.theme.capitalized)
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(AMORColorPalette.twilightPurple)
                    }

                    Spacer()
                }

                Text(prompt.question)
                    .font(AMORTypography.titleFont)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    showingNewReflection = true
                } label: {
                    HStack {
                        Image(systemName: "pencil.and.scribble")
                        Text("Begin Reflection")
                    }
                    .font(AMORTypography.bodyFont.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [AMORColorPalette.twilightPurple, AMORColorPalette.deepIndigo],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Theme Filter

    private var themeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // "All" chip
                themeChip(name: "All", icon: "circle.grid.cross.fill", isSelected: selectedTheme == nil) {
                    selectedTheme = nil
                }

                ForEach(ReflectionPrompts.themes, id: \.name) { theme in
                    themeChip(
                        name: theme.name.capitalized,
                        icon: theme.icon,
                        isSelected: selectedTheme == theme.name
                    ) {
                        withAnimation(AMORAnimations.slowFade) {
                            selectedTheme = theme.name
                        }
                    }
                }
            }
        }
    }

    private func themeChip(name: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(name)
                    .font(AMORTypography.captionFont)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ?
                AMORColorPalette.twilightPurple.opacity(0.2) :
                Color.gray.opacity(0.1)
            )
            .foregroundStyle(isSelected ? AMORColorPalette.twilightPurple : .secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? AMORColorPalette.twilightPurple : Color.clear, lineWidth: 1)
            )
        }
    }

    // MARK: - Reflections List

    private var filteredReflections: [ReflectionEntry] {
        if let theme = selectedTheme {
            return reflections.filter { $0.theme == theme }
        }
        return reflections
    }

    private var reflectionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if selectedTheme == nil {
                Text("Recent Reflections")
                    .font(AMORTypography.titleFont)
                    .foregroundStyle(AMORColorPalette.deepIndigo)
            }

            ForEach(filteredReflections.prefix(20), id: \.id) { reflection in
                ReflectionCard(reflection: reflection)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 48))
                .foregroundStyle(AMORColorPalette.twilightPurple)

            Text("No reflections yet")
                .font(AMORTypography.titleFont)
                .foregroundStyle(.secondary)

            Text("Begin your first guided reflection to start building your contemplation archive.")
                .font(AMORTypography.bodyFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Reflection Card

struct ReflectionCard: View {
    let reflection: ReflectionEntry

    var body: some View {
        AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    Image(systemName: themeIcon)
                        .foregroundStyle(AMORColorPalette.twilightPurple)

                    Text(reflection.theme.capitalized)
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(AMORColorPalette.twilightPurple)

                    Spacer()

                    Text(reflection.formattedDate)
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }

                // Prompt
                Text(reflection.prompt)
                    .font(AMORTypography.bodyFont.bold())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                // Response
                if !reflection.response.isEmpty {
                    Text(reflection.response)
                        .font(AMORTypography.bodyFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Mood shift
                if reflection.moodBefore != reflection.moodAfter {
                    HStack(spacing: 6) {
                        Text("Mood: \(reflection.moodBefore) → \(reflection.moodAfter)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var themeIcon: String {
        ReflectionPrompts.themes.first(where: { $0.name == reflection.theme })?.icon ?? "circle.fill"
    }
}

// MARK: - Guided Reflection Flow

struct GuidedReflectionFlow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var currentStep = 0
    @State private var moodBefore = "neutral"
    @State private var mainResponse = ""
    @State private var followUpResponse = ""
    @State private var moodAfter = "neutral"

    private let prompt = ReflectionPrompts.promptForToday()
    private let moods = ["neutral", "calm", "focused", "tired", "energized", "stressed", "grateful"]

    var body: some View {
        NavigationStack {
            ZStack {
                AMORColorPalette.morningDawn
                    .ignoresSafeArea()

                VStack {
                    // Progress indicator
                    progressDots

                    // Step content
                    ScrollView {
                        VStack(spacing: 24) {
                            switch currentStep {
                            case 0: moodCheckInStep
                            case 1: mainPromptStep
                            case 2: followUpStep
                            default: moodAfterStep
                            }
                        }
                        .padding()
                    }

                    // Navigation buttons
                    navigationButtons
                }
            }
            .navigationTitle("Reflection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<4) { step in
                Circle()
                    .fill(step <= currentStep ? AMORColorPalette.mutedGold : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(AMORAnimations.slowFade, value: currentStep)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Step 0: Mood Check-In

    private var moodCheckInStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white)

            Text("How are you feeling right now?")
                .font(AMORTypography.titleFont)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(moods, id: \.self) { mood in
                    Button {
                        withAnimation(AMORAnimations.thoughtfulAppear) {
                            moodBefore = mood
                        }
                    } label: {
                        Text(mood.capitalized)
                            .font(AMORTypography.captionFont)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                moodBefore == mood ?
                                Color.white.opacity(0.9) :
                                Color.white.opacity(0.15)
                            )
                            .foregroundStyle(moodBefore == mood ? AMORColorPalette.deepIndigo : .white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    // MARK: - Step 1: Main Prompt

    private var mainPromptStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: prompt.icon)
                .font(.system(size: 36))
                .foregroundStyle(.white)

            Text(prompt.question)
                .font(AMORTypography.titleFont)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $mainResponse)
                .font(AMORTypography.bodyFont)
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(Color.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(minHeight: 150)
        }
    }

    // MARK: - Step 2: Follow-Up

    private var followUpStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let followUp = prompt.followUp {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)

                Text("Reflect deeper...")
                    .font(AMORTypography.subtitleFont)
                    .foregroundStyle(.white.opacity(0.8))

                Text(followUp)
                    .font(AMORTypography.titleFont)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                TextEditor(text: $followUpResponse)
                    .font(AMORTypography.bodyFont)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Color.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(minHeight: 120)
            } else {
                Text("Take a breath. You've reflected well.")
                    .font(AMORTypography.titleFont)
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Step 3: Mood After + Save

    private var moodAfterStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "sunrise.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white)

            Text("How do you feel now?")
                .font(AMORTypography.titleFont)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("You came in feeling \(moodBefore)")
                .font(AMORTypography.bodyFont)
                .foregroundStyle(.white.opacity(0.7))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(moods, id: \.self) { mood in
                    Button {
                        withAnimation(AMORAnimations.thoughtfulAppear) {
                            moodAfter = mood
                        }
                    } label: {
                        Text(mood.capitalized)
                            .font(AMORTypography.captionFont)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                moodAfter == mood ?
                                Color.white.opacity(0.9) :
                                Color.white.opacity(0.15)
                            )
                            .foregroundStyle(moodAfter == mood ? AMORColorPalette.deepIndigo : .white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation(AMORAnimations.thoughtfulAppear) {
                        currentStep -= 1
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                if currentStep < 3 {
                    withAnimation(AMORAnimations.thoughtfulAppear) {
                        currentStep += 1
                    }
                } else {
                    saveReflection()
                    dismiss()
                }
            } label: {
                Text(currentStep < 3 ? "Continue" : "Complete")
                    .font(AMORTypography.bodyFont.bold())
                    .foregroundStyle(AMORColorPalette.deepIndigo)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(currentStep == 1 && mainResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }

    // MARK: - Save

    private func saveReflection() {
        let combinedResponse = followUpResponse.isEmpty ?
            mainResponse :
            "\(mainResponse)\n\n\(prompt.followUp ?? "")\n\(followUpResponse)"

        let entry = ReflectionEntry(
            date: .now,
            prompt: prompt.question,
            response: combinedResponse,
            theme: prompt.theme,
            moodBefore: moodBefore,
            moodAfter: moodAfter
        )
        modelContext.insert(entry)
    }
}
