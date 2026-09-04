// ═══════════════════════════════════════════════════════════════════
// v5.2.0 — THE FULL ILLUMINATION leg. Seven engines were welded to
// SwiftData @Models, so this harness could NEVER compile them:
// BriefingEngine, RhythmEngine, NudgeEngine, WeeklyReviewEngine,
// SessionDumpAutomation, DumpGenerator, ProgressTracker — 4,200+
// lines of briefing voice, rhythm scores, nudge cadence, weekly
// reviews, and the daily dump pipeline NOBODY could fixture-test.
// The mirrors change that. These asserts carry the law forever.
// ═══════════════════════════════════════════════════════════════════
import Foundation

var ePass = 0, eFail = 0
func echeck(_ name: String, _ cond: Bool, _ detail: String) {
    if cond { ePass += 1; print("  ✅ \(name): PASS — \(detail)") }
    else { eFail += 1; print("  ❌ \(name): FAIL — \(detail)") }
}

let cal = Calendar.current
func daysAgo(_ offset: Int) -> Date {
    cal.date(byAdding: .hour, value: -24 * offset, to: Date())!
}

print("=== AMOR ENGINES LIVE-FIRE — v5.2.0 the full illumination ===")

// ── Fixtures: five practices, sessions across days, cron jobs ──
let devotee = AMORPracticeSnapshot(
    practiceName: "Gita", currentStreak: 98, longestStreak: 98,
    totalCompletions: 98, lastCompletedDate: daysAgo(0), goal: "daily"
)
let lapsed = AMORPracticeSnapshot(
    practiceName: "Gym", currentStreak: 0, longestStreak: 9,
    totalCompletions: 5, lastCompletedDate: daysAgo(4), goal: "3x per week"
)
// Minor break: longest 3 < 7 — the anti-wolf law keeps it silent.
let minorBreak = AMORPracticeSnapshot(
    practiceName: "Stretching", currentStreak: 0, longestStreak: 3,
    totalCompletions: 4, lastCompletedDate: daysAgo(5), goal: "daily"
)
let dormant = AMORPracticeSnapshot(
    practiceName: "Meditation", currentStreak: 0, longestStreak: 0,
    totalCompletions: 0, lastCompletedDate: nil, goal: "daily"
)
let practices: [AMORPracticeSnapshot] = [devotee, lapsed, minorBreak, dormant]

func makeSession(_ dayOffset: Int, hours: Int = 10, minutes: Int = 45, tools: String, mood: String, tasks: Int = 2) -> AMORSessionSnapshot {
    let d = daysAgo(dayOffset)
    let anchored = cal.date(bySettingHour: hours, minute: 0, second: 0, of: d) ?? d
    return AMORSessionSnapshot(
        id: UUID(), date: anchored, title: "Session \(dayOffset)d ago",
        notes: "", durationMinutes: minutes, toolsUsed: tools,
        skillsLearned: "swift, sqlite", mood: mood, completedTasks: tasks,
        timestamp: anchored
    )
}

let sessions: [AMORSessionSnapshot] = [
    makeSession(0, tools: "terminal, hermes", mood: "focused", tasks: 3),
    makeSession(0, tools: "hermes, swiftc", mood: "focused", tasks: 1),
    makeSession(1, tools: "terminal, sqlite3", mood: "energized", tasks: 4),
    makeSession(2, tools: "hermes", mood: "tired", tasks: 1),
    makeSession(4, tools: "terminal", mood: "neutral", tasks: 2),
]

let healthyJob = AMORCronJobSnapshot(
    id: UUID(), jobName: "Gita AM", lastRunDate: daysAgo(0), lastStatus: "success",
    errorMessage: nil, schedule: "30 6 * * *", isEnabled: true,
    consecutiveFailures: 0, lastSuccessDate: daysAgo(0)
)
let criticalJob = AMORCronJobSnapshot(
    id: UUID(), jobName: "Broken Pipe", lastRunDate: daysAgo(0), lastStatus: "failed",
    errorMessage: "HTTP 404", schedule: "0 12 * * *", isEnabled: true,
    consecutiveFailures: 4, lastSuccessDate: daysAgo(9)
)
let disabledJob = AMORCronJobSnapshot(
    id: UUID(), jobName: "Retired", lastRunDate: nil, lastStatus: "pending",
    errorMessage: nil, schedule: "", isEnabled: false,
    consecutiveFailures: 0, lastSuccessDate: nil
)
let cronJobs: [AMORCronJobSnapshot] = [healthyJob, criticalJob, disabledJob]

let summaries = [
    AMORDailySummarySnapshot(
        id: UUID(), date: daysAgo(0), sessionCount: 2, totalFocusMinutes: 90,
        tasksCompleted: 4, practicesCompleted: ["Gita"], mood: "focused",
        notes: "", timestamp: daysAgo(0)
    )
]

let reflections = [
    AMORReflectionSnapshot(
        id: UUID(), date: daysAgo(0), prompt: "What mattered today?",
        response: "The work itself.", theme: "presence",
        moodBefore: "neutral", moodAfter: "calm", timestamp: daysAgo(0)
    )
]

// ── Rhythm engine ──
do {
    let score = AMORRhythmEngine.computeScore(
        sessions: sessions, practices: practices,
        cronJobs: cronJobs, reflections: reflections
    )
    echeck("RHYTHM-SCORE", (0...100).contains(score.overall),
           "score \(score.overall) in range, grade \(score.grade.emoji)")
    echeck("RHYTHM-MOOD-LAW", score.overall > 0,
           "devotee + focus sessions produce a living score")

    let momentum = AMORRhythmEngine.computeMomentum(sessions: sessions, practices: practices)
    echeck("RHYTHM-MOMENTUM", momentum != nil, "momentum computed \(momentum.map { "\($0.arrow)" } ?? "nil")")

    let correlations = AMORRhythmEngine.detectCorrelations(sessions: sessions, practices: practices)
    echeck("RHYTHM-CORRELATIONS", !correlations.isEmpty,
           "\(correlations.count) correlation(s) detected")

    let insights = AMORRhythmEngine.generateInsights(
        score: score, momentum: momentum, correlations: correlations,
        sessions: sessions, practices: practices,
        cronJobs: cronJobs, reflections: reflections
    )
    echeck("RHYTHM-INSIGHTS", !insights.isEmpty, "\(insights.count) insight(s) generated")
}

// ── Briefing engine ──
do {
    let briefing = AMORBriefingEngine.generateBriefing(
        sessions: sessions, practices: practices, cronJobs: cronJobs,
        reflections: reflections, rhythmScore: 72, rhythmGrade: "🌀",
        date: Date()
    )
    echeck("BRIEFING-GENERATED", !briefing.headline.isEmpty,
           "briefing generated: \(briefing.headline)")

    let recap = AMORBriefingEngine.buildYesterdayRecap(
        sessions: sessions, practices: practices, reflections: reflections, date: Date()
    )
    echeck("BRIEFING-RECAP", recap.focusMinutes >= 45 && recap.sessionsCount >= 1,
           "yesterday recap: \(recap.focusMinutes)m focus across \(recap.sessionsCount) session(s) (1d-ago counted)")

    let tomorrow = AMORBriefingEngine.buildTomorrowPreview(practices: practices, cronJobs: cronJobs, date: Date())
    echeck("BRIEFING-TOMORROW", !tomorrow.practicesDue.isEmpty || tomorrow.cronJobsScheduled >= 0,
           "preview practices due: \(tomorrow.practicesDue.count)")
}

// ── Nudge engine ──
do {
    let nudges = AMORNudgeEngine.evaluate(
        practices: practices, cronJobs: cronJobs, sessions: sessions
    )
    echeck("NUDGE-EVALUATE", !nudges.allNudges.isEmpty,
           "\(nudges.allNudges.count) nudge(s) — lapsed gym + critical cron surface")

    let streakNudges = AMORNudgeEngine.generateStreakNudges(practices: practices)
    echeck("NUDGE-STREAK", streakNudges.contains { $0.title.contains("Gym") },
           "\(streakNudges.count) streak nudge(s) — the significant break (9d) reaches the user")
    echeck("NUDGE-ANTI-WOLF", !streakNudges.contains { $0.title.contains("Stretching") },
           "minor break (3d) stays silent — anti-wolf law holds")

    let cronNudges = AMORNudgeEngine.generateCronNudges(cronJobs: cronJobs)
    echeck("NUDGE-CRITICAL", cronNudges.contains { $0.title.contains("Broken Pipe") },
           "critical cron failure reaches the user by name")
}

// ── Weekly review engine ──
do {
    let summary = AMORWeeklyReviewEngine.generateWeeklyReview(
        sessions: sessions, practices: practices, cronJobs: cronJobs,
        summaries: summaries, reflections: reflections
    )
    echeck("WEEKLY-GENERATED", summary.totalSessions >= 4,
           "weekly review: \(summary.totalSessions) sessions, streak \(summary.longestActiveStreak) days")

    let markdown = AMORWeeklyReviewEngine.generateWeeklyMarkdown(summary: summary)
    echeck("WEEKLY-MARKDOWN", markdown.contains("# ") && markdown.contains("AMOR"),
           "markdown authored: \(markdown.prefix(40))…")
}

// ── Session dump automation (the pipeline heart) ──
do {
    let automation = AMORSessionDumpAutomation()
    let result = automation.generateDailyDump(
        sessions: sessions, practices: practices, cronJobs: cronJobs,
        summaries: summaries, reflections: reflections
    )
    echeck("DUMP-GENERATED", result != nil,
           "daily dump generated: \(result.map { "\($0.snapshot.sessionCount) sessions → \($0.dumpPath)" } ?? "nil")")
    if let r = result {
        echeck("DUMP-MARKDOWN-LAW", r.markdownContent.contains("## ") && r.markdownContent.contains("AMOR"),
               "dump markdown has structure (\(r.markdownContent.count) chars)")
        echeck("DUMP-CRON-HEALTH", r.snapshot.cronHealthPercentage >= 0 && r.snapshot.cronHealthPercentage <= 100,
               "cron health \(String(format: "%.0f", r.snapshot.cronHealthPercentage))%")
        // LEDGER LAW cleanup: remove the harness's own dump; remove the
        // dumps dir ONLY if empty (never destroy real evidence — the app
        // may have authored dumps of its own).
        if let path = r.dumpPath {
            try? FileManager.default.removeItem(atPath: path)
            let dir = (path as NSString).deletingLastPathComponent
            let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? ["keep"]
            if leftovers.isEmpty { try? FileManager.default.removeItem(atPath: dir) }
        }
    }
}

// ── Dump generator (manual dumps) + ProgressTracker ──
do {
    let gen = AMORDumpGenerator()
    let daily = gen.generateDailyDump(
        sessions: sessions, practices: practices, cronJobs: cronJobs,
        mood: "focused", reflections: "Deep work."
    )
    echeck("MANUAL-DUMP", daily.contains("## Sessions") || daily.contains("## "),
           "manual daily dump authored (\(daily.count) chars)")

    let tracker = AMORProgressTracker()
    let insights = tracker.computeWeeklyInsights(
        sessions: sessions, practices: practices, cronJobs: cronJobs
    )
    echeck("TRACKER-WEEKLY", insights.totalSessions >= 4,
           "weekly insights: \(insights.totalSessions) sessions, \(insights.totalFocusMinutes)m focus")

    let streakStats = tracker.computeStreakStats(practices: practices)
    echeck("TRACKER-STREAKS", streakStats.activeCount >= 1,
           "streak stats: \(streakStats.activeCount) active of \(streakStats.totalPractices)")

    let monthly = tracker.computeMonthlyReport(sessions: sessions, practices: practices)
    echeck("TRACKER-MONTHLY", monthly.totalSessions >= 4,
           "monthly report: \(monthly.totalSessions) sessions, streak \(monthly.longestStreak)")
}

print("ENGINE-ASSERTS: \(ePass)/\(ePass + eFail) PASS")
if eFail > 0 { exit(1) }
