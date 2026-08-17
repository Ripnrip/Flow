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

// Live-fire the dump parser (v2): tools must surface from today's real dump
print("\n=== AMOR DUMP PARSER LIVE-FIRE (v2 tools) — last 3 dumps ===")
let dumps = AMORGroundTruthEngine.readRecentDumps(daysBack: 3)
for d in dumps {
    let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
    print("[\(df.string(from: d.date))] sessions=\(d.sessionsToday) tools=\(d.tools) skills=\(d.skillsTouched.count) cronOk=\(d.cronOkCount) cronErr=\(d.cronErrorCount)")
}
let today = dumps.first
print("\nTOOLS-ASSERT: \(today?.tools.isEmpty == false ? "PASS — tools parsed: \(today!.tools)" : "FAIL — no tools in newest dump")")
