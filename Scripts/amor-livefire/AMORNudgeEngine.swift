/**
 * 🔔 AMORNudgeEngine — Proactive Intelligence & Notification Logic
 *
 * "The gentle hand on the shoulder. Where data awakens into action,
 * where the silent observation of patterns becomes a timely whisper
 * that guides without demanding, alerts without alarming."
 *
 * v3.7.0 — Proactive Notification & Nudge Engine
 *
 * Pure-function enum. No state. Reads PracticeStreak and CronJobHealth
 * @Model objects + existing intelligence engines (StreakIntelligence,
 * CronStatusReader). Produces NudgeDescriptors that the NotificationManager
 * translates into UNNotificationRequests.
 *
 * Nudge Categories:
 *   1. Streak Risk      — Practice due today or at risk (priority-sorted)
 *   2. Cron Failure     — Jobs failing or consecutively erroring
 *   3. Milestone        — Practice hit 7/14/30/100/etc days
 *   4. Morning Briefing — Time-based daily reminder
 *   5. Evening Review   — End-of-day session logging nudge
 *   6. Weekly Review    — Sunday weekly-review prompt
 *   7. Inactivity       — No sessions logged in 24h+ (gentle)
 *
 * Architecture: Foundation-only. Type-checks with swiftc -parse.
 * Uses the stub-model pattern for swiftc -typecheck verification.
 */

import Foundation

// MARK: - Nudge Category

enum AMORNudgeCategory: String, Codable, CaseIterable {
    case streakRisk      = "streak_risk"
    case cronFailure     = "cron_failure"
    case milestone       = "milestone"
    case morningBriefing = "morning_briefing"
    case eveningReview   = "evening_review"
    case weeklyReview    = "weekly_review"
    case inactivity      = "inactivity"

    var displayName: String {
        switch self {
        case .streakRisk:      return "Streak Alerts"
        case .cronFailure:     return "Cron Failures"
        case .milestone:       return "Milestones"
        case .morningBriefing: return "Morning Briefing"
        case .eveningReview:   return "Evening Review"
        case .weeklyReview:    return "Weekly Review"
        case .inactivity:      return "Inactivity"
        }
    }

    var icon: String {
        switch self {
        case .streakRisk:      return "flame.fill"
        case .cronFailure:     return "exclamationmark.triangle.fill"
        case .milestone:       return "star.fill"
        case .morningBriefing: return "sun.max.fill"
        case .eveningReview:   return "moon.fill"
        case .weeklyReview:    return "calendar.badge.clock"
        case .inactivity:      return "wind"
        }
    }

    /// UserDefaults settings key for toggling this category
    var settingsKey: String {
        "amor.nudges.\(rawValue)"
    }

    /// Whether this category is enabled by default
    var defaultEnabled: Bool {
        switch self {
        case .streakRisk, .cronFailure, .milestone: return true
        case .morningBriefing, .eveningReview:      return true
        case .weeklyReview:                          return true
        case .inactivity:                            return false
        }
    }
}

// MARK: - Nudge Priority

enum AMORNudgePriority: Int, Comparable {
    case critical = 0   // cron failures, streaks about to break
    case high     = 1   // streak due today, milestone reached
    case normal   = 2   // daily reminders
    case low      = 3   // gentle inactivity nudges

    static func < (lhs: AMORNudgePriority, rhs: AMORNudgePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Nudge Trigger

enum AMORNudgeTrigger: Equatable {
    /// Fire immediately (within ~60 seconds)
    case immediate
    /// Fire after N seconds
    case afterInterval(TimeInterval)
    /// Fire daily at hour:minute (24h format)
    case daily(hour: Int, minute: Int)
    /// Fire weekly on weekday (1=Sunday...7=Saturday) at hour:minute
    case weekly(weekday: Int, hour: Int, minute: Int)

    var isRepeating: Bool {
        switch self {
        case .daily, .weekly: return true
        case .immediate, .afterInterval: return false
        }
    }
}

// MARK: - Nudge Descriptor

/// A single notification descriptor produced by the nudge engine.
/// The NotificationManager translates this into a UNNotificationRequest.
struct AMORNudgeDescriptor: Identifiable {
    /// Unique identifier for deduplication and cancellation
    let id: String
    let category: AMORNudgeCategory
    let title: String
    let body: String
    let priority: AMORNudgePriority
    let trigger: AMORNudgeTrigger

    /// Sort key — lower priority rawValue = more urgent = sorted first
    var sortKey: Int { priority.rawValue }
}

// MARK: - Nudge Result

/// Result of a full nudge evaluation cycle.
struct AMORNudgeResult {
    let allNudges: [AMORNudgeDescriptor]
    let streakNudges: [AMORNudgeDescriptor]
    let cronNudges: [AMORNudgeDescriptor]
    let milestoneNudges: [AMORNudgeDescriptor]
    let scheduledNudges: [AMORNudgeDescriptor]

    var hasCriticalAlerts: Bool {
        allNudges.contains { $0.priority == .critical }
    }

    var summary: String {
        var bits: [String] = []
        if !streakNudges.isEmpty {
            bits.append("\(streakNudges.count) streak alert\(streakNudges.count == 1 ? "" : "s")")
        }
        if !cronNudges.isEmpty {
            bits.append("\(cronNudges.count) cron failure\(cronNudges.count == 1 ? "" : "s")")
        }
        if !milestoneNudges.isEmpty {
            bits.append("\(milestoneNudges.count) milestone\(milestoneNudges.count == 1 ? "" : "s")")
        }
        return bits.isEmpty ? "All clear" : bits.joined(separator: ", ")
    }
}

// MARK: - AMORNudgeEngine

/// Pure-function engine that analyzes data and produces notification descriptors.
enum AMORNudgeEngine {

    // MARK: - Full Evaluation

    /// Runs all nudge analyses and returns a complete result.
    static func evaluate(
        practices: [AMORPracticeSnapshot],
        cronJobs: [AMORCronJobSnapshot],
        sessions: [AMORSessionSnapshot],
        referenceDate: Date = .now
    ) -> AMORNudgeResult {
        let streakNudges = generateStreakNudges(practices: practices, referenceDate: referenceDate)
        let cronNudges = generateCronNudges(cronJobs: cronJobs)
        let milestoneNudges = generateMilestoneNudges(practices: practices)
        let scheduledNudges = generateScheduledNudges(referenceDate: referenceDate)
        let inactivityNudges = generateInactivityNudges(sessions: sessions, referenceDate: referenceDate)

        var all = streakNudges + cronNudges + milestoneNudges + scheduledNudges + inactivityNudges
        all.sort { $0.sortKey < $1.sortKey }

        return AMORNudgeResult(
            allNudges: all,
            streakNudges: streakNudges,
            cronNudges: cronNudges,
            milestoneNudges: milestoneNudges,
            scheduledNudges: scheduledNudges
        )
    }

    // MARK: - 1. Streak Risk Nudges

    /// Generates nudge descriptors for practices that are due today or at risk.
    static func generateStreakNudges(
        practices: [AMORPracticeSnapshot],
        referenceDate: Date = .now
    ) -> [AMORNudgeDescriptor] {
        var nudges: [AMORNudgeDescriptor] = []

        for practice in practices {
            let risk = AMORStreakIntelligence.assessRisk(practice: practice, referenceDate: referenceDate)

            switch risk {
            case .safe, .notStarted:
                continue  // No nudge needed

            case .dueToday:
                let streak = practice.currentStreak
                let title: String
                let body: String
                let priority: AMORNudgePriority

                if streak >= 7 {
                    title = "🔥 \(practice.practiceName) streak needs you"
                    body = "Day \(streak + 1) is waiting. Don't let \(streak) days unravel — even 5 minutes counts."
                    priority = .high
                } else if streak >= 3 {
                    title = "⏰ \(practice.practiceName) due today"
                    body = "Day \(streak + 1) — the streak is young. Complete it before the day slips away."
                    priority = .high
                } else {
                    title = "🌱 \(practice.practiceName) today"
                    body = "Showing up is the whole practice. Will today be day one?"
                    priority = .normal
                }

                nudges.append(AMORNudgeDescriptor(
                    id: "streak_\(practice.practiceName)_\(dateKey(referenceDate))",
                    category: .streakRisk,
                    title: title,
                    body: body,
                    priority: priority,
                    trigger: .immediate
                ))

            case .atRisk:
                nudges.append(AMORNudgeDescriptor(
                    id: "streak_atrisk_\(practice.practiceName)_\(dateKey(referenceDate))",
                    category: .streakRisk,
                    title: "⚠️ \(practice.practiceName) streak at risk!",
                    body: "Last done \(practice.currentStreak) days ago. Complete TODAY or the streak resets to zero.",
                    priority: .critical,
                    trigger: .immediate
                ))

            case .broken:
                // Only nudge about broken streaks if they were significant
                if practice.longestStreak >= 7 {
                    nudges.append(AMORNudgeDescriptor(
                        id: "streak_broken_\(practice.practiceName)_\(dateKey(referenceDate))",
                        category: .streakRisk,
                        title: "💔 \(practice.practiceName) streak broken",
                        body: "You hit \(practice.longestStreak) days before. You've proven you can do it. Begin again today.",
                        priority: .normal,
                        trigger: .immediate
                    ))
                }
            }
        }

        return nudges.sorted { $0.sortKey < $1.sortKey }
    }

    // MARK: - 2. Cron Failure Nudges

    /// Generates nudge descriptors for failing or critical cron jobs.
    static func generateCronNudges(cronJobs: [AMORCronJobSnapshot]) -> [AMORNudgeDescriptor] {
        var nudges: [AMORNudgeDescriptor] = []

        for job in cronJobs {
            guard job.isEnabled else { continue }

            switch job.healthStatus {
            case "critical":
                nudges.append(AMORNudgeDescriptor(
                    id: "cron_critical_\(job.jobName)",
                    category: .cronFailure,
                    title: "❌ \(job.jobName) CRITICAL",
                    body: "\(job.consecutiveFailures) consecutive failures. Last error: \(job.errorMessage ?? "unknown")",
                    priority: .critical,
                    trigger: .immediate
                ))

            case "warning":
                nudges.append(AMORNudgeDescriptor(
                    id: "cron_warning_\(job.jobName)",
                    category: .cronFailure,
                    title: "⚠️ \(job.jobName) warning",
                    body: "Recent failure detected. Status: \(job.lastStatus)",
                    priority: .high,
                    trigger: .immediate
                ))

            default:
                continue
            }
        }

        return nudges
    }

    // MARK: - 3. Milestone Nudges

    /// Generates celebration nudge descriptors for practices hitting milestones today.
    static func generateMilestoneNudges(practices: [AMORPracticeSnapshot]) -> [AMORNudgeDescriptor] {
        let milestones = AMORStreakIntelligence.detectMilestones(practices: practices)

        return milestones.map { milestoneText in
            AMORNudgeDescriptor(
                id: "milestone_\(milestoneText.hashValue)",
                category: .milestone,
                title: "🏆 Milestone Reached!",
                body: milestoneText,
                priority: .normal,
                trigger: .immediate
            )
        }
    }

    // MARK: - 4. Morning Briefing

    /// Generates the daily morning briefing nudge.
    /// Fires at the configured time (default 7:00 AM).
    static func generateMorningBriefingNudge(hour: Int = 7, minute: Int = 0) -> AMORNudgeDescriptor {
        AMORNudgeDescriptor(
            id: "scheduled_morning_briefing",
            category: .morningBriefing,
            title: "🧘 Good morning",
            body: "Your daily briefing is ready. Check AMOR for today's outlook, streak status, and system health.",
            priority: .normal,
            trigger: .daily(hour: hour, minute: minute)
        )
    }

    // MARK: - 5. Evening Review

    /// Generates the evening review nudge.
    /// Fires at the configured time (default 9:00 PM).
    static func generateEveningReviewNudge(hour: Int = 21, minute: Int = 0) -> AMORNudgeDescriptor {
        AMORNudgeDescriptor(
            id: "scheduled_evening_review",
            category: .eveningReview,
            title: "🌙 Time to reflect",
            body: "Log your sessions and reflect on the day. How did your practices hold up?",
            priority: .normal,
            trigger: .daily(hour: hour, minute: minute)
        )
    }

    // MARK: - 6. Weekly Review

    /// Generates the weekly review nudge.
    /// Fires on Sunday evenings (weekday 1) at 6:00 PM by default.
    static func generateWeeklyReviewNudge(weekday: Int = 1, hour: Int = 18, minute: Int = 0) -> AMORNudgeDescriptor {
        AMORNudgeDescriptor(
            id: "scheduled_weekly_review",
            category: .weeklyReview,
            title: "📊 Weekly Review Ready",
            body: "Your week-in-review has been auto-generated. Take a moment to see the patterns and arc of your week.",
            priority: .normal,
            trigger: .weekly(weekday: weekday, hour: hour, minute: minute)
        )
    }

    // MARK: - 7. Inactivity Detection

    /// Generates a gentle nudge if no sessions have been logged in 24+ hours.
    static func generateInactivityNudges(
        sessions: [AMORSessionSnapshot],
        referenceDate: Date = .now
    ) -> [AMORNudgeDescriptor] {
        guard let lastSession = sessions.sorted(by: { $0.date > $1.date }).first else {
            // No sessions ever logged
            return [AMORNudgeDescriptor(
                id: "inactivity_never_logged",
                category: .inactivity,
                title: "👋 Welcome to AMOR",
                body: "Log your first work session to start tracking your daily operating rhythm.",
                priority: .low,
                trigger: .afterInterval(3600) // 1 hour from now
            )]
        }

        let hoursSince = referenceDate.timeIntervalSince(lastSession.date) / 3600

        if hoursSince >= 48 {
            return [AMORNudgeDescriptor(
                id: "inactivity_48h_\(dateKey(referenceDate))",
                category: .inactivity,
                title: "🌬️ Been a while",
                body: "No sessions in \(Int(hoursSince / 24)) days. Log something — even a quick 15-minute session counts.",
                priority: .low,
                trigger: .immediate
            )]
        }

        return []
    }

    // MARK: - Scheduled Nudges (combined)

    /// Generates all time-based recurring nudges.
    static func generateScheduledNudges(referenceDate: Date = .now) -> [AMORNudgeDescriptor] {
        // Parse the configured briefing reminder time from settings.
        // v5.2.0: reads UserDefaults directly — the engine no longer
        // depends on the SwiftUI-welded AMORSettingsManager, so the
        // live-fire harness can compile it (CLT SDK, no app target).
        let timeString = UserDefaults.standard
            .string(forKey: "amor.settings.briefingReminderTime") ?? "07:00"
        let parts = timeString.components(separatedBy: ":")
        let morningHour = Int(parts.first ?? "7") ?? 7
        let morningMinute = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0

        return [
            generateMorningBriefingNudge(hour: morningHour, minute: morningMinute),
            generateEveningReviewNudge(),
            generateWeeklyReviewNudge()
        ]
    }

    // MARK: - Deduplication Key

    /// Produces a date key for deduplication (e.g., "2026_08_12")
    static func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy_MM_dd"
        return formatter.string(from: date)
    }

    // MARK: - Nudge Suppression

    /// Checks if a nudge category is enabled in settings.
    static func isCategoryEnabled(_ category: AMORNudgeCategory) -> Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: category.settingsKey) as? Bool ?? category.defaultEnabled
    }

    /// Checks if notifications are globally enabled.
    /// v5.2.0: reads UserDefaults directly (harness-compilable).
    static func isNotificationsEnabled() -> Bool {
        UserDefaults.standard.object(forKey: "amor.settings.notificationsEnabled") as? Bool ?? true
    }

    /// Filters nudges based on user settings.
    static func filterEnabled(_ nudges: [AMORNudgeDescriptor]) -> [AMORNudgeDescriptor] {
        guard isNotificationsEnabled() else { return [] }
        return nudges.filter { isCategoryEnabled($0.category) }
    }

    // MARK: - Daily Digest

    /// Generates a single combined digest notification for all immediate alerts.
    /// Used when multiple alerts fire at once — combine into one notification.
    static func generateDigest(from result: AMORNudgeResult) -> AMORNudgeDescriptor? {
        let immediate = result.allNudges.filter {
            $0.trigger == .immediate && $0.priority != .low
        }
        guard !immediate.isEmpty else { return nil }

        let hasCritical = immediate.contains { $0.priority == .critical }
        let title = hasCritical ? "🚨 AMOR Alerts" : "📋 AMOR Update"

        // Build a concise body from the alerts
        let lines = immediate.prefix(3).map { nudge -> String in
            "• \(nudge.title)"
        }
        var body = lines.joined(separator: "\n")
        if immediate.count > 3 {
            body += "\n+ \(immediate.count - 3) more"
        }

        return AMORNudgeDescriptor(
            id: "digest_\(dateKey(.now))",
            category: hasCritical ? .cronFailure : .streakRisk,
            title: title,
            body: body,
            priority: hasCritical ? .critical : .normal,
            trigger: .immediate
        )
    }
}
