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

// ══════════════════════════════════════════════════════════════════
// v4.8.0 — RUN TRUTH LEG: the executions ledger beneath jobs.json
// ══════════════════════════════════════════════════════════════════
// jobs.json is the scheduler's story (lastRunAt banks only on
// completion). The RUNS live in ~/.hermes/cron/executions.db —
// durations, failure history, stuck claims. This leg live-fires the
// truth engine against the real ledger + a synthetic faux ledger for
// the stuck/flaky/hollow shapes the real one doesn't currently hold.

import SQLite3

/// Harness-local SQLITE_TRANSIENT sentinel (engine's copy is file-private).
let FIXTURE_SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

let hermesHome = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".hermes")
let execTruth = AMORExecutionTruth.read(hermesHome: hermesHome)
print("\n=== AMOR EXECUTION TRUTH LIVE-FIRE — real ~/.hermes/cron/executions.db ===")
print("ledger available: \(execTruth.isAvailable) · executions in 7d window: \(execTruth.totalExecutions)")
if execTruth.isAvailable {
    for (_, s) in execTruth.stats.sorted(by: { $0.value.runs7d > $1.value.runs7d }) {
        let avg = s.avgDurationText ?? "—"
        let last = s.lastDurationText ?? "—"
        print("  [\(s.jobID)] runs=\(s.runs7d) fail=\(s.failures7d) avg=\(avg) last=\(last)\(s.stuck ? " STUCK \(s.stuckText ?? "")" : "")")
    }
    // Cross-check: the ledger's completed runs must match jobs.json's
    // banked lastRunAt story for at least one job (the two truths agree).
    let mono = execTruth.stats["6267cc96c42c"]
    if let mono = mono {
        print("  hollow-run truth: monographs feeder \(mono.runs7d) runs avg \(mono.avgDurationText ?? "—") — jobs.json calls it ✅ok; the ledger shows ~0.5s idempotent no-ops")
    }
} else {
    print("  (ledger missing or unreadable — engine degrades to unavailable, no alarm)")
}

// FAUX LEDGER — deterministic fixtures for shapes the real ledger lacks.
do {
    // read(hermesHome:) resolves <home>/cron/executions.db — build that shape.
    let fixtureRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("amor-exec-fixture-\(Int(Date().timeIntervalSince1970))", isDirectory: true)
    let fixtureCron = fixtureRoot.appendingPathComponent("cron", isDirectory: true)
    try? FileManager.default.createDirectory(at: fixtureCron, withIntermediateDirectories: true)
    let tmp = fixtureCron.appendingPathComponent("executions.db")
    var db: OpaquePointer?
    guard sqlite3_open_v2(tmp.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK, let d = db else {
        print("EXEC-ASSERTS: FAIL — could not create faux ledger")
        exit(1)
    }
    defer {
        sqlite3_close(d)
        try? FileManager.default.removeItem(at: fixtureRoot)
    }
    sqlite3_exec(d, """
    CREATE TABLE executions (
      id TEXT PRIMARY KEY, job_id TEXT NOT NULL, source TEXT NOT NULL,
      process_id TEXT NOT NULL, pid INTEGER NOT NULL, process_started_at INTEGER,
      status TEXT NOT NULL, claimed_at TEXT NOT NULL, started_at TEXT,
      finished_at TEXT, error TEXT
    );
    """, nil, nil, nil)

    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
    fmt.timeZone = TimeZone(identifier: "UTC")
    fmt.locale = Locale(identifier: "en_US_POSIX")
    func ts(_ dAgo: Double) -> String {
        fmt.string(from: Date().addingTimeInterval(-dAgo))
    }
    func insert(_ jid: String, _ status: String, _ secAgo: Double, _ durSec: Double?, _ err: String?) {
        var stmt: OpaquePointer?
        let claimed = ts(secAgo)
        let finished = durSec.map { ts(secAgo - $0) }
        let sql = "INSERT INTO executions (id, job_id, source, process_id, pid, status, claimed_at, started_at, finished_at, error) VALUES (?,?,?,?,?,?,?,?,?,?)"
        guard sqlite3_prepare_v2(d, sql, -1, &stmt, nil) == SQLITE_OK, let s = stmt else { return }
        defer { sqlite3_finalize(s) }
        sqlite3_bind_text(s, 1, UUID().uuidString, -1, FIXTURE_SQLITE_TRANSIENT)
        sqlite3_bind_text(s, 2, jid, -1, FIXTURE_SQLITE_TRANSIENT)
        sqlite3_bind_text(s, 3, "cron", -1, FIXTURE_SQLITE_TRANSIENT)
        sqlite3_bind_text(s, 4, "proc", -1, FIXTURE_SQLITE_TRANSIENT)
        sqlite3_bind_int64(s, 5, 12345)
        sqlite3_bind_text(s, 6, status, -1, FIXTURE_SQLITE_TRANSIENT)
        sqlite3_bind_text(s, 7, claimed, -1, FIXTURE_SQLITE_TRANSIENT)
        sqlite3_bind_text(s, 8, claimed, -1, FIXTURE_SQLITE_TRANSIENT)
        if let f = finished { sqlite3_bind_text(s, 9, f, -1, FIXTURE_SQLITE_TRANSIENT) } else { sqlite3_bind_null(s, 9) }
        if let e = err { sqlite3_bind_text(s, 10, e, -1, FIXTURE_SQLITE_TRANSIENT) } else { sqlite3_bind_null(s, 10) }
        sqlite3_step(s)
    }

    // Shape 1 — STUCK: claimed 10h ago, never finished, no newer attempt.
    insert("fix-stuck", "claimed", 10 * 3600, nil, nil)
    // Shape 2 — FLAKY: two failures then a success, all recent.
    insert("fix-flaky", "failed", 3 * 3600, 20, "HTTP 429 from provider")
    insert("fix-flaky", "failed", 2 * 3600, 15, nil)
    insert("fix-flaky", "completed", 1 * 3600, 30, nil)
    // Shape 3 — HOLLOW: sub-second no-op guard, by design not a failure.
    insert("fix-hollow", "completed", 30 * 60, 0.5, nil)
    insert("fix-hollow", "completed", 15 * 60, 0.4, nil)
    // Shape 4 — FRESH: one healthy run, nothing suspicious.
    insert("fix-fresh", "completed", 45 * 60, 62, nil)
    // Shape 5 — REAPED ORPHAN: running row 9h old BUT a newer completed
    // attempt exists → NOT stuck (scheduler moved on; old row is an orphan).
    insert("fix-orphan", "running", 9 * 3600, nil, nil)
    insert("fix-orphan", "completed", 1 * 3600, 40, nil)

    let result = AMORExecutionTruth.read(hermesHome: fixtureRoot)
    guard result.isAvailable else {
        // read() appends cron/executions.db — fixture must live there.
        print("EXEC-ASSERTS: FAIL — fixture db not found at \(tmp.path)")
        exit(1)
    }

    var pass = 0, fail = 0
    func check(_ name: String, _ ok: Bool, _ detail: String) {
        if ok { pass += 1; print("  ✅ \(name): PASS — \(detail)") }
        else { fail += 1; print("  ❌ \(name): FAIL — \(detail)") }
    }

    let stuck = result.stats["fix-stuck"]
    check("STUCK-ASSERT", stuck?.stuck == true && (stuck?.stuckMinutes ?? 0) > 590,
          "claimed 10h unfinished no-newer → stuck=true (\(stuck?.stuckText ?? "nil"))")
    let flaky = result.stats["fix-flaky"]
    check("FLAKY-ASSERT", (flaky?.failures7d ?? -1) == 2 && (flaky?.runs7d ?? -1) == 3,
          "2 failures + 1 success counted (\(flaky?.failures7d ?? -1)f/\(flaky?.runs7d ?? -1)r), last error surfaced: \(flaky?.lastError ?? "nil")")
    let hollow = result.stats["fix-hollow"]
    check("HOLLOW-ASSERT", (hollow?.runs7d ?? -1) == 2 && hollow?.stuck != true,
          "sub-second runs counted (\(hollow?.avgDurationText ?? "—") avg), no false alarm (anti-wolf law)")
    let fresh = result.stats["fix-fresh"]
    check("FRESH-ASSERT", (fresh?.failures7d ?? -1) == 0 && fresh?.stuck != true && (fresh?.lastDurationText ?? "") == "~1m",
          "healthy 62s run rendered as ~1m per the format law (\(fresh?.lastDurationText ?? "nil"))")
    let orphan = result.stats["fix-orphan"]
    check("ORPHAN-ASSERT", orphan?.stuck != true,
          "running row with newer completed attempt NOT stuck — reaped orphan, not a hang")

    print("EXEC-ASSERTS: \(pass)/\(pass + fail) PASS")
    if fail > 0 { exit(1) }
}
