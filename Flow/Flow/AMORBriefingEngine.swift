/**
 * 🌅 AMORBriefingEngine — The Daily Briefing Engine
 *
 * "The voice that greets you in the morning with purpose,
 * checks on you at midday with care, and sends you to rest
 * with reflection. Not a dashboard — a companion."
 *
 * v3.0.0 — Time-aware synthesis of all AMOR data into
 * proactive briefings that surface what matters WHEN it matters.
 *
 * Architecture: Pure Foundation enum with static functions.
 * Operates on SwiftData @Model arrays. No SwiftUI.
 * Fully type-checkable with swiftc -typecheck -sdk macosx.
 */

import Foundation

// MARK: - Time of Day

/// Determines which briefing phase to show based on current time.
enum BriefingPhase: String, CaseIterable {
    case morning    // 5:00 AM – 11:59 AM
    case midday     // 12:00 PM – 4:59 PM
    case evening    // 5:00 PM – 9:59 PM
    case night      // 10:00 PM – 4:59 AM

    static func current(date: Date = .now) -> BriefingPhase {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12:    return .morning
        case 12..<17:   return .midday
        case 17..<22:   return .evening
        default:        return .night
        }
    }

    var greeting: String {
        switch self {
        case .morning:  return "Good morning"
        case .midday:   return "Good afternoon"
        case .evening:  return "Good evening"
        case .night:    return "Still here"
        }
    }

    var icon: String {
        switch self {
        case .morning:  return "sun.max.fill"
        case .midday:   return "sun.haze.fill"
        case .evening:  return "moon.stars.fill"
        case .night:    return "moon.zzz.fill"
        }
    }

    var accentColor: String {
        switch self {
        case .morning:  return "dawnOrange"
        case .midday:   return "sageGreen"
        case .evening:  return "twilightPurple"
        case .night:    return "deepIndigo"
        }
    }
}

// MARK: - Briefing Data Structures

/// A complete daily briefing — the synthesized output.
struct DailyBriefing: Identifiable {
    let id = UUID()
    let phase: BriefingPhase
    let date: Date
    let headline: String           // One-line summary: "3 sessions logged, Gita streak at 12 days"
    let subheadline: String        // Secondary context
    let greeting: String           // Personalized greeting
    let sections: [BriefingSection]
    let priorityAlerts: [BriefingAlert]
    let suggestedActions: [BriefingAction]
    let rhythmScore: Int?          // 0-100 if available
    let rhythmGrade: String?       // Emoji grade
    let reflectivePrompt: String   // A question to sit with
}

/// A themed section within the briefing.
struct BriefingSection: Identifiable {
    let id = UUID()
    let title: String
    let icon: String               // SF Symbol
    let items: [String]            // Bullet points
    let tone: SectionTone

    enum SectionTone {
        case positive     // green
        case neutral      // default
        case attention    // orange
        case warning      // red
    }
}

/// An alert that needs immediate attention.
struct BriefingAlert: Identifiable {
    let id = UUID()
    let severity: AlertSeverity
    let title: String
    let detail: String
    let icon: String

    enum AlertSeverity {
        case info       // blue
        case warning    // orange
        case critical   // red
        case celebration // green
    }
}

/// A suggested action the user can take.
struct BriefingAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let context: String             // Why this action matters now
}

// MARK: - Yesterday Recap

/// Summary of the previous day's activity.
struct YesterdayRecap {
    let sessionsCount: Int
    let focusMinutes: Int
    let practicesCompleted: [String]
    let practicesMissed: [String]
    let topTools: [String]
    let moodSummary: String?
    let hadReflection: Bool
    let longestStreak: Int          // Best streak going into today
    let streaksBroken: [String]     // Practices whose streak broke overnight

    var isEmpty: Bool {
        sessionsCount == 0 && practicesCompleted.isEmpty && focusMinutes == 0
    }

    var headline: String {
        var parts: [String] = []
        if sessionsCount > 0 {
            parts.append("\(sessionsCount) session\(sessionsCount == 1 ? "" : "s")")
        }
        if focusMinutes > 0 {
            let hrs = focusMinutes / 60
            let mins = focusMinutes % 60
            if hrs > 0 {
                parts.append("\(hrs)h\(mins > 0 ? " \(mins)m" : "") focused")
            } else {
                parts.append("\(mins)m focused")
            }
        }
        if !practicesCompleted.isEmpty {
            parts.append("\(practicesCompleted.count) practice\(practicesCompleted.count == 1 ? "" : "s")")
        }
        if parts.isEmpty { return "A quiet day" }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Today Snapshot

/// Current state of today's progress.
struct TodaySnapshot {
    let sessionsCount: Int
    let focusMinutes: Int
    let practicesCompleted: [String]
    let practicesRemaining: [String]
    let tasksCompleted: Int
    let toolsUsedToday: [String]
    let cronIssues: Int
    let cronHealthy: Int

    var completionRate: Double {
        let total = practicesCompleted.count + practicesRemaining.count
        guard total > 0 else { return 1.0 }
        return Double(practicesCompleted.count) / Double(total)
    }

    var allPracticesDone: Bool {
        practicesRemaining.isEmpty && !practicesCompleted.isEmpty
    }
}

// MARK: - Tomorrow Preview

/// Preview of what's coming tomorrow.
struct TomorrowPreview {
    let practicesDue: [String]
    let cronJobsScheduled: Int
    let longestActiveStreak: Int
    let suggestedFocus: String      // What to focus on based on patterns

    var isEmpty: Bool {
        practicesDue.isEmpty && cronJobsScheduled == 0
    }
}

// MARK: - Engine

/// The core briefing engine — pure functions, no state.
enum AMORBriefingEngine {

    // MARK: Phase Detection

    /// Determines the current briefing phase based on time of day.
    static func currentPhase(date: Date = .now) -> BriefingPhase {
        BriefingPhase.current(date: date)
    }

    // MARK: Yesterday Recap

    /// Builds a recap of yesterday's activity from session and practice data.
    static func buildYesterdayRecap(
        sessions: [DailySession],
        practices: [PracticeStreak],
        reflections: [ReflectionEntry],
        date: Date = .now
    ) -> YesterdayRecap {
        let cal = Calendar.current
        let yesterdayStart = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: date))!
        let todayStart = cal.startOfDay(for: date)
        let dateRange = yesterdayStart..<todayStart

        let yesterdaySessions = sessions.filter { dateRange.contains($0.date) }
        let focusMinutes = yesterdaySessions.reduce(0) { $0 + $1.durationMinutes }
        let tasksCompleted = yesterdaySessions.reduce(0) { $0 + $1.completedTasks }

        // Parse tools from yesterday
        let ws = CharacterSet.whitespaces
        let toolsRaw = yesterdaySessions.flatMap { $0.toolsUsed.components(separatedBy: ",").map { $0.trimmingCharacters(in: ws) } }
        let toolCounts: [String: Int] = Dictionary(toolsRaw.filter { !$0.isEmpty }.map { ($0, 1) }, uniquingKeysWith: +)
        let topTools = toolCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }

        // Determine mood from yesterday
        let moods = yesterdaySessions.map { $0.mood }.filter { $0 != "neutral" && !$0.isEmpty }
        let moodCounts: [String: Int] = moods.isEmpty ? [:] : Dictionary(moods.map { ($0, 1) }, uniquingKeysWith: +)
        let moodSummary: String? = moodCounts.max(by: { $0.value < $1.value })?.key

        // Practices completed yesterday
        let completedYesterday = practices.filter { p in
            guard let last = p.lastCompletedDate else { return false }
            return cal.isDate(last, inSameDayAs: yesterdayStart)
        }.map { $0.practiceName }

        // Practices that were due yesterday but not done (streak may have broken)
        let missedYesterday = practices.filter { p in
            guard let last = p.lastCompletedDate else { return p.goal.lowercased().contains("daily") }
            // If last completion was before yesterday and it's a daily practice
            return last < yesterdayStart && p.goal.lowercased().contains("daily")
        }.map { $0.practiceName }

        // Check for broken streaks
        let brokenStreaks = practices.filter { p in
            guard let last = p.lastCompletedDate else { return false }
            // Was active (completed within 2 days before yesterday) but not yesterday
            let twoDaysBefore = cal.date(byAdding: .day, value: -2, to: yesterdayStart)!
            return last >= twoDaysBefore && last < yesterdayStart && p.goal.lowercased().contains("daily")
        }.map { $0.practiceName }

        // Check reflections from yesterday
        let hadReflection = reflections.contains { r in
            cal.isDate(r.date, inSameDayAs: yesterdayStart)
        }

        // Longest streak currently active
        let longestStreak = practices.map { $0.currentStreak }.max() ?? 0

        return YesterdayRecap(
            sessionsCount: yesterdaySessions.count,
            focusMinutes: focusMinutes,
            practicesCompleted: completedYesterday,
            practicesMissed: missedYesterday,
            topTools: topTools,
            moodSummary: moodSummary,
            hadReflection: hadReflection,
            longestStreak: longestStreak,
            streaksBroken: brokenStreaks
        )
    }

    // MARK: Today Snapshot

    /// Builds a snapshot of today's current progress.
    static func buildTodaySnapshot(
        sessions: [DailySession],
        practices: [PracticeStreak],
        cronJobs: [CronJobHealth],
        date: Date = .now
    ) -> TodaySnapshot {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: date)

        let todaySessions = sessions.filter { $0.date >= todayStart }
        let focusMinutes = todaySessions.reduce(0) { $0 + $1.durationMinutes }
        let tasksCompleted = todaySessions.reduce(0) { $0 + $1.completedTasks }

        let ws = CharacterSet.whitespaces
        let toolsRaw = todaySessions.flatMap { $0.toolsUsed.components(separatedBy: ",").map { $0.trimmingCharacters(in: ws) } }
        let toolsUsed = Array(Set(toolsRaw.filter { !$0.isEmpty })).sorted()

        let completedToday = practices.filter { p in
            guard let last = p.lastCompletedDate else { return false }
            return cal.isDateInToday(last)
        }.map { $0.practiceName }

        let remaining = practices.filter { $0.isDueToday && !completedToday.contains($0.practiceName) }
            .map { $0.practiceName }

        let healthy = cronJobs.filter { $0.healthStatus == "healthy" }.count
        let issues = cronJobs.filter { $0.healthStatus != "healthy" && $0.isEnabled }.count

        return TodaySnapshot(
            sessionsCount: todaySessions.count,
            focusMinutes: focusMinutes,
            practicesCompleted: completedToday,
            practicesRemaining: remaining,
            tasksCompleted: tasksCompleted,
            toolsUsedToday: toolsUsed,
            cronIssues: issues,
            cronHealthy: healthy
        )
    }

    // MARK: Tomorrow Preview

    /// Builds a preview of what's coming tomorrow.
    static func buildTomorrowPreview(
        practices: [PracticeStreak],
        cronJobs: [CronJobHealth],
        date: Date = .now
    ) -> TomorrowPreview {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: date)!

        // Practices that will be due tomorrow
        let dueTomorrow = practices.filter { p in
            guard let last = p.lastCompletedDate else { return true }
            // Due tomorrow if last completed today or earlier
            return !cal.isDate(last, inSameDayAs: tomorrow)
        }.map { $0.practiceName }

        let scheduledCrons = cronJobs.filter { $0.isEnabled }.count
        let longestStreak = practices.map { $0.currentStreak }.max() ?? 0

        // Suggest focus based on what's been neglected
        let neglectedPractices = practices.filter { p in
            guard let last = p.lastCompletedDate else { return false }
            let daysSince = cal.dateComponents([.day], from: last, to: date).day ?? 0
            return daysSince >= 2
        }.map { $0.practiceName }

        let suggestedFocus: String
        if !neglectedPractices.isEmpty {
            suggestedFocus = "Reconnect with: \(neglectedPractices.joined(separator: ", "))"
        } else if longestStreak >= 7 {
            suggestedFocus = "Keep the momentum — \(longestStreak)-day streak alive"
        } else {
            suggestedFocus = "Build consistency — small steps, daily"
        }

        return TomorrowPreview(
            practicesDue: dueTomorrow,
            cronJobsScheduled: scheduledCrons,
            longestActiveStreak: longestStreak,
            suggestedFocus: suggestedFocus
        )
    }

    // MARK: Full Briefing Generation

    /// Generates the complete daily briefing for the current time of day.
    static func generateBriefing(
        sessions: [DailySession],
        practices: [PracticeStreak],
        cronJobs: [CronJobHealth],
        reflections: [ReflectionEntry],
        rhythmScore: Int? = nil,
        rhythmGrade: String? = nil,
        date: Date = .now
    ) -> DailyBriefing {
        let phase = currentPhase(date: date)
        let yesterday = buildYesterdayRecap(sessions: sessions, practices: practices, reflections: reflections, date: date)
        let today = buildTodaySnapshot(sessions: sessions, practices: practices, cronJobs: cronJobs, date: date)
        let tomorrow = buildTomorrowPreview(practices: practices, cronJobs: cronJobs, date: date)

        let greeting = personalizedGreeting(phase: phase, practices: practices, date: date)
        let headline = buildHeadline(phase: phase, today: today, yesterday: yesterday)
        let subheadline = buildSubheadline(phase: phase, today: today, yesterday: yesterday, tomorrow: tomorrow)
        let sections = buildSections(phase: phase, yesterday: yesterday, today: today, tomorrow: tomorrow)
        let alerts = buildAlerts(phase: phase, today: today, yesterday: yesterday, cronJobs: cronJobs)
        let actions = buildActions(phase: phase, today: today, practices: practices)
        let prompt = reflectivePrompt(phase: phase, yesterday: yesterday, today: today)

        return DailyBriefing(
            phase: phase,
            date: date,
            headline: headline,
            subheadline: subheadline,
            greeting: greeting,
            sections: sections,
            priorityAlerts: alerts,
            suggestedActions: actions,
            rhythmScore: rhythmScore,
            rhythmGrade: rhythmGrade,
            reflectivePrompt: prompt
        )
    }

    // MARK: Private Helpers

    private static func personalizedGreeting(phase: BriefingPhase, practices: [PracticeStreak], date: Date) -> String {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)

        let longestStreak = practices.map { $0.currentStreak }.max() ?? 0

        switch phase {
        case .morning:
            if hour < 7 {
                return "Early start. The quiet hours are yours."
            }
            if longestStreak >= 14 {
                return "\(phase.greeting). \(longestStreak)-day strong."
            }
            if longestStreak >= 7 {
                return "\(phase.greeting). Week-long streak burning."
            }
            return "\(phase.greeting). A new day to begin."
        case .midday:
            let completed = practices.filter { p in
                guard let last = p.lastCompletedDate else { return false }
                return cal.isDateInToday(last)
            }.count
            if completed > 0 {
                return "\(completed) practice\(completed == 1 ? "" : "s") done. Keep going."
            }
            return "Midday check-in. How's the rhythm?"
        case .evening:
            let todaySessions = practices.filter { $0.isActive }.count
            if todaySessions > 0 {
                return "Evening reflection. \(todaySessions) streaks alive."
            }
            return "Evening. Time to reflect."
        case .night:
            return "Late hours. Rest is a practice too."
        }
    }

    private static func buildHeadline(phase: BriefingPhase, today: TodaySnapshot, yesterday: YesterdayRecap) -> String {
        switch phase {
        case .morning:
            // Lead with yesterday's accomplishment
            if !yesterday.isEmpty {
                return "Yesterday: \(yesterday.headline)"
            }
            return "Yesterday was a rest day. Today is fresh."
        case .midday:
            if today.sessionsCount > 0 {
                let hrs = today.focusMinutes / 60
                let mins = today.focusMinutes % 60
                if hrs > 0 {
                    return "\(today.sessionsCount) sessions · \(hrs)h\(mins > 0 ? " \(mins)m" : "") so far"
                }
                return "\(today.sessionsCount) sessions · \(mins)m focused"
            }
            return "No sessions logged yet today."
        case .evening:
            if today.allPracticesDone {
                return "All practices complete. Well done."
            }
            let remaining = today.practicesRemaining.count
            if remaining > 0 {
                return "\(remaining) practice\(remaining == 1 ? "" : "s") remaining tonight"
            }
            return "Day winding down."
        case .night:
            return "The day is done. Rest now."
        }
    }

    private static func buildSubheadline(phase: BriefingPhase, today: TodaySnapshot, yesterday: YesterdayRecap, tomorrow: TomorrowPreview) -> String {
        switch phase {
        case .morning:
            if !yesterday.streaksBroken.isEmpty {
                return "⚠️ \(yesterday.streaksBroken.joined(separator: ", ")) streak broke overnight."
            }
            if yesterday.longestStreak >= 7 {
                return "Longest streak: \(yesterday.longestStreak) days. Don't break the chain."
            }
            return "\(today.practicesRemaining.count) practices due today."
        case .midday:
            if today.cronIssues > 0 {
                return "⚠️ \(today.cronIssues) system\(today.cronIssues == 1 ? "" : "s") need attention."
            }
            if today.allPracticesDone {
                return "All practices done. Focus time: \(today.focusMinutes)m"
            }
            return "\(today.practicesCompleted.count)/\(today.practicesCompleted.count + today.practicesRemaining.count) practices done."
        case .evening:
            if today.tasksCompleted > 0 {
                return "\(today.tasksCompleted) task\(today.tasksCompleted == 1 ? "" : "s") completed today."
            }
            if today.focusMinutes > 0 {
                return "\(today.focusMinutes / 60)h\(today.focusMinutes % 60 > 0 ? " \(today.focusMinutes % 60)m" : "") of focused work."
            }
            return tomorrow.isEmpty ? "A quiet day." : "Tomorrow: \(tomorrow.practicesDue.count) practices due."
        case .night:
            return "Tomorrow awaits with fresh intention."
        }
    }

    private static func buildSections(phase: BriefingPhase, yesterday: YesterdayRecap, today: TodaySnapshot, tomorrow: TomorrowPreview) -> [BriefingSection] {
        var sections: [BriefingSection] = []

        switch phase {
        case .morning:
            // Yesterday recap section
            if !yesterday.isEmpty {
                var items: [String] = []
                items.append(yesterday.headline)
                if !yesterday.practicesCompleted.isEmpty {
                    items.append("✅ \(yesterday.practicesCompleted.joined(separator: ", "))")
                }
                if !yesterday.practicesMissed.isEmpty {
                    items.append("⏸ \(yesterday.practicesMissed.joined(separator: ", ")) — not completed")
                }
                if !yesterday.topTools.isEmpty {
                    items.append("🔧 Tools: \(yesterday.topTools.joined(separator: ", "))")
                }
                if let mood = yesterday.moodSummary {
                    items.append(" Mood: \(mood)")
                }
                sections.append(BriefingSection(title: "Yesterday", icon: "sunrise.fill", items: items, tone: .neutral))
            }

            // Today's priorities
            if !today.practicesRemaining.isEmpty {
                sections.append(BriefingSection(
                    title: "Today's Priorities",
                    icon: "list.bullet.clipboard.fill",
                    items: today.practicesRemaining.map { "○ \($0)" },
                    tone: .attention
                ))
            }

            // System alerts
            if today.cronIssues > 0 {
                sections.append(BriefingSection(
                    title: "System Health",
                    icon: "exclamationmark.shield.fill",
                    items: ["\(today.cronIssues) system\(today.cronIssues == 1 ? "" : "s") need\(today.cronIssues == 1 ? "s" : "") attention", "\(today.cronHealthy) running healthy"],
                    tone: .warning
                ))
            }

        case .midday:
            // Progress so far
            var progressItems: [String] = []
            if today.sessionsCount > 0 {
                progressItems.append("\(today.sessionsCount) session\(today.sessionsCount == 1 ? "" : "s") logged")
            }
            if today.focusMinutes > 0 {
                progressItems.append("\(today.focusMinutes / 60)h\(today.focusMinutes % 60 > 0 ? " \(today.focusMinutes % 60)m" : "") focused")
            }
            if !today.practicesCompleted.isEmpty {
                progressItems.append("✅ \(today.practicesCompleted.joined(separator: ", "))")
            }
            if !today.toolsUsedToday.isEmpty {
                progressItems.append("🔧 \(today.toolsUsedToday.prefix(3).joined(separator: ", "))")
            }
            if progressItems.isEmpty { progressItems = ["No sessions logged yet."] }
            sections.append(BriefingSection(title: "Today's Progress", icon: "chart.bar.fill", items: progressItems, tone: .positive))

            // What's left
            if !today.practicesRemaining.isEmpty {
                sections.append(BriefingSection(
                    title: "Still To Do",
                    icon: "circle.dashed",
                    items: today.practicesRemaining.map { "○ \($0)" },
                    tone: .neutral
                ))
            }

        case .evening:
            // Accomplishments
            var accompItems: [String] = []
            if today.sessionsCount > 0 {
                accompItems.append("\(today.sessionsCount) session\(today.sessionsCount == 1 ? "" : "s") · \(today.focusMinutes)m focused")
            }
            if !today.practicesCompleted.isEmpty {
                accompItems.append("✅ \(today.practicesCompleted.joined(separator: ", "))")
            }
            if today.tasksCompleted > 0 {
                accompItems.append("\(today.tasksCompleted) task\(today.tasksCompleted == 1 ? "" : "s") completed")
            }
            if !today.practicesRemaining.isEmpty {
                accompItems.append("⏸ \(today.practicesRemaining.joined(separator: ", ")) — still open")
            }
            if accompItems.isEmpty { accompItems = ["A day of rest."] }
            sections.append(BriefingSection(title: "Today's Accomplishments", icon: "checkmark.seal.fill", items: accompItems, tone: accompItems.count > 1 ? .positive : .neutral))

            // Tomorrow preview
            if !tomorrow.isEmpty {
                var tomorrowItems: [String] = []
                if !tomorrow.practicesDue.isEmpty {
                    tomorrowItems.append("\(tomorrow.practicesDue.count) practice\(tomorrow.practicesDue.count == 1 ? "" : "s") due")
                }
                tomorrowItems.append("Focus: \(tomorrow.suggestedFocus)")
                sections.append(BriefingSection(title: "Tomorrow", icon: "sun.haze.fill", items: tomorrowItems, tone: .neutral))
            }

        case .night:
            sections.append(BriefingSection(
                title: "Rest",
                icon: "moon.zzz.fill",
                items: ["The systems watch while you sleep.", "\(today.cronHealthy) jobs running clean."],
                tone: .neutral
            ))
        }

        return sections
    }

    private static func buildAlerts(phase: BriefingPhase, today: TodaySnapshot, yesterday: YesterdayRecap, cronJobs: [CronJobHealth]) -> [BriefingAlert] {
        var alerts: [BriefingAlert] = []

        // Broken streaks
        for broken in yesterday.streaksBroken {
            alerts.append(BriefingAlert(
                severity: .warning,
                title: "\(broken) streak broke",
                detail: "Last completed more than a day ago. Restart today.",
                icon: "flame.slash.fill"
            ))
        }

        // Critical cron failures
        let critical = cronJobs.filter { $0.consecutiveFailures >= 3 && $0.isEnabled }
        for job in critical {
            alerts.append(BriefingAlert(
                severity: .critical,
                title: "\(job.jobName) is failing",
                detail: "\(job.consecutiveFailures) consecutive failures. Last error: \(job.errorMessage ?? "unknown")",
                icon: "exclamationmark.octagon.fill"
            ))
        }

        // Morning celebration for long streaks
        if phase == .morning {
            if yesterday.longestStreak >= 30 {
                alerts.append(BriefingAlert(
                    severity: .celebration,
                    title: "🏆 \(yesterday.longestStreak)-day streak!",
                    detail: "Incredible consistency. This is who you are now.",
                    icon: "trophy.fill"
                ))
            } else if yesterday.longestStreak >= 14 {
                alerts.append(BriefingAlert(
                    severity: .celebration,
                    title: "🔥 \(yesterday.longestStreak)-day streak",
                    detail: "Two weeks strong. Keep the fire burning.",
                    icon: "flame.fill"
                ))
            }
        }

        // Evening reflection reminder
        if phase == .evening && !yesterday.hadReflection && today.practicesCompleted.count > 0 {
            alerts.append(BriefingAlert(
                severity: .info,
                title: "Take a moment to reflect",
                detail: "A few words about today will sharpen tomorrow.",
                icon: "pencil.and.scribble"
            ))
        }

        // All practices done celebration
        if today.allPracticesDone && phase != .night {
            alerts.append(BriefingAlert(
                severity: .celebration,
                title: "✨ All practices complete",
                detail: "Every intention honored today.",
                icon: "sparkles"
            ))
        }

        return alerts
    }

    private static func buildActions(phase: BriefingPhase, today: TodaySnapshot, practices: [PracticeStreak]) -> [BriefingAction] {
        var actions: [BriefingAction] = []

        switch phase {
        case .morning:
            // Suggest completing first practice
            if !today.practicesRemaining.isEmpty {
                let first = today.practicesRemaining[0]
                actions.append(BriefingAction(
                    title: "Complete \(first)",
                    icon: "checkmark.circle.fill",
                    context: "Start the day with intention"
                ))
            }
            if today.sessionsCount == 0 {
                actions.append(BriefingAction(
                    title: "Log first session",
                    icon: "plus.circle.fill",
                    context: "Capture the morning's work"
                ))
            }

        case .midday:
            if !today.practicesRemaining.isEmpty {
                actions.append(BriefingAction(
                    title: "Midday practice check",
                    icon: "leaf.fill",
                    context: "\(today.practicesRemaining.count) remaining today"
                ))
            }
            if today.cronIssues > 0 {
                actions.append(BriefingAction(
                    title: "Review system alerts",
                    icon: "gear.badge.questionmark",
                    context: "\(today.cronIssues) system\(today.cronIssues == 1 ? "" : "s") need attention"
                ))
            }

        case .evening:
            if !today.practicesRemaining.isEmpty {
                actions.append(BriefingAction(
                    title: "Finish remaining practices",
                    icon: "moon.fill",
                    context: "\(today.practicesRemaining.count) left before rest"
                ))
            }
            actions.append(BriefingAction(
                title: "Evening reflection",
                icon: "pencil.and.scribble",
                context: "Close the day with awareness"
            ))

        case .night:
            break
        }

        return actions
    }

    private static func reflectivePrompt(phase: BriefingPhase, yesterday: YesterdayRecap, today: TodaySnapshot) -> String {
        switch phase {
        case .morning:
            if yesterday.isEmpty {
                return "What one thing would make today worth living?"
            }
            if !yesterday.streaksBroken.isEmpty {
                return "A streak broke. What pulls you back to the practice?"
            }
            let prompts = [
                "What are you avoiding that matters?",
                "If today is a chapter, what's the theme?",
                "What would the person you're becoming do first?",
                "Where did yesterday's energy come from?",
                "What deserves more attention than you've been giving it?"
            ]
            let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
            return prompts[dayOfYear % prompts.count]

        case .midday:
            let prompts = [
                "Is your energy serving your intention?",
                "What's the most important thing right now?",
                "Are you reacting or creating?",
                "What would make the rest of today matter?"
            ]
            let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
            return prompts[(dayOfYear + 1) % prompts.count]

        case .evening:
            if today.allPracticesDone {
                return "What did you learn about yourself today?"
            }
            if !today.practicesRemaining.isEmpty {
                return "What got in the way of what matters?"
            }
            let prompts = [
                "What surprised you today?",
                "Where did you find flow?",
                "What will you remember from today in a year?",
                "What do you want to leave behind?"
            ]
            let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
            return prompts[(dayOfYear + 2) % prompts.count]

        case .night:
            return "Rest is not the opposite of work. It's the soil it grows from."
        }
    }
}
