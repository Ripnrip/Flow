/**
 * 🧠 AMORRhythmEngine — The Intelligence Layer for Flow
 *
 * "Where raw data becomes wisdom. Sessions, practices, and system health
 * are not merely counted — they are understood. The engine sees the pattern
 * beneath the noise, the rhythm beneath the days, the meaning beneath the metrics."
 *
 * Architecture: Foundation-only (no SwiftUI, no SwiftData queries inside).
 * Pure functions that operate on arrays of SwiftData @Model objects.
 * Fully type-checkable with swiftc -typecheck -sdk macosx.
 *
 * v2.9.0 — Rhythm Intelligence Engine
 *
 * Capabilities:
 * 1. Composite Rhythm Score (0–100) with six weighted components
 * 2. Correlation Detection (practice→mood, time→energy, day→volume, tool→affinity)
 * 3. Pattern Insight Generation (natural-language observations from data)
 * 4. Momentum Tracking (week-over-week delta and acceleration)
 * 5. Friction Detection (what's blocking your rhythm)
 */

import Foundation

// MARK: - Core Score Types

/// The composite rhythm score — AMOR's headline intelligence metric.
struct RhythmScore {
    /// Overall score 0–100
    let overall: Int

    /// Individual component scores (each 0–100)
    let consistency: Int      // How regularly you show up
    let practiceDepth: Int    // Practice streak adherence
    let focusIntensity: Int   // Total focus minutes invested
    let momentum: Int         // Week-over-week trajectory
    let reflection: Int       // Are you reflecting on your work?
    let systemHealth: Int     // Cron job health

    /// Letter grade derived from overall score
    var grade: RhythmGrade {
        RhythmGrade.from(overall)
    }

    /// One-line human-readable summary
    var summary: String {
        grade.synthesis(for: overall, delta: nil)
    }

    /// Summary with week-over-week context
    func summaryWith(delta: Int?) -> String {
        grade.synthesis(for: overall, delta: delta)
    }
}

/// Five rhythm grades, each with emoji, description, and synthesis.
enum RhythmGrade: String, CaseIterable {
    case ascending = "Ascending"
    case steady = "Steady"
    case building = "Building"
    case recovering = "Recovering"
    case dormant = "Dormant"

    var emoji: String {
        switch self {
        case .ascending:  return "🚀"
        case .steady:     return "🌿"
        case .building:   return "🔥"
        case .recovering: return "🌊"
        case .dormant:    return "🌙"
        }
    }

    var description: String {
        switch self {
        case .ascending:  return "Your rhythm is accelerating. Momentum is real."
        case .steady:     return "Consistent and grounded. The foundation holds."
        case .building:   return "Energy is gathering. Keep stoking the fire."
        case .recovering: return "You're finding your way back. Be patient."
        case .dormant:    return "The engine is quiet. One session reignites it."
        }
    }

    static func from(_ score: Int) -> RhythmGrade {
        if score >= 80 { return .ascending }
        if score >= 60 { return .steady }
        if score >= 40 { return .building }
        if score >= 20 { return .recovering }
        return .dormant
    }

    func synthesis(for score: Int, delta: Int?) -> String {
        var parts: [String] = []
        parts.append("Rhythm score: \(score)/100 (\(emoji) \(rawValue))")
        if let delta = delta {
            if delta > 0 {
                parts.append("Up \(delta) points — momentum accelerating.")
            } else if delta < 0 {
                parts.append("Down \(abs(delta)) points — gentle recalibration needed.")
            } else {
                parts.append("Holding steady.")
            }
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Correlation Types

/// A detected pattern between two variables in your rhythm data.
struct RhythmCorrelation: Identifiable, Hashable {
    let id = UUID()
    let type: CorrelationType
    let description: String    // Human-readable: "Gym days → 2.3× more flow states"
    let strength: Double       // 0.0–1.0, how strong the correlation is
    let dataPoints: Int        // How many observations back this

    var strengthLabel: String {
        if strength >= 0.7 { return "Strong" }
        if strength >= 0.4 { return "Moderate" }
        return "Weak"
    }

    var strengthDots: String {
        let filled = Int(strength * 5)
        return String(repeating: "●", count: filled) + String(repeating: "○", count: 5 - filled)
    }
}

enum CorrelationType: String, CaseIterable {
    case practiceToMood = "Practice → Mood"
    case timeOfDayToEnergy = "Time → Energy"
    case dayOfWeekToVolume = "Day → Volume"
    case toolToAffinity = "Tool → Affinity"
}

// MARK: - Insight Types

/// A natural-language observation generated from rhythm data.
struct RhythmInsight: Identifiable, Hashable {
    let id = UUID()
    let category: InsightCategory
    let title: String       // Short headline
    let detail: String      // Longer explanation
    let severity: InsightSeverity

    var icon: String {
        category.icon
    }
}

enum InsightCategory: String, CaseIterable {
    case celebration
    case observation
    case nudge
    case warning
    case pattern

    var icon: String {
        switch self {
        case .celebration: return "🎉"
        case .observation: return "📊"
        case .nudge:       return "💡"
        case .warning:     return "⚠️"
        case .pattern:     return "🔮"
        }
    }
}

enum InsightSeverity: String, CaseIterable {
    case positive   // Green/celebratory
    case neutral    // Gray/informational
    case gentle     // Yellow/encouraging
    case urgent     // Red/needs attention

    var color: String {
        switch self {
        case .positive: return "green"
        case .neutral:  return "gray"
        case .gentle:   return "yellow"
        case .urgent:   return "red"
        }
    }
}

// MARK: - Momentum Types

/// Week-over-week trajectory data.
struct RhythmMomentum {
    let currentWeekScore: Int
    let lastWeekScore: Int
    let delta: Int            // current - last
    let acceleration: Acceleration

    var arrow: String {
        switch acceleration {
        case .accelerating: return "↑↑"
        case .improving:    return "↑"
        case .stable:       return "→"
        case .declining:    return "↓"
        case .freefall:     return "↓↓"
        }
    }

    var interpretation: String {
        switch acceleration {
        case .accelerating: return "Momentum is compounding. You're not just improving — you're improving faster."
        case .improving:    return "Positive trajectory. Keep the rhythm."
        case .stable:       return "Consistent baseline. The foundation is solid."
        case .declining:    return "Slight dip. A small adjustment will restore course."
        case .freefall:     return "Significant drop. Pause, reflect, and re-engage with one practice."
        }
    }
}

enum Acceleration: String {
    case accelerating  // delta > 0 AND delta increased vs prior
    case improving     // delta > 0
    case stable        // delta ≈ 0
    case declining     // delta < 0
    case freefall      // delta < -15
}

// MARK: - Friction Types

/// Something that's creating resistance in your rhythm.
struct RhythmFriction: Identifiable, Hashable {
    let id = UUID()
    let area: String         // "Meditation", "Reflection", "System Health"
    let description: String  // "4-day gap since last meditation"
    let impact: FrictionImpact
    let suggestion: String   // "One 5-minute session breaks the inertia"
}

enum FrictionImpact: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var icon: String {
        switch self {
        case .low:    return "🟡"
        case .medium: return "🟠"
        case .high:   return "🔴"
        }
    }
}

// MARK: - Weekly Summary

/// A complete weekly snapshot — the input to narrative generation.
struct WeeklyRhythmSnapshot {
    let weekStart: Date
    let weekEnd: Date
    let score: RhythmScore
    let momentum: RhythmMomentum?
    let correlations: [RhythmCorrelation]
    let insights: [RhythmInsight]
    let frictions: [RhythmFriction]

    let sessionsCount: Int
    let activeDays: Int           // Days with at least 1 session
    let totalFocusMinutes: Int
    let practicesCompleted: Int
    let reflectionsCount: Int
    let topMood: String?
    let topTool: String?
    let longestStreak: Int

    /// A narrative-style opening line for the week.
    var openingLine: String {
        let hours = totalFocusMinutes / 60
        let mins = totalFocusMinutes % 60

        var parts: [String] = []
        parts.append("This week you showed up \(activeDays) of 7 days")
        parts.append("logging \(sessionsCount) session\(sessionsCount == 1 ? "" : "s")")

        if hours > 0 {
            parts.append("totaling \(hours)h \(mins)m")
        } else {
            parts.append("totaling \(mins) minutes")
        }

        if let m = momentum {
            switch m.acceleration {
            case .accelerating, .improving:
                parts.append("— momentum is real.")
            case .stable:
                parts.append("— steady as she goes.")
            case .declining, .freefall:
                parts.append("— a gentler week.")
            }
        }

        return parts.joined(separator: " ") + "."
    }

    /// Next-week focus suggestion derived from frictions and patterns.
    var nextWeekFocus: String {
        if let topFriction = frictions.first(where: { $0.impact == .high }) {
            return "Focus: \(topFriction.area). \(topFriction.suggestion)"
        }

        if let streak = insights.first(where: { $0.category == .celebration }) {
            return "Maintain: \(streak.title). Build on what's working."
        }

        if sessionsCount < 3 {
            return "Intention: Log at least one session per day to build the data engine."
        }

        return "Intention: Deepen what's already working. The rhythm is solid."
    }
}

// MARK: - The Engine

/// Pure-function rhythm intelligence engine.
/// Operates on arrays of SwiftData model objects — no database access inside.
enum AMORRhythmEngine {

    // MARK: - Score Computation

    /// Compute the composite rhythm score from raw data.
    static func computeScore(
        sessions: [AMORSessionSnapshot],
        practices: [AMORPracticeSnapshot],
        cronJobs: [AMORCronJobSnapshot],
        reflections: [AMORReflectionSnapshot],
        weeksOfHistory: Int = 2
    ) -> RhythmScore {
        let calendar = Calendar.current
        let now = Date()

        // --- Consistency (28%) ---
        // How many of the last 7 days had at least 1 session?
        var consistencyDays = 0
        for daysAgo in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: -daysAgo, to: now) {
                let dayStart = calendar.startOfDay(for: day)
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                let hasSession = sessions.contains { $0.date >= dayStart && $0.date < dayEnd }
                if hasSession { consistencyDays += 1 }
            }
        }
        let consistency = (consistencyDays * 100) / 7

        // --- Practice Depth (24%) ---
        // Adherence: fraction of active practices done today or yesterday
        let activePractices = practices.filter { $0.isActive || $0.isDueToday }
        let practiceAdherence: Double
        if activePractices.isEmpty {
            practiceAdherence = 0.5 // neutral if no practices set up
        } else {
            let doneRecently = activePractices.filter { practice in
                guard let last = practice.lastCompletedDate else { return false }
                return calendar.isDateInToday(last) || calendar.isDateInYesterday(last)
            }.count
            practiceAdherence = Double(doneRecently) / Double(activePractices.count)
        }
        // Factor in longest current streak for bonus
        let maxStreak = practices.map { $0.currentStreak }.max() ?? 0
        let streakBonus = min(maxStreak * 3, 20) // up to +20 for streak
        let practiceDepth = min(Int(practiceAdherence * 80) + streakBonus, 100)

        // --- Focus Intensity (20%) ---
        // Total focus minutes this week, scaled (180min = 100)
        let weekStart = calendar.date(byAdding: .day, value: -7, to: now)!
        let weekFocus = sessions
            .filter { $0.date >= weekStart }
            .reduce(0) { $0 + $1.durationMinutes }
        let focusIntensity = min((weekFocus * 100) / 180, 100)

        // --- Momentum (14%) ---
        // Compare this week's sessions to last week's
        let thisWeekSessions = sessions.filter { $0.date >= weekStart }.count
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now)!
        let lastWeekSessions = sessions.filter { $0.date >= twoWeeksAgo && $0.date < weekStart }.count
        let momentumRaw: Double
        if lastWeekSessions == 0 {
            momentumRaw = thisWeekSessions > 0 ? 0.7 : 0.3
        } else {
            let ratio = Double(thisWeekSessions) / Double(max(lastWeekSessions, 1))
            momentumRaw = min(ratio, 1.5) / 1.5
        }
        let momentum = Int(momentumRaw * 100)

        // --- Reflection (10%) ---
        // Have you reflected recently?
        let recentReflections = reflections.filter { $0.date >= weekStart }
        let reflection: Int
        switch recentReflections.count {
        case 0:          reflection = 20
        case 1:          reflection = 50
        case 2...3:      reflection = 80
        default:         reflection = 100
        }

        // --- System Health (4%) ---
        let enabledJobs = cronJobs.filter { $0.isEnabled }
        let healthyCount = enabledJobs.filter { $0.healthStatus == "healthy" }.count
        let systemHealth = enabledJobs.isEmpty ? 100 : (healthyCount * 100) / enabledJobs.count

        // --- Weighted Composite ---
        let overall = Int(
            Double(consistency) * 0.28 +
            Double(practiceDepth) * 0.24 +
            Double(focusIntensity) * 0.20 +
            Double(momentum) * 0.14 +
            Double(reflection) * 0.10 +
            Double(systemHealth) * 0.04
        )

        return RhythmScore(
            overall: max(0, min(100, overall)),
            consistency: consistency,
            practiceDepth: practiceDepth,
            focusIntensity: focusIntensity,
            momentum: momentum,
            reflection: reflection,
            systemHealth: systemHealth
        )
    }

    // MARK: - Momentum Computation

    static func computeMomentum(
        sessions: [AMORSessionSnapshot],
        practices: [AMORPracticeSnapshot]
    ) -> RhythmMomentum? {
        let calendar = Calendar.current
        let now = Date()
        let thisWeekStart = calendar.date(byAdding: .day, value: -7, to: now)!
        let lastWeekStart = calendar.date(byAdding: .day, value: -14, to: now)!

        let thisWeekScore = miniScore(sessions: sessions.filter { $0.date >= thisWeekStart },
                                       practices: practices)
        let lastWeekScore = miniScore(sessions: sessions.filter { $0.date >= lastWeekStart && $0.date < thisWeekStart },
                                       practices: practices)

        let delta = thisWeekScore - lastWeekScore
        let acceleration: Acceleration
        if delta > 10 { acceleration = .accelerating }
        else if delta > 0 { acceleration = .improving }
        else if delta > -5 { acceleration = .stable }
        else if delta > -15 { acceleration = .declining }
        else { acceleration = .freefall }

        return RhythmMomentum(
            currentWeekScore: thisWeekScore,
            lastWeekScore: lastWeekScore,
            delta: delta,
            acceleration: acceleration
        )
    }

    /// Simplified 0-100 score for momentum comparison (sessions + practices only).
    private static func miniScore(sessions: [AMORSessionSnapshot], practices: [AMORPracticeSnapshot]) -> Int {
        let focusMins = sessions.reduce(0) { $0 + $1.durationMinutes }
        let sessionScore = min(focusMins / 3, 60)  // 180min → 60
        let activePractices = practices.filter { $0.isActive }.count
        let practiceScore = min(activePractices * 10, 40) // 4+ practices → 40
        return sessionScore + practiceScore
    }

    // MARK: - Correlation Detection

    /// Detect patterns in the user's rhythm data.
    static func detectCorrelations(
        sessions: [AMORSessionSnapshot],
        practices: [AMORPracticeSnapshot]
    ) -> [RhythmCorrelation] {
        var correlations: [RhythmCorrelation] = []

        // Only attempt correlations with enough data
        guard sessions.count >= 5 else { return correlations }

        // 1. Practice → Mood correlation
        // Compare moods on days with completed practices vs days without
        correlations.append(contentsOf: detectPracticeMoodCorrelation(sessions: sessions, practices: practices))

        // 2. Time-of-day → Energy
        correlations.append(contentsOf: detectTimeEnergyCorrelation(sessions: sessions))

        // 3. Day-of-week → Volume
        correlations.append(contentsOf: detectDayVolumeCorrelation(sessions: sessions))

        // 4. Tool → High-energy affinity
        correlations.append(contentsOf: detectToolAffinityCorrelation(sessions: sessions))

        // Sort by strength descending, take top 4
        return correlations.sorted { $0.strength > $1.strength }.prefix(4).map { $0 }
    }

    /// Days where practices were completed tend to have higher-energy moods.
    private static func detectPracticeMoodCorrelation(
        sessions: [AMORSessionSnapshot],
        practices: [AMORPracticeSnapshot]
    ) -> [RhythmCorrelation] {
        let highEnergyMoods: Set<String> = ["focused", "energized", "flow", "excited", "productive", "inspired"]
        let calendar = Calendar.current

        // For each practice, find sessions on the same day as completion
        var practiceFlowRatios: [(name: String, ratio: Double, points: Int)] = []

        for practice in practices {
            guard let lastCompleted = practice.lastCompletedDate else { continue }

            // Find sessions on the same day as recent completions
            let sameDaySessions = sessions.filter { session in
                calendar.isDate(session.date, inSameDayAs: lastCompleted)
            }
            guard sameDaySessions.count >= 2 else { continue }

            let highEnergyCount = sameDaySessions.filter { highEnergyMoods.contains($0.mood.lowercased()) }.count
            let ratio = Double(highEnergyCount) / Double(sameDaySessions.count)
            practiceFlowRatios.append((practice.practiceName, ratio, sameDaySessions.count))
        }

        return practiceFlowRatios.compactMap { item in
            guard item.ratio > 0.4 else { return nil }
            let multiplier = item.ratio / 0.3 // normalize: 0.3 is baseline
            guard multiplier >= 1.3 else { return nil }
            return RhythmCorrelation(
                type: .practiceToMood,
                description: "\(item.name) days produce \(String(format: "%.1f", multiplier))× more high-energy sessions.",
                strength: min(item.ratio, 1.0),
                dataPoints: item.points
            )
        }
    }

    /// Certain hours of the day tend to produce higher-energy sessions.
    private static func detectTimeEnergyCorrelation(sessions: [AMORSessionSnapshot]) -> [RhythmCorrelation] {
        let highEnergyMoods: Set<String> = ["focused", "energized", "flow", "excited", "productive", "inspired"]
        let calendar = Calendar.current

        var hourBuckets: [Int: (total: Int, highEnergy: Int)] = [:]
        for session in sessions {
            let hour = calendar.component(.hour, from: session.date)
            var bucket = hourBuckets[hour, default: (0, 0)]
            bucket.total += 1
            if highEnergyMoods.contains(session.mood.lowercased()) {
                bucket.highEnergy += 1
            }
            hourBuckets[hour] = bucket
        }

        // Find the best hour with at least 3 sessions
        let bestHour = hourBuckets
            .filter { $0.value.total >= 3 }
            .max { ($0.value.highEnergy * 100 / max($0.value.total, 1)) < ($1.value.highEnergy * 100 / max($1.value.total, 1)) }

        if let (hour, bucket) = bestHour, bucket.total >= 3 {
            let pct = (bucket.highEnergy * 100) / bucket.total
            if pct >= 50 {
                let hourStr = hour > 12 ? "\(hour - 12) PM" : (hour == 12 ? "12 PM" : "\(hour) AM")
                let strength = Double(pct) / 100.0
                return [RhythmCorrelation(
                    type: .timeOfDayToEnergy,
                    description: "Peak energy window: \(hourStr). \(pct)% of sessions there are high-energy.",
                    strength: strength,
                    dataPoints: bucket.total
                )]
            }
        }
        return []
    }

    /// Certain days of the week tend to have more session volume.
    private static func detectDayVolumeCorrelation(sessions: [AMORSessionSnapshot]) -> [RhythmCorrelation] {
        let calendar = Calendar.current
        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

        var dayBuckets: [Int: Int] = [:] // weekday → session count
        for session in sessions {
            let weekday = calendar.component(.weekday, from: session.date) - 1 // 0=Sunday
            dayBuckets[weekday, default: 0] += 1
        }

        guard let bestDay = dayBuckets.max(by: { $0.value < $1.value }), bestDay.value >= 3 else {
            return []
        }

        let avgSessions = Double(sessions.count) / 7.0
        let ratio = Double(bestDay.value) / max(avgSessions, 1.0)
        guard ratio >= 1.3 else { return [] }

        let strength = min(ratio / 2.0, 1.0)
        return [RhythmCorrelation(
            type: .dayOfWeekToVolume,
            description: "Strongest day: \(dayNames[bestDay.key]). \(bestDay.value) sessions — \(String(format: "%.1f", ratio))× the daily average.",
            strength: strength,
            dataPoints: bestDay.value
        )]
    }

    /// Certain tools tend to be used in high-energy sessions.
    private static func detectToolAffinityCorrelation(sessions: [AMORSessionSnapshot]) -> [RhythmCorrelation] {
        let highEnergyMoods: Set<String> = ["focused", "energized", "flow", "excited", "productive", "inspired"]

        var toolBuckets: [String: (total: Int, highEnergy: Int)] = [:]
        for session in sessions {
            let tools = parseCSV(session.toolsUsed)
            let isHighEnergy = highEnergyMoods.contains(session.mood.lowercased())
            for tool in tools {
                var bucket = toolBuckets[tool, default: (0, 0)]
                bucket.total += 1
                if isHighEnergy { bucket.highEnergy += 1 }
                toolBuckets[tool] = bucket
            }
        }

        guard let bestTool = toolBuckets
            .filter({ $0.value.total >= 3 })
            .max(by: {
                ($0.value.highEnergy * 100 / max($0.value.total, 1)) < ($1.value.highEnergy * 100 / max($1.value.total, 1))
            }),
              bestTool.value.total >= 3 else { return [] }

        let pct = (bestTool.value.highEnergy * 100) / bestTool.value.total
        guard pct >= 50 else { return [] }

        return [RhythmCorrelation(
            type: .toolToAffinity,
            description: "\(bestTool.key) appears in \(pct)% of high-energy sessions.",
            strength: Double(pct) / 100.0,
            dataPoints: bestTool.value.total
        )]
    }

    // MARK: - Insight Generation

    /// Generate natural-language insights from all data.
    static func generateInsights(
        score: RhythmScore,
        momentum: RhythmMomentum?,
        correlations: [RhythmCorrelation],
        sessions: [AMORSessionSnapshot],
        practices: [AMORPracticeSnapshot],
        cronJobs: [AMORCronJobSnapshot],
        reflections: [AMORReflectionSnapshot]
    ) -> [RhythmInsight] {
        var insights: [RhythmInsight] = []
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(byAdding: .day, value: -7, to: now)!

        // --- Celebration: High score or strong streak ---
        if score.overall >= 75 {
            insights.append(RhythmInsight(
                category: .celebration,
                title: "Rhythm score \(score.overall) — elite territory",
                detail: "You're in the top rhythm band. \(score.grade.description)",
                severity: .positive
            ))
        }

        if let topStreak = practices.max(by: { $0.currentStreak < $1.currentStreak }), topStreak.currentStreak >= 7 {
            insights.append(RhythmInsight(
                category: .celebration,
                title: "\(topStreak.practiceName): \(topStreak.currentStreak)-day streak 🔥",
                detail: "Longest active streak. \(topStreak.currentStreak >= topStreak.longestStreak ? "This is your all-time best!" : "Your record is \(topStreak.longestStreak) days.")",
                severity: .positive
            ))
        }

        // --- Momentum insight ---
        if let m = momentum {
            switch m.acceleration {
            case .accelerating:
                insights.append(RhythmInsight(
                    category: .pattern,
                    title: "Momentum: accelerating (+\(m.delta))",
                    detail: m.interpretation,
                    severity: .positive
                ))
            case .freefall:
                insights.append(RhythmInsight(
                    category: .warning,
                    title: "Momentum: significant drop (\(m.delta))",
                    detail: m.interpretation,
                    severity: .urgent
                ))
            default:
                break
            }
        }

        // --- Top correlation as pattern insight ---
        if let topCorrelation = correlations.first {
            insights.append(RhythmInsight(
                category: .pattern,
                title: topCorrelation.description,
                detail: "\(topCorrelation.strengthLabel) correlation based on \(topCorrelation.dataPoints) data points. \(topCorrelation.strengthDots)",
                severity: .neutral
            ))
        }

        // --- Practice gap nudge ---
        for practice in practices {
            if let last = practice.lastCompletedDate {
                let daysSince = calendar.dateComponents([.day], from: last, to: now).day ?? 0
                if daysSince >= 3 && practice.currentStreak == 0 {
                    insights.append(RhythmInsight(
                        category: .nudge,
                        title: "\(practice.practiceName) gap: \(daysSince) days",
                        detail: "Break the inertia. One session reignites the streak.",
                        severity: .gentle
                    ))
                }
            }
        }

        // --- Reflection gap ---
        let weekReflections = reflections.filter { $0.date >= weekStart }
        let weekSessions = sessions.filter { $0.date >= weekStart }
        if weekSessions.count >= 3 && weekReflections.count == 0 {
            insights.append(RhythmInsight(
                category: .nudge,
                title: "\(weekSessions.count) sessions, 0 reflections",
                detail: "The 'why' matters as much as the 'what'. Consider a reflection entry.",
                severity: .gentle
            ))
        }

        // --- System health warning ---
        let failingJobs = cronJobs.filter { $0.isEnabled && $0.healthStatus == "critical" }
        if !failingJobs.isEmpty {
            insights.append(RhythmInsight(
                category: .warning,
                title: "\(failingJobs.count) system\(failingJobs.count > 1 ? "s" : "") need attention",
                detail: failingJobs.map { $0.jobName }.prefix(3).joined(separator: ", "),
                severity: .urgent
            ))
        }

        // --- Focus observation ---
        let weekFocus = weekSessions.reduce(0) { $0 + $1.durationMinutes }
        if weekFocus >= 600 { // 10+ hours
            let hours = weekFocus / 60
            insights.append(RhythmInsight(
                category: .observation,
                title: "\(hours) hours of deep work this week",
                detail: "Sustained focus investment. Your consistency score: \(score.consistency)/100.",
                severity: .positive
            ))
        }

        return insights
    }

    // MARK: - Friction Detection

    /// Identify what's creating resistance in the rhythm.
    static func detectFriction(
        sessions: [AMORSessionSnapshot],
        practices: [AMORPracticeSnapshot],
        cronJobs: [AMORCronJobSnapshot],
        reflections: [AMORReflectionSnapshot]
    ) -> [RhythmFriction] {
        var frictions: [RhythmFriction] = []
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(byAdding: .day, value: -7, to: now)!

        // Session gap
        let recentSessions = sessions.filter { $0.date >= weekStart }
        if recentSessions.isEmpty {
            frictions.append(RhythmFriction(
                area: "Session Logging",
                description: "No sessions logged this week",
                impact: .high,
                suggestion: "Log one session to restart the data engine."
            ))
        } else if recentSessions.count < 3 {
            frictions.append(RhythmFriction(
                area: "Session Volume",
                description: "Only \(recentSessions.count) session\(recentSessions.count == 1 ? "" : "s") this week",
                impact: .medium,
                suggestion: "Aim for daily logging to strengthen pattern detection."
            ))
        }

        // Practice gaps
        for practice in practices {
            if let last = practice.lastCompletedDate {
                let daysSince = calendar.dateComponents([.day], from: last, to: now).day ?? 0
                if daysSince >= 3 {
                    let impact: FrictionImpact = daysSince >= 7 ? .high : .medium
                    frictions.append(RhythmFriction(
                        area: practice.practiceName,
                        description: "\(daysSince)-day gap since last \(practice.practiceName.lowercased())",
                        impact: impact,
                        suggestion: "One 5-minute session breaks the inertia."
                    ))
                }
            } else {
                frictions.append(RhythmFriction(
                    area: practice.practiceName,
                    description: "Never completed",
                    impact: .low,
                    suggestion: "Start \(practice.practiceName.lowercased()) today."
                ))
            }
        }

        // Reflection deficit
        let weekReflections = reflections.filter { $0.date >= weekStart }
        if weekReflections.isEmpty {
            frictions.append(RhythmFriction(
                area: "Reflection",
                description: "No reflections this week",
                impact: .low,
                suggestion: "A 2-minute reflection deepens the data's meaning."
            ))
        }

        // System health
        let criticalJobs = cronJobs.filter { $0.isEnabled && $0.healthStatus == "critical" }
        if !criticalJobs.isEmpty {
            frictions.append(RhythmFriction(
                area: "System Health",
                description: "\(criticalJobs.count) critical job\(criticalJobs.count > 1 ? "s" : "")",
                impact: .high,
                suggestion: "Check Systems tab — silent failures compound."
            ))
        }

        // Sort by impact (high → medium → low)
        let order: [FrictionImpact] = [.high, .medium, .low]
        return frictions.sorted { a, b in
            let aIdx = order.firstIndex(of: a.impact) ?? 99
            let bIdx = order.firstIndex(of: b.impact) ?? 99
            return aIdx < bIdx
        }
    }

    // MARK: - Full Weekly Snapshot

    /// Produce a complete weekly rhythm snapshot — the master intelligence output.
    static func generateWeeklySnapshot(
        sessions: [AMORSessionSnapshot],
        practices: [AMORPracticeSnapshot],
        cronJobs: [AMORCronJobSnapshot],
        reflections: [AMORReflectionSnapshot]
    ) -> WeeklyRhythmSnapshot {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(byAdding: .day, value: -7, to: now)!
        let weekEnd = now

        let score = computeScore(
            sessions: sessions, practices: practices,
            cronJobs: cronJobs, reflections: reflections
        )
        let momentum = computeMomentum(sessions: sessions, practices: practices)
        let correlations = detectCorrelations(sessions: sessions, practices: practices)
        let insights = generateInsights(
            score: score, momentum: momentum, correlations: correlations,
            sessions: sessions, practices: practices,
            cronJobs: cronJobs, reflections: reflections
        )
        let frictions = detectFriction(
            sessions: sessions, practices: practices,
            cronJobs: cronJobs, reflections: reflections
        )

        let weekSessions = sessions.filter { $0.date >= weekStart }
        let activeDays = countActiveDays(sessions: weekSessions)
        let totalFocus = weekSessions.reduce(0) { $0 + $1.durationMinutes }
        let practicesCompleted = practices.filter { p in
            guard let last = p.lastCompletedDate else { return false }
            return last >= weekStart
        }.count
        let topMood = mostCommonMood(sessions: weekSessions)
        let topTool = mostCommonTool(sessions: weekSessions)
        let longestStreak = practices.map { $0.currentStreak }.max() ?? 0

        return WeeklyRhythmSnapshot(
            weekStart: weekStart, weekEnd: weekEnd,
            score: score, momentum: momentum,
            correlations: correlations, insights: insights, frictions: frictions,
            sessionsCount: weekSessions.count, activeDays: activeDays,
            totalFocusMinutes: totalFocus, practicesCompleted: practicesCompleted,
            reflectionsCount: reflections.filter { $0.date >= weekStart }.count,
            topMood: topMood, topTool: topTool,
            longestStreak: longestStreak
        )
    }

    // MARK: - Helpers

    private static func countActiveDays(sessions: [AMORSessionSnapshot]) -> Int {
        let calendar = Calendar.current
        var days: Set<DateComponents> = []
        for session in sessions {
            let comps = calendar.dateComponents([.year, .month, .day], from: session.date)
            days.insert(comps)
        }
        return days.count
    }

    private static func mostCommonMood(sessions: [AMORSessionSnapshot]) -> String? {
        guard !sessions.isEmpty else { return nil }
        var counts: [String: Int] = [:]
        for s in sessions { counts[s.mood, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private static func mostCommonTool(sessions: [AMORSessionSnapshot]) -> String? {
        guard !sessions.isEmpty else { return nil }
        var counts: [String: Int] = [:]
        for s in sessions {
            for tool in parseCSV(s.toolsUsed) {
                counts[tool, default: 0] += 1
            }
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private static func parseCSV(_ csv: String) -> [String] {
        csv.split(separator: ",")
           .map { $0.trimmingCharacters(in: .whitespaces) }
           .filter { !$0.isEmpty }
    }
}
