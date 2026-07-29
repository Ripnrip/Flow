/**
 * 🧠 AMORRhythmView — The Intelligence Surface
 *
 * "Where numbers breathe and patterns speak. This is not a dashboard —
 * it is a mirror that reflects the shape of your days, the weight of
 * your practices, and the direction of your momentum."
 *
 * v2.9.0 — Rhythm Intelligence UI
 *
 * Architecture: SwiftUI views consuming AMORRhythmEngine pure functions.
 * Tab structure: Score Hero → Breakdown → Correlations → Insights → Friction → Momentum
 */

import SwiftUI
import SwiftData

// MARK: - Main Rhythm View (Full Tab)

struct AMORRhythmView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [DailySession]
    @Query private var practices: [PracticeStreak]
    @Query private var cronJobs: [CronJobHealth]
    @Query private var reflections: [ReflectionEntry]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Score Hero
                ScoreHeroCard()

                // Component Breakdown
                ScoreBreakdownCard()

                // Momentum
                MomentumCard()

                // Correlations
                CorrelationsCard()

                // Insights
                InsightsCard()

                // Friction
                FrictionCard()

                // Weekly Narrative Opening
                NarrativeOpeningCard()

                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Rhythm")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Score Hero Card

/// Large display of the overall rhythm score with grade.
struct ScoreHeroCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [DailySession]
    @Query private var practices: [PracticeStreak]
    @Query private var cronJobs: [CronJobHealth]
    @Query private var reflections: [ReflectionEntry]

    private var score: RhythmScore {
        AMORRhythmEngine.computeScore(
            sessions: sessions,
            practices: practices,
            cronJobs: cronJobs,
            reflections: reflections
        )
    }

    private var momentum: RhythmMomentum? {
        AMORRhythmEngine.computeMomentum(sessions: sessions, practices: practices)
    }

    var body: some View {
        AMORComponents.ContemplativeCard {
            VStack(spacing: 16) {
                // Grade emoji
                Text(score.grade.emoji)
                    .font(.system(size: 56))

                // Score number
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(score.overall)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(AMORColorPalette.deepIndigo)
                    Text("/ 100")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                // Grade label
                Text(score.grade.rawValue)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AMORColorPalette.twilightPurple)

                // Delta indicator
                if let delta = momentum?.delta {
                    HStack(spacing: 4) {
                        Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                        Text(delta >= 0 ? "+\(delta) vs last week" : "\(delta) vs last week")
                            .font(.caption)
                    }
                    .foregroundStyle(delta >= 0 ? .green : .orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(delta >= 0 ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                    .clipShape(Capsule())
                }

                // Description
                Text(score.grade.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Score Breakdown Card

/// Six weighted component scores as progress bars.
struct ScoreBreakdownCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [DailySession]
    @Query private var practices: [PracticeStreak]
    @Query private var cronJobs: [CronJobHealth]
    @Query private var reflections: [ReflectionEntry]

    private var score: RhythmScore {
        AMORRhythmEngine.computeScore(
            sessions: sessions, practices: practices,
            cronJobs: cronJobs, reflections: reflections
        )
    }

    var body: some View {
        AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Score Breakdown")
                    .font(.headline)
                    .foregroundStyle(AMORColorPalette.deepIndigo)

                ComponentBar(label: "Consistency", value: score.consistency, weight: "28%", icon: "calendar")
                ComponentBar(label: "Practice", value: score.practiceDepth, weight: "24%", icon: "flame.fill")
                ComponentBar(label: "Focus", value: score.focusIntensity, weight: "20%", icon: "timer")
                ComponentBar(label: "Momentum", value: score.momentum, weight: "14%", icon: "chart.line.uptrend.xyaxis")
                ComponentBar(label: "Reflection", value: score.reflection, weight: "10%", icon: "moon.stars")
                ComponentBar(label: "Systems", value: score.systemHealth, weight: "4%", icon: "gearshape")
            }
        }
    }
}

struct ComponentBar: View {
    let label: String
    let value: Int
    let weight: String
    let icon: String

    private var barColor: Color {
        switch value {
        case 80...:  return .green
        case 60..<80: return AMORColorPalette.deepIndigo
        case 40..<60: return AMORColorPalette.dawnOrange
        case 20..<40: return .orange
        default:      return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(label, systemImage: icon)
                    .font(.subheadline)
                Spacer()
                Text("\(value)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(barColor)
                Text("(\(weight))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(value), total: 100)
                .tint(barColor)
                .scaleEffect(y: 1.3)
        }
    }
}

// MARK: - Momentum Card

struct MomentumCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [DailySession]
    @Query private var practices: [PracticeStreak]

    private var momentum: RhythmMomentum? {
        AMORRhythmEngine.computeMomentum(sessions: sessions, practices: practices)
    }

    var body: some View {
        if let m = momentum {
            AMORComponents.ContemplativeCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Momentum")
                            .font(.headline)
                            .foregroundStyle(AMORColorPalette.deepIndigo)
                        Spacer()
                        Text(m.arrow)
                            .font(.title2)
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading) {
                            Text("This Week")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(m.currentWeekScore)")
                                .font(.title2.weight(.bold))
                        }

                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading) {
                            Text("Last Week")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(m.lastWeekScore)")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("Delta")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(m.delta >= 0 ? "+\(m.delta)" : "\(m.delta)")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(m.delta >= 0 ? .green : .orange)
                        }
                    }

                    Text(m.interpretation)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Correlations Card

struct CorrelationsCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [DailySession]
    @Query private var practices: [PracticeStreak]

    private var correlations: [RhythmCorrelation] {
        AMORRhythmEngine.detectCorrelations(sessions: sessions, practices: practices)
    }

    var body: some View {
        AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Patterns Detected")
                        .font(.headline)
                        .foregroundStyle(AMORColorPalette.deepIndigo)
                    Spacer()
                    Text("\(correlations.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AMORColorPalette.twilightPurple)
                        .clipShape(Capsule())
                }

                if correlations.isEmpty {
                    Text("Not enough data yet. Log 5+ sessions to unlock pattern detection.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    ForEach(correlations) { corr in
                        CorrelationRow(corr: corr)
                        if corr.id != correlations.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

struct CorrelationRow: View {
    let corr: RhythmCorrelation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(corr.type.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(AMORColorPalette.sageGreen)
                    .clipShape(Capsule())

                Text(corr.strengthLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(corr.strengthDots)
                    .font(.caption2)
                    .foregroundStyle(AMORColorPalette.dawnOrange)
            }

            Text(corr.description)
                .font(.subheadline)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Insights Card

struct InsightsCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [DailySession]
    @Query private var practices: [PracticeStreak]
    @Query private var cronJobs: [CronJobHealth]
    @Query private var reflections: [ReflectionEntry]

    private var insights: [RhythmInsight] {
        let score = AMORRhythmEngine.computeScore(
            sessions: sessions, practices: practices,
            cronJobs: cronJobs, reflections: reflections
        )
        let momentum = AMORRhythmEngine.computeMomentum(sessions: sessions, practices: practices)
        let correlations = AMORRhythmEngine.detectCorrelations(sessions: sessions, practices: practices)
        return AMORRhythmEngine.generateInsights(
            score: score, momentum: momentum, correlations: correlations,
            sessions: sessions, practices: practices,
            cronJobs: cronJobs, reflections: reflections
        )
    }

    var body: some View {
        AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Insights")
                    .font(.headline)
                    .foregroundStyle(AMORColorPalette.deepIndigo)

                if insights.isEmpty {
                    Text("Your rhythm is balanced. No urgent signals.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    ForEach(insights) { insight in
                        InsightRow(insight: insight)
                        if insight.id != insights.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

struct InsightRow: View {
    let insight: RhythmInsight

    private var severityColor: Color {
        switch insight.severity {
        case .positive: return .green
        case .neutral:  return AMORColorPalette.deepIndigo
        case .gentle:   return AMORColorPalette.dawnOrange
        case .urgent:   return .red
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(insight.icon)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(severityColor)

                Text(insight.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Friction Card

struct FrictionCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [DailySession]
    @Query private var practices: [PracticeStreak]
    @Query private var cronJobs: [CronJobHealth]
    @Query private var reflections: [ReflectionEntry]

    private var frictions: [RhythmFriction] {
        AMORRhythmEngine.detectFriction(
            sessions: sessions, practices: practices,
            cronJobs: cronJobs, reflections: reflections
        )
    }

    var body: some View {
        AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Friction")
                    .font(.headline)
                    .foregroundStyle(AMORColorPalette.deepIndigo)

                if frictions.isEmpty {
                    Text("No friction detected. Your rhythm flows smoothly. ✨")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    ForEach(frictions) { friction in
                        FrictionRow(friction: friction)
                        if friction.id != frictions.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

struct FrictionRow: View {
    let friction: RhythmFriction

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(friction.impact.icon)
                .font(.caption)

            VStack(alignment: .leading, spacing: 4) {
                Text(friction.area)
                    .font(.subheadline.weight(.semibold))

                Text(friction.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(friction.suggestion)
                    .font(.caption2)
                    .foregroundStyle(AMORColorPalette.sageGreen)
                    .italic()
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Narrative Opening Card

struct NarrativeOpeningCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [DailySession]
    @Query private var practices: [PracticeStreak]
    @Query private var cronJobs: [CronJobHealth]
    @Query private var reflections: [ReflectionEntry]

    private var snapshot: WeeklyRhythmSnapshot {
        AMORRhythmEngine.generateWeeklySnapshot(
            sessions: sessions, practices: practices,
            cronJobs: cronJobs, reflections: reflections
        )
    }

    var body: some View {
        AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("The Week in Words")
                    .font(.headline)
                    .foregroundStyle(AMORColorPalette.deepIndigo)

                Text(snapshot.openingLine)
                    .font(.body.italic())
                    .foregroundStyle(.primary)

                if !snapshot.correlations.isEmpty {
                    Divider()
                    Text("Pattern: \(snapshot.correlations.first!.description)")
                        .font(.caption)
                        .foregroundStyle(AMORColorPalette.sageGreen)
                }

                Divider()

                Text(snapshot.nextWeekFocus)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(AMORColorPalette.twilightPurple)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Compact Dashboard Card

/// Compact version for embedding in the Dashboard tab.
struct RhythmScoreCompactCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [DailySession]
    @Query private var practices: [PracticeStreak]
    @Query private var cronJobs: [CronJobHealth]
    @Query private var reflections: [ReflectionEntry]

    private var score: RhythmScore {
        AMORRhythmEngine.computeScore(
            sessions: sessions, practices: practices,
            cronJobs: cronJobs, reflections: reflections
        )
    }

    private var momentum: RhythmMomentum? {
        AMORRhythmEngine.computeMomentum(sessions: sessions, practices: practices)
    }

    var body: some View {
        AMORComponents.ContemplativeCard {
            VStack(spacing: 12) {
                HStack {
                    Text(score.grade.emoji)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rhythm Score")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(score.overall)")
                                .font(.title.weight(.bold))
                            Text(score.grade.rawValue)
                                .font(.caption)
                                .foregroundStyle(AMORColorPalette.twilightPurple)
                        }
                    }

                    Spacer()

                    if let m = momentum {
                        VStack(alignment: .trailing) {
                            Text(m.arrow)
                                .font(.title3)
                            Text("\(m.delta >= 0 ? "+" : "")\(m.delta)")
                                .font(.caption2)
                                .foregroundStyle(m.delta >= 0 ? .green : .orange)
                        }
                    }
                }

                // Mini breakdown
                HStack(spacing: 4) {
                    MiniBar(label: "C", value: score.consistency)
                    MiniBar(label: "P", value: score.practiceDepth)
                    MiniBar(label: "F", value: score.focusIntensity)
                    MiniBar(label: "M", value: score.momentum)
                    MiniBar(label: "R", value: score.reflection)
                    MiniBar(label: "S", value: score.systemHealth)
                }
            }
        }
    }
}

struct MiniBar: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            ProgressView(value: Double(value), total: 100)
                .tint(value >= 60 ? .green : (value >= 40 ? AMORColorPalette.dawnOrange : .red))
                .scaleEffect(y: 0.8)
        }
    }
}
