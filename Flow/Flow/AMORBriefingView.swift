/**
 * 🌅 AMORBriefingView — The Daily Briefing Surface
 *
 * "Not a dashboard you scroll through. A voice that meets you
 * where you are in the day — morning purpose, midday pulse,
 * evening reflection. The keystone of the daily rhythm."
 *
 * v3.0.0 — Replaces the static header with a living briefing.
 */

import SwiftUI
import SwiftData

// MARK: - Main Briefing View

struct AMORBriefingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [DailySession]
    /// v5.2.0: engine inputs as Foundation snapshots (engines never touch @Models).
    private var sessionsSnap: [AMORSessionSnapshot] { sessions.map { $0.snapshot } }
    @Query private var practices: [PracticeStreak]
    /// v5.2.0: engine inputs as Foundation snapshots (engines never touch @Models).
    private var practicesSnap: [AMORPracticeSnapshot] { practices.map { $0.snapshot } }
    @Query private var cronJobs: [CronJobHealth]
    /// v5.2.0: engine inputs as Foundation snapshots (engines never touch @Models).
    private var cronJobsSnap: [AMORCronJobSnapshot] { cronJobs.map { $0.snapshot } }

    @State private var briefing: DailyBriefing?
    @State private var reflections: [ReflectionEntry] = []
    /// v5.2.0: engine inputs as Foundation snapshots (engines never touch @Models).
    private var reflectionsSnap: [AMORReflectionSnapshot] { reflections.map { $0.snapshot } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let briefing = briefing {
                    briefingContent(for: briefing)
                } else {
                    loadingView
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .background(AMORComponents.GradientBackground(
            gradient: phaseGradient,
            content: { Color.clear }
        ).opacity(0.3))
        .task {
            generateBriefing()
        }
        .refreshable {
            generateBriefing()
        }
    }

    // MARK: - Phase Gradient

    private var phaseGradient: LinearGradient {
        let phase = BriefingPhase.current()
        switch phase {
        case .morning:
            return LinearGradient(
                colors: [Color(hex: "FF8C42").opacity(0.15), Color(hex: "FFD93D").opacity(0.08)],
                startPoint: .top, endPoint: .bottom
            )
        case .midday:
            return LinearGradient(
                colors: [Color(hex: "6B9F4A").opacity(0.12), Color(hex: "A8D08D").opacity(0.06)],
                startPoint: .top, endPoint: .bottom
            )
        case .evening:
            return LinearGradient(
                colors: [Color(hex: "6B4C9A").opacity(0.15), Color(hex: "9B7EBD").opacity(0.08)],
                startPoint: .top, endPoint: .bottom
            )
        case .night:
            return LinearGradient(
                colors: [Color(hex: "2B2D6B").opacity(0.2), Color(hex: "4A4E8C").opacity(0.1)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    // MARK: - Briefing Content

    @ViewBuilder
    private func briefingContent(for briefing: DailyBriefing) -> some View {
        // Hero greeting
        BriefingHeroCard(briefing: briefing)

        // Priority alerts
        if !briefing.priorityAlerts.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(briefing.priorityAlerts) { alert in
                    BriefingAlertCard(alert: alert)
                }
            }
        }

        // Rhythm score (if available)
        if let score = briefing.rhythmScore, let grade = briefing.rhythmGrade {
            BriefingRhythmBar(score: score, grade: grade)
        }

        // Content sections
        ForEach(briefing.sections) { section in
            BriefingSectionCard(section: section)
        }

        // Suggested actions
        if !briefing.suggestedActions.isEmpty {
            BriefingActionsCard(actions: briefing.suggestedActions)
        }

        // Reflective prompt
        BriefingPromptCard(prompt: briefing.reflectivePrompt, phase: briefing.phase)

        // Timestamp
        HStack {
            Spacer()
            Text("Updated \(briefing.date.formatted(date: .omitted, time: .shortened))")
                .font(AMORTypography.captionFont)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 8)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(AMORColorPalette.deepIndigo)
            Text("Synthesizing your day…")
                .font(AMORTypography.bodyFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Briefing Generation

    private func generateBriefing() {
        let phase = BriefingPhase.current()

        // Try to get rhythm score from the engine
        var rhythmScore: Int? = nil
        var rhythmGrade: String? = nil
        let scoreResult = AMORRhythmEngine.computeScore(
            sessions: sessionsSnap, practices: practicesSnap, cronJobs: cronJobsSnap, reflections: reflectionsSnap
        )
        rhythmScore = scoreResult.score
        rhythmGrade = scoreResult.grade.emoji

        briefing = AMORBriefingEngine.generateBriefing(
            sessions: sessionsSnap,
            practices: practicesSnap,
            cronJobs: cronJobsSnap,
            reflections: reflectionsSnap,
            rhythmScore: rhythmScore,
            rhythmGrade: rhythmGrade,
            date: .now
        )
    }
}

// MARK: - Hero Card

struct BriefingHeroCard: View {
    let briefing: DailyBriefing

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Greeting + phase icon
            HStack(alignment: .top) {
                Image(systemName: briefing.phase.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(phaseColor)
                    .symbolEffect(.pulse, options: .nonRepeating)

                VStack(alignment: .leading, spacing: 4) {
                    Text(briefing.greeting)
                        .font(AMORTypography.headingFont)
                        .foregroundStyle(.primary)

                    Text(briefing.date.formatted(date: .complete, time: .omitted))
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(briefing.phase.rawValue.capitalized)
                    .font(AMORTypography.captionFont.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(phaseColor.opacity(0.15))
                    .foregroundStyle(phaseColor)
                    .clipShape(Capsule())
            }

            // Headline
            Text(briefing.headline)
                .font(AMORTypography.bodyFont.weight(.semibold))
                .foregroundStyle(.primary)

            // Subheadline
            Text(briefing.subheadline)
                .font(AMORTypography.bodyFont)
                .foregroundStyle(.secondary)

            // Quick stats row
            HStack(spacing: 0) {
                if let score = briefing.rhythmScore {
                    BriefingQuickStat(
                        icon: "gauge.with.dots.underneath",
                        value: "\(score)",
                        label: "Rhythm"
                    )
                    Divider().frame(height: 32).padding(.horizontal, 8)
                }

                let phaseNow = BriefingPhase.current()
                if phaseNow == .morning || phaseNow == .midday {
                    let totalPractices = briefing.sections.flatMap { $0.items }.filter { $0.hasPrefix("○") }.count
                    BriefingQuickStat(
                        icon: "leaf.fill",
                        value: "\(totalPractices)",
                        label: "To Do"
                    )
                }
            }
            .font(AMORTypography.captionFont)
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    private var phaseColor: Color {
        switch briefing.phase {
        case .morning:   return Color(hex: "FF8C42")
        case .midday:    return Color(hex: "6B9F4A")
        case .evening:   return Color(hex: "6B4C9A")
        case .night:     return Color(hex: "2B2D6B")
        }
    }
}

// MARK: - Quick Stat

struct BriefingQuickStat: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.title3)
            Text(value)
                .font(AMORTypography.captionFont.weight(.bold))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Alert Card

struct BriefingAlertCard: View {
    let alert: BriefingAlert

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: alert.icon)
                .font(.title3)
                .foregroundStyle(severityColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(alert.title)
                    .font(AMORTypography.bodyFont.weight(.semibold))
                    .foregroundStyle(severityColor)

                Text(alert.detail)
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Spacer()
        }
        .padding(14)
        .background(severityColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(severityColor.opacity(0.2), lineWidth: 1)
        )
    }

    private var severityColor: Color {
        switch alert.severity {
        case .info:         return .blue
        case .warning:      return .orange
        case .critical:     return .red
        case .celebration:  return .green
        }
    }
}

// MARK: - Rhythm Bar

struct BriefingRhythmBar: View {
    let score: Int
    let grade: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(grade) Rhythm Score")
                    .font(AMORTypography.captionFont.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(score)/100")
                    .font(AMORTypography.captionFont.weight(.bold))
                    .foregroundStyle(scoreColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.15))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(scoreColor)
                        .frame(width: geo.size.width * CGFloat(score) / 100.0)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var scoreColor: Color {
        if score >= 80 { return .green }
        if score >= 60 { return Color(hex: "6B9F4A") }
        if score >= 40 { return .orange }
        return .red
    }
}

// MARK: - Section Card

struct BriefingSectionCard: View {
    let section: BriefingSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: section.icon)
                    .font(.body)
                    .foregroundStyle(toneColor)

                Text(section.title)
                    .font(AMORTypography.bodyFont.weight(.semibold))
                    .foregroundStyle(toneColor)

                Spacer()
            }

            // Items
            ForEach(section.items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text(item)
                        .font(AMORTypography.bodyFont)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    }

    private var toneColor: Color {
        switch section.tone {
        case .positive:   return .green
        case .neutral:    return AMORColorPalette.deepIndigo
        case .attention:  return .orange
        case .warning:    return .red
        }
    }
}

// MARK: - Actions Card

struct BriefingActionsCard: View {
    let actions: [BriefingAction]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggested")
                .font(AMORTypography.captionFont.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(actions) { action in
                HStack(spacing: 12) {
                    Image(systemName: action.icon)
                        .font(.body)
                        .foregroundStyle(AMORColorPalette.deepIndigo)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(action.title)
                            .font(AMORTypography.bodyFont.weight(.medium))
                        Text(action.context)
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Prompt Card

struct BriefingPromptCard: View {
    let prompt: String
    let phase: BriefingPhase

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: phase == .night ? "moon.zzz.fill" : "quote.bubble.fill")
                .font(.title2)
                .foregroundStyle(phaseColor)

            Text(prompt)
                .font(AMORTypography.headingFont)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text("— A question to sit with")
                .font(AMORTypography.captionFont)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(phaseColor.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(phaseColor.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var phaseColor: Color {
        switch phase {
        case .morning:   return Color(hex: "FF8C42")
        case .midday:    return Color(hex: "6B9F4A")
        case .evening:   return Color(hex: "6B4C9A")
        case .night:     return Color(hex: "2B2D6B")
        }
    }
}

// MARK: - Color Extension (Hex init)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
