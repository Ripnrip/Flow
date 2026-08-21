// Live-fire the cron-health reader against the REAL ~/.hermes/cron/jobs.json
import Foundation

let reader = AMORCronStatusReader()
reader.refresh()
let jobs = reader.jobs.sorted(by: { ($0.lastRunAt ?? .distantPast) > ($1.lastRunAt ?? .distantPast) })
print("=== AMOR CRON HEALTH LIVE-FIRE — \(jobs.count) jobs from real jobs.json ===")
for j in jobs {
    let ageMin: String
    if let lr = j.lastRunAt {
        ageMin = String(Int(Date().timeIntervalSince(lr) / 60)) + "m ago"
    } else {
        ageMin = "never"
    }
    print("[\(j.enabled ? "ON " : "OFF")] \(j.lastStatus) \(ageMin)  \(j.name)")
}
let failing = jobs.filter { $0.enabled && $0.lastStatus == "error" }
print("\nFAILING ENABLED JOBS: \(failing.count)")
for f in failing { print("  ! \(f.name) — \(f.lastError ?? "?")") }

// Live-fire the Gita streak engine against the REAL ~/.hermes/logs/gita_progress.json
// (restored 2026-08-18 — the v2 rewrite had dropped this; streak tracking is a headline feature)
print("=== AMOR GITA STREAK LIVE-FIRE — real gita_progress.json ===")
if let gp = AMORGroundTruthEngine.readGitaProgress() {
    let streak = AMORGroundTruthEngine.gitaStreakDays(from: gp)
    let pos = "Ch \(gp.currentChapter) V \(gp.currentVerse)"
    let done = AMORGroundTruthEngine.gitaCompletedToday(gp) ? "YES" : "not yet"
    print("days_completed=\(gp.daysCompleted) position=\(pos) completedToday=\(done) streakDays=\(streak)")
    print("last_completed=\(gp.lastCompleted?.date ?? "?") Ch\(gp.lastCompleted?.chapter ?? 0)")
} else {
    print("FAIL — gita_progress.json unreadable")
}
let gym = AMORGroundTruthEngine.gymEvidenceDates(daysBack: 7)
print("gym evidence (7d): \(gym.isEmpty ? "0 — HONEST ZERO, not an error" : gym.joined(separator: ", "))")

// Live-fire the meditation ledger (v4.1.0) — reads the real meditation_progress.json
let med = AMORGroundTruthEngine.meditationEvidenceDates(daysBack: 7)
if let mp = AMORGroundTruthEngine.meditationProgress() {
    print("meditation ledger: streak=\(mp.streak) total=\(mp.total) evidence(7d)=\(med.isEmpty ? "0 — HONEST ZERO" : med.joined(separator: ", "))")
} else {
    print("meditation ledger: UNREADABLE — check ~/.hermes/logs/meditation_progress.json")
}

// Live-fire the dump parser (v2): tools must surface from today's real dump
print("\n=== AMOR DUMP PARSER LIVE-FIRE (v2 tools) — last 3 dumps ===")
let dumps = AMORGroundTruthEngine.readRecentDumps(daysBack: 3)
for d in dumps {
    let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
    print("[\(df.string(from: d.date))] sessions=\(d.sessionsToday) tools=\(d.tools) skills=\(d.skillsTouched.count) cronOk=\(d.cronOkCount) cronErr=\(d.cronErrorCount)")
}
let today = dumps.first
print("\nTOOLS-ASSERT: \(today?.tools.isEmpty == false ? "PASS — tools parsed: \(today!.tools)" : "FAIL — no tools in newest dump")")
