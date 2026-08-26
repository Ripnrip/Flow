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

// v4.4.0: missed-schedule detection asks "did a run happen after the slot?"
let missed = jobs.filter { $0.healthStatus == "missed" }
print("\nMISSED-SCHEDULE JOBS: \(missed.count)")
for m in missed {
    print("  🟠 \(m.name) — last run \(m.relativeLastRun), expected slot passed (status still 'ok')")
}

// v4.5.0: zombies — enabled, never ran, schedule drifted past creation.
let zombies = jobs.filter { $0.healthStatus == "zombie" }
print("\nZOMBIE JOBS (enabled, never ran, drifted): \(zombies.count)")
for z in zombies {
    print("  🧟 \(z.name) — created \(z.relativeCreatedAt), never ran, next_run drifted to \(z.relativeNextRun)")
}
print("summary: active=\(reader.totalActive) healthy=\(reader.totalHealthy) missed=\(reader.totalMissed) zombies=\(reader.totalZombies) failing=\(reader.totalFailing) paused=\(reader.totalPaused)")
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

       // HARD ASSERT 3 — a daily job that ran its slot today, hours ago, must NOT be missed
       // (v4.3.0 false-positive: it saw "last run 9h ago > 90m grace" and flagged orange).
       do {
       struct FixtureJob: Codable { let jobs: [AMORCronJob] }
       let fmt = ISO8601DateFormatter()
       let last = Date().addingTimeInterval(-8 * 3600)  // ran 8 hours ago, after 12:00 slot
       let next = Date().addingTimeInterval(16 * 3600)  // next slot tomorrow
       let json = """
       {"jobs":[{
       "id":"fix-daily-midcycle","name":"Fixture Mid-Cycle Daily","enabled":true,"state":"active",
       "schedule_display":"0 12 * * *","schedule":{"kind":"cron","expr":"0 12 * * *"},
       "last_status":"ok",
       "last_run_at":"\(fmt.string(from: last))","next_run_at":"\(fmt.string(from: next))",
       "deliver":"telegram:1"
       }]}
       """
       if let data = json.data(using: .utf8),
       let fixture = try? JSONDecoder().decode(FixtureJob.self, from: data).jobs.first {
       let hs = fixture.healthStatus
       print("fixture(daily,mid-cycle): healthStatus=\(hs)")
       if hs != "healthy" {
           print("MID-CYCLE-ASSERT: FAIL — expected healthy, got \(hs)")
           exit(1)
       }
       print("MID-CYCLE-ASSERT: PASS — ran-today daily stays green ✅")
       } else {
       print("MID-CYCLE-ASSERT: FAIL — fixture decode failed")
       exit(1)
       }
       }

       // HARD ASSERT 4 — an hour-step calendar job (e.g. Strategic Heartbeat) that ran its
       // most recent slot must not be flagged missed just because 90m grace passed.
       do {
       struct FixtureJob: Codable { let jobs: [AMORCronJob] }
       let fmt = ISO8601DateFormatter()
       let last = Date().addingTimeInterval(-59 * 60)  // 59m ago, after the 18:00 slot
       let next = Date().addingTimeInterval(61 * 60)   // next slot at 20:00
       let json = """
       {"jobs":[{
       "id":"fix-hourstep","name":"Fixture Hour-Step","enabled":true,"state":"active",
       "schedule_display":"0 */2 * * *","schedule":{"kind":"cron","expr":"0 */2 * * *"},
       "last_status":"ok",
       "last_run_at":"\(fmt.string(from: last))","next_run_at":"\(fmt.string(from: next))",
       "deliver":"telegram:1"
       }]}
       """
       if let data = json.data(using: .utf8),
       let fixture = try? JSONDecoder().decode(FixtureJob.self, from: data).jobs.first {
       let hs = fixture.healthStatus
       print("fixture(hour-step,ran-slot): healthStatus=\(hs)")
       if hs != "healthy" {
           print("HOURSTEP-ASSERT: FAIL — expected healthy, got \(hs)")
           exit(1)
       }
       print("HOURSTEP-ASSERT: PASS — hour-step job that ran its slot stays green ✅")
       } else {
       print("HOURSTEP-ASSERT: FAIL — fixture decode failed")
       exit(1)
       }
       }

       // HARD ASSERT 5 — the zombie signature (v4.5.0): enabled, never ran,
       // created two+ periods ago on a REAL 48h interval (2880m — note:
       // 172800m is 120 DAYS, the units-bug shape, not a zombie). Every other
       // detector is blind (they anchor on lastRunAt). Must classify "zombie".
       do {
       struct FixtureJob: Codable { let jobs: [AMORCronJob] }
       let fmt = ISO8601DateFormatter()
       let created = Date().addingTimeInterval(-40 * 86400)  // created 40 days ago
       let next = Date().addingTimeInterval(47 * 3600)       // scheduler still says +47h
       let json = """
       {"jobs":[{
       "id":"fix-zombie","name":"Fixture Zombie","enabled":true,"state":"active",
       "schedule_display":"every 2880m","schedule":{"kind":"interval","minutes":2880},
       "schedule_display":"every 2880m","schedule":{"kind":"interval","minutes":2880},
       "last_status":"pending",
       "last_run_at":null,"next_run_at":"\(fmt.string(from: next))",
       "created_at":"\(fmt.string(from: created))",
       "deliver":"telegram:1"
       }]}
       """
       if let data = json.data(using: .utf8),
       let fixture = try? JSONDecoder().decode(FixtureJob.self, from: data).jobs.first {
       let hs = fixture.healthStatus
       print("fixture(interval-zombie,never-ran): healthStatus=\(hs)")
       if hs != "zombie" {
       print("ZOMBIE-ASSERT: FAIL — expected zombie, got \(hs)")
       exit(1)
       }
       print("ZOMBIE-ASSERT: PASS — never-run drifted job flagged 🧟")
       } else {
       print("ZOMBIE-ASSERT: FAIL — fixture decode failed")
       exit(1)
       }
       }

       // HARD ASSERT 6 — a freshly created job must NOT be a zombie: it hasn't
       // missed anything yet; its first slot may still be in the future.
       do {
       struct FixtureJob: Codable { let jobs: [AMORCronJob] }
       let fmt = ISO8601DateFormatter()
       let created = Date().addingTimeInterval(-3600)        // created 1h ago
       let next = Date().addingTimeInterval(47 * 3600)       // first run due in 47h
       let json = """
       {"jobs":[{
       "id":"fix-fresh-job","name":"Fixture Fresh Job","enabled":true,"state":"active",
       "schedule_display":"every 2880m","schedule":{"kind":"interval","minutes":2880},
       "last_status":"pending",
       "last_run_at":null,"next_run_at":"\(fmt.string(from: next))",
       "created_at":"\(fmt.string(from: created))",
       "deliver":"telegram:1"
       }]}
       """
       if let data = json.data(using: .utf8),
       let fixture = try? JSONDecoder().decode(FixtureJob.self, from: data).jobs.first {
       let hs = fixture.healthStatus
       print("fixture(fresh-job,first-slot-ahead): healthStatus=\(hs)")
       if hs == "zombie" {
       print("FRESHJOB-ASSERT: FAIL — expected non-zombie, got \(hs)")
       exit(1)
       }
       print("FRESHJOB-ASSERT: PASS — freshly created job stays non-zombie ✅")
       } else {
       print("FRESHJOB-ASSERT: FAIL — fixture decode failed")
       exit(1)
       }
       }
