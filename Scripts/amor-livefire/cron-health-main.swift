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
    let missFlag = j.healthStatus == "missed" ? " 🟠MISSED" : ""
    print("[\(j.enabled ? "ON " : "OFF")] \(j.lastStatus) \(ageMin)  \(j.name)\(missFlag)")
}
let failing = jobs.filter { $0.enabled && $0.lastStatus == "error" }
print("\nFAILING ENABLED JOBS: \(failing.count)")
for f in failing { print("  ! \(f.name) — \(f.lastError ?? "?")") }

// v4.3.0: missed-schedule detection (stale-ok blind spot).
let missed = jobs.filter { $0.healthStatus == "missed" }
print("\nMISSED-SCHEDULE JOBS: \(missed.count)")
for m in missed {
    print("  🟠 \(m.name) — last run \(m.relativeLastRun), expected slot passed (status still 'ok')")
}
print("summary: active=\(reader.totalActive) healthy=\(reader.totalHealthy) missed=\(reader.totalMissed) failing=\(reader.totalFailing) paused=\(reader.totalPaused)")
print("attention list: \(reader.jobsNeedingAttention.map { $0.name })")

// HARD ASSERT 1 — deterministic synthetic fixture: the real single-miss
// signature (next−last cadence = 2 days because the scheduler advanced
// next_run_at past one skipped slot; live-proven by the EOD job today).
// Must classify "missed", not "healthy".
do {
    struct FixtureJob: Codable { let jobs: [AMORCronJob] }
    let fmt = ISO8601DateFormatter()
    let last = Date().addingTimeInterval(-27 * 3600)   // yesterday's slot ran
    let next = Date().addingTimeInterval(21 * 3600)    // scheduler advanced past today's skipped slot
    let json = """
    {"jobs":[{
      "id":"fix-daily-missed","name":"Fixture Daily","enabled":true,"state":"active",
      "schedule_display":"0 12 * * *","schedule":{"kind":"cron","expr":"0 12 * * *"},
      "last_status":"ok",
      "last_run_at":"\(fmt.string(from: last))","next_run_at":"\(fmt.string(from: next))",
      "deliver":"telegram:1"
    }]}
    """
    if let data = json.data(using: .utf8),
       let fixture = try? JSONDecoder().decode(FixtureJob.self, from: data).jobs.first {
        let hs = fixture.healthStatus
        print("fixture(daily,slot+3h): healthStatus=\(hs)")
        if hs != "missed" {
            print("MISSED-ASSERT: FAIL — expected missed, got \(hs)")
            exit(1)
        }
        print("MISSED-ASSERT: PASS — stale-ok daily correctly flagged 🟠")
    } else {
        print("MISSED-ASSERT: FAIL — fixture decode failed")
        exit(1)
    }
}

// HARD ASSERT 2 — a freshly-run daily job must stay "healthy" (no false alarm).
do {
    struct FixtureJob: Codable { let jobs: [AMORCronJob] }
    let fmt = ISO8601DateFormatter()
    let last = Date().addingTimeInterval(-3600)
    let next = Date().addingTimeInterval(23 * 3600)
    let json = """
    {"jobs":[{
      "id":"fix-daily-fresh","name":"Fixture Fresh Daily","enabled":true,"state":"active",
      "schedule_display":"0 12 * * *","schedule":{"kind":"cron","expr":"0 12 * * *"},
      "last_status":"ok",
      "last_run_at":"\(fmt.string(from: last))","next_run_at":"\(fmt.string(from: next))",
      "deliver":"telegram:1"
    }]}
    """
    if let data = json.data(using: .utf8),
       let fixture = try? JSONDecoder().decode(FixtureJob.self, from: data).jobs.first {
        let hs = fixture.healthStatus
        print("fixture(daily,fresh): healthStatus=\(hs)")
        if hs != "healthy" {
            print("FRESH-ASSERT: FAIL — expected healthy, got \(hs)")
            exit(1)
        }
        print("FRESH-ASSERT: PASS — fresh daily stays green ✅")
    } else {
        print("FRESH-ASSERT: FAIL — fixture decode failed")
        exit(1)
    }
}
