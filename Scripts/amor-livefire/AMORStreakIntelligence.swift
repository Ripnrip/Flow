/**
 * 🔥 AMORStreakIntelligence — Streak Break Detection & Recovery Intelligence
 *
 * "The keeper of the flame. Where streaks reveal their fragility, where
 * breaks become teachers, and where the path back to rhythm is illuminated
 * with gentle, data-driven wisdom."
 *
 * v3.4.0 — Weekly Review Automation & Streak Intelligence
 * v5.0.0 — MORTAL STREAKS: engine now reasons over AMORPracticeSnapshot
 *          (Foundation-only) so the live-fire harness compiles it directly.
 *          Never-started practices no longer drag the health denominator —
 *          an invitation is not a failure.
 *
 * Pure-function enum. No state. No SwiftData — fully fixture-testable.
 */

import Foundation

// MARK: - StreakRiskLevel

enum StreakRiskLevel: String, Codable {
    case safe       // Completed today, no risk
    case dueToday   // Not yet completed today
    case atRisk     // Not completed yesterday or today
    case broken     // Streak has reset
    case notStarted // Never completed

    var emoji: String {
        switch self {
        case .safe: return "✅"
        case .dueToday: return "⏰"
        case .atRisk: return "⚠️"
        case .broken: return "💔"
        case .notStarted: return "🌙"
        }
    }

    var label: String {
        switch self {
        case .safe: return "On Track"
        case .dueToday: return "Due Today"
        case .atRisk: return "At Risk"
        case .broken: return "Broken"
        case .notStarted: return "Not Started"
        }
    }
}

// MARK: - StreakInsight

/// A single actionable insight about a practice streak.
struct StreakInsight: Identifiable {
    let id = UUID()
    let practiceName: String
    let riskLevel: StreakRiskLevel
    let currentStreak: Int
    let longestStreak: Int
    let totalCompletions: Int
    let message: String
    let suggestion: String
    let priority: Int  // 1 = highest priority
}

// MARK: - StreakSummary

/// Aggregated streak health across all practices.
struct StreakSummary {
    let totalPractices: Int
    let activeStreaks: Int
    let atRiskCount: Int
    let brokenCount: Int
    let longestStreak: Int
    let totalCompletions: Int
    let overallHealthScore: Double  // 0-100
    let insights: [StreakInsight]
    let headline: String
    let motivationalMessage: String

    var healthEmoji: String {
        switch overallHealthScore {
        case 80...100: return "🔥"
        case 60..<80: return "✨"
        case 40..<60: return "🌱"
        case 20..<40: return "⚠️"
        default: return "💔"
        }
    }
}

// MARK: - AMORStreakIntelligence

/// Pure-function engine for streak analysis and intelligence.
enum AMORStreakIntelligence {

    // MARK: Started

    /// A practice is "started" once ANY completion evidence exists.
    /// Never-started practices are invitations (🌙), not failures —
    /// they never count against the health denominator. (v5.0.0 law)
    static func isStarted(_ practice: AMORPracticeSnapshot) -> Bool {
        practice.totalCompletions > 0 || practice.lastCompletedDate != nil
    }

    // MARK: - Risk Assessment

    /// Assesses the risk level for a single practice.
    static func assessRisk(practice: AMORPracticeSnapshot, referenceDate: Date = .now) -> StreakRiskLevel {
        let calendar = Calendar.current

        guard let lastCompleted = practice.lastCompletedDate else {
            return .notStarted
        }

        if calendar.isDateInToday(lastCompleted) {
            return .safe
        }

        if calendar.isDateInYesterday(lastCompleted) {
            return .dueToday
        }

        // Check if it's been more than 1 day
        let daysSince = calendar.dateComponents([.day], from: lastCompleted, to: referenceDate).day ?? 0

        if daysSince == 0 {
            // Same day (edge case with timezone)
            return .safe
        } else if daysSince == 1 {
            return .dueToday
        } else if daysSince == 2 {
            return .atRisk
        } else {
            return .broken
        }
    }

    // MARK: - Insight Generation

    /// Generates a personalized insight for a single practice.
    static func generateInsight(practice: AMORPracticeSnapshot, referenceDate: Date = .now) -> StreakInsight {
        let risk = assessRisk(practice: practice, referenceDate: referenceDate)

        let message: String
        let suggestion: String
        let priority: Int

        switch risk {
        case .safe:
            if practice.currentStreak >= 30 {
                message = "🔥 \(practice.practiceName): \(practice.currentStreak)-day streak. Legendary consistency."
                suggestion = "You've built something rare. Protect this streak — it's now part of who you are."
                priority = 5
            } else if practice.currentStreak >= 7 {
                message = "✨ \(practice.practiceName): \(practice.currentStreak)-day streak. Momentum is real."
                suggestion = "One week is the foothold. Two weeks is the habit. Keep going."
                priority = 4
            } else if practice.currentStreak >= 3 {
                message = "🌱 \(practice.practiceName): \(practice.currentStreak)-day streak. The habit is forming."
                suggestion = "Day 3 is where most people quit. You didn't."
                priority = 3
            } else {
                message = "✅ \(practice.practiceName): Completed today."
                suggestion = "Every streak starts with a single day. You're here."
                priority = 5
            }

        case .dueToday:
            if practice.currentStreak >= 7 {
                message = "⏰ \(practice.practiceName): \(practice.currentStreak)-day streak needs you TODAY."
                suggestion = "Don't let \(practice.currentStreak) days unravel. Even 5 minutes counts. Do it now."
                priority = 1
            } else if practice.currentStreak >= 3 {
                message = "⏰ \(practice.practiceName): Day \(practice.currentStreak + 1) is waiting."
                suggestion = "The streak is young and fragile. Complete it before the day slips away."
                priority = 2
            } else {
                message = "⏰ \(practice.practiceName): Due today."
                suggestion = "Start small. Showing up is the whole practice."
                priority = 2
            }

        case .atRisk:
            message = "⚠️ \(practice.practiceName): Streak at risk — \(practice.currentStreak) days, last done yesterday."
            suggestion = "Complete today to keep the streak alive. Tomorrow it resets to 1."
            priority = 1

        case .broken:
            if practice.longestStreak >= 7 {
                message = "💔 \(practice.practiceName): Streak broken. You hit \(practice.longestStreak) days before."
                suggestion = "You've proven you can do it. The path back starts with a single completion today. Begin again."
                priority = 2
            } else {
                message = "💔 \(practice.practiceName): Streak broken. Last done a few days ago."
                suggestion = "Breaks happen. What matters is the return. Start fresh today."
                priority = 3
            }

        case .notStarted:
            message = "🌙 \(practice.practiceName): Not yet started."
            suggestion = "Every practice begins with the first completion. Will today be day one?"
            priority = 3
        }

        return StreakInsight(
            practiceName: practice.practiceName,
            riskLevel: risk,
            currentStreak: practice.currentStreak,
            longestStreak: practice.longestStreak,
            totalCompletions: practice.totalCompletions,
            message: message,
            suggestion: suggestion,
            priority: priority
        )
    }

    // MARK: - Aggregate Summary

    /// Generates a comprehensive streak summary across all practices.
    /// v5.0.0 law: health is graded on STARTED practices only — a dormant
    /// practice (never any completion evidence) is an open invitation, not
    /// a wound. It can never lower the health score.
    static func generateSummary(practices: [AMORPracticeSnapshot], referenceDate: Date = .now) -> StreakSummary {
        let insights = practices.map { generateInsight(practice: $0, referenceDate: referenceDate) }
            .sorted { $0.priority < $1.priority }

        let started = practices.filter { isStarted($0) }
        let activeCount = started.filter { practice in
            guard let last = practice.lastCompletedDate else { return false }
            return Calendar.current.isDateInToday(last) ||
                   Calendar.current.isDateInYesterday(last)
        }.count

        var atRiskCount = 0
        var brokenCount = 0
        var safeCount = 0
        for insight in insights {
            switch insight.riskLevel {
            case .safe: safeCount += 1
            case .atRisk, .dueToday: atRiskCount += 1
            case .broken: brokenCount += 1
            case .notStarted: break
            }
        }

        let longest = started.map { $0.currentStreak }.max() ?? 0
        let totalCompletions = practices.reduce(0) { $0 + $1.totalCompletions }

        // Health score (v5.0.0): denominator = STARTED practices only.
        // Never-started practices are invitations — they cannot wound.
        let denominator = max(started.count, 1)
        let safeScore: Double = Double(safeCount) / Double(denominator) * 60.0
        let streakBonus: Double = min(Double(longest) / 30.0, 1.0) * 20.0
        let completionBonus: Double = min(Double(totalCompletions) / 100.0, 1.0) * 10.0
        let riskPenalty: Double = Double(atRiskCount + brokenCount) / Double(denominator) * 10.0
        let healthScore: Double = max(0, min(100, safeScore + streakBonus + completionBonus - riskPenalty))

        let headline: String
        if atRiskCount > 0 {
            headline = "\(atRiskCount) practice\(atRiskCount == 1 ? "" : "s") need attention today"
        } else if !started.isEmpty && activeCount == started.count {
            headline = "All started practices on track"
        } else if brokenCount > 0 {
            headline = "\(brokenCount) streak\(brokenCount == 1 ? "" : "s") broken — time to rebuild"
        } else if started.isEmpty {
            headline = "The first completion is waiting"
        } else {
            headline = "Your practices are taking root"
        }

        let motivational: String
        if longest >= 30 {
            motivational = "You've sustained a \(longest)-day streak. That's not luck — that's identity."
        } else if longest >= 7 {
            motivational = "A \(longest)-day streak proves the pattern. Now deepen it."
        } else if activeCount > 0 {
            motivational = "Every flame starts with a spark. You have \(activeCount) burning."
        } else {
            motivational = "The first completion is the hardest. After that, it's just showing up."
        }

        return StreakSummary(
            totalPractices: practices.count,
            activeStreaks: activeCount,
            atRiskCount: atRiskCount,
            brokenCount: brokenCount,
            longestStreak: longest,
            totalCompletions: totalCompletions,
            overallHealthScore: healthScore,
            insights: insights,
            headline: headline,
            motivationalMessage: motivational
        )
    }

    // MARK: - Streak Milestone Detection

    /// Checks if any practice has reached a notable milestone.
    static func detectMilestones(practices: [AMORPracticeSnapshot]) -> [String] {
        let milestones: [(Int, String)] = [
            (3, "🌱 3 days — the habit is forming"),
            (7, "✨ 7 days — one full week"),
            (14, "🔥 14 days — the pattern is locked in"),
            (21, "🧠 21 days — neural pathway established"),
            (30, "🏆 30 days — a month of discipline"),
            (60, "💎 60 days — this is who you are now"),
            (90, "👑 90 days — the practice owns you"),
            (100, "💯 100 days — century of devotion"),
            (180, "🌟 180 days — half a year unbroken"),
            (365, "🦁 365 days — a full year. Legendary."),
        ]

        var results: [String] = []
        for practice in practices where isStarted(practice) {
            for (days, label) in milestones {
                if practice.currentStreak == days {
                    results.append("\(practice.practiceName): \(label)")
                }
            }
        }
        return results
    }

    // MARK: - Recovery Suggestions

    /// Generates specific recovery actions for broken or at-risk streaks.
    static func recoveryActions(for practices: [AMORPracticeSnapshot], referenceDate: Date = .now) -> [String] {
        let insights = practices.map { generateInsight(practice: $0, referenceDate: referenceDate) }
        let needAttention = insights.filter { $0.priority <= 2 }

        guard !needAttention.isEmpty else { return [] }

        var actions: [String] = []
        for insight in needAttention.sorted(by: { $0.priority < $1.priority }) {
            switch insight.riskLevel {
            case .dueToday:
                actions.append("Complete \(insight.practiceName) now — \(insight.currentStreak)-day streak depends on today")
            case .atRisk:
                actions.append("⚠️ Complete \(insight.practiceName) immediately — streak breaks tomorrow")
            case .broken:
                actions.append("Start \(insight.practiceName) fresh — your record was \(insight.longestStreak) days")
            default:
                break
            }
        }
        return actions
    }
}
