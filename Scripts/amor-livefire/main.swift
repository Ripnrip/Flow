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

    // v4.9.0 — storm verdict on the REAL ledger: fuse this week's failure
    // rows into incidents. Report-only (a hard assert here would time-bomb
    // as the 7d window slides past real events — fixtures carry the law).
    let jobsURL = hermesHome.appendingPathComponent("cron").appendingPathComponent("jobs.json")
    var knownIDs: Set<String> = []
    if let data = try? Data(contentsOf: jobsURL),
       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let arr = obj["jobs"] as? [[String: Any]] {
        knownIDs = Set(arr.compactMap { $0["id"] as? String })
    }
    let realIncidents = AMORStormSentinel.cluster(
        events: execTruth.failureEvents,
        lastNonFailureByJob: execTruth.lastNonFailureByJob,
        knownJobIDs: knownIDs)
    print("storm sentinel: \(realIncidents.count) incident(s) fused from \(execTruth.failureEvents.count) failure row(s) · \(realIncidents.filter { $0.isActive }.count) active")
    for inc in realIncidents.prefix(5) {
        let verdict = inc.isActive ? "🌩️ ACTIVE" : (inc.recovered ? "✅ resolved" : "🌙 quiet")
        print("  \(inc.isStorm ? "storm" : "lone ") · \(verdict) · \(inc.summaryText)")
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

    // v4.9.0 — STORM SENTINEL asserts. The same faux ledger already holds
    // a lone-job chain (fix-flaky) — the sentinel must NOT promote it to
    // weather. Shape 6 forges the overnight-outage signature: failures
    // chained across 3 jobs at ≤2.5h gaps, then clean runs after.
    let knownJobs: Set<String> = ["fix-stuck", "fix-flaky", "fix-hollow", "fix-fresh", "fix-orphan", "fix-storm-a", "fix-storm-b", "fix-storm-c"]

    // fix-flaky: failed 3h ago, failed 2h ago, completed 1h ago → one lone
    // chain, single job, recovered → no storm, no active incident.
    let flakyEvents: [AMORFailureEvent] = [
        AMORFailureEvent(jobID: "fix-flaky", date: Date().addingTimeInterval(-3 * 3600), error: "HTTP 429"),
        AMORFailureEvent(jobID: "fix-flaky", date: Date().addingTimeInterval(-2 * 3600), error: nil),
    ]
    let flakyRecovery: [String: Date] = ["fix-flaky": Date().addingTimeInterval(-1 * 3600)]

    let loneVerdict = AMORStormSentinel.cluster(events: flakyEvents, lastNonFailureByJob: flakyRecovery, knownJobIDs: knownJobs, now: Date())
    check("LONE-ASSERT", loneVerdict.count == 1 && !loneVerdict[0].isStorm && !loneVerdict[0].isActive,
          "single-job failure chain stays a row chip, never weather (isStorm=\(loneVerdict.first?.isStorm ?? false), active=\(loneVerdict.first?.isActive ?? true))")

    // Shape 6 — STORM: the live-proven overnight outage. 3 jobs, 5 bolts,
    // 2h apart, all inside the 2.5h chain gap; every member flew after.
    let h: Double = 3600
    let stormEvents: [AMORFailureEvent] = [
        AMORFailureEvent(jobID: "fix-storm-a", date: Date().addingTimeInterval(-12 * h), error: "Hermes can't reach the model provider"),
        AMORFailureEvent(jobID: "fix-storm-b", date: Date().addingTimeInterval(-10 * h), error: "Hermes can't reach the model provider"),
        AMORFailureEvent(jobID: "fix-storm-a", date: Date().addingTimeInterval(-8 * h), error: "HTTP 404 model gone"),
        AMORFailureEvent(jobID: "fix-storm-c", date: Date().addingTimeInterval(-6 * h), error: nil),
        AMORFailureEvent(jobID: "fix-storm-a", date: Date().addingTimeInterval(-4 * h), error: "HTTP 404 model gone"),
    ]
    let stormRecovery: [String: Date] = [
        "fix-storm-a": Date().addingTimeInterval(-2 * h),   // witness flew after last bolt
        "fix-storm-b": Date().addingTimeInterval(-1 * h),
        // fix-storm-c never reported after — ONE-WITNESS LAW still clears it
    ]
    let stormVerdict = AMORStormSentinel.cluster(events: stormEvents, lastNonFailureByJob: stormRecovery, knownJobIDs: knownJobs, now: Date())
    let storm = stormVerdict.first
    check("STORM-ASSERT", (storm?.isStorm ?? false) && (storm?.failureCount ?? 0) == 5 && (storm?.jobIDs.count ?? 0) == 3 && !(storm?.isActive ?? true),
          "5 bolts / 3 jobs fused into ONE storm, one witness clears it (jobs=\(storm?.jobIDs.count ?? 0), failures=\(storm?.failureCount ?? 0), active=\(storm?.isActive ?? true))")

    // Shape 7 — ACTIVE storm: same shape, but the last bolt was 1h ago and
    // nobody has run since — the sky is still dark.
    let activeEvents = stormEvents.map { e in
        AMORFailureEvent(jobID: e.jobID, date: e.date.addingTimeInterval(3 * h), error: e.error)
    }
    let activeVerdict = AMORStormSentinel.cluster(events: activeEvents, lastNonFailureByJob: [:], knownJobIDs: knownJobs, now: Date())
    check("SKY-DARK-ASSERT", (activeVerdict.first?.isStorm ?? false) && (activeVerdict.first?.isActive ?? false),
          "storm with no recovery and last bolt 1h ago → ACTIVE banner (active=\(activeVerdict.first?.isActive ?? false))")

    // Shape 8 — SPLIT: two failures 24h apart are NOT one storm — the
    // gap law cuts the chain.
    let splitEvents: [AMORFailureEvent] = [
        AMORFailureEvent(jobID: "fix-storm-a", date: Date().addingTimeInterval(-30 * h), error: "old bolt"),
        AMORFailureEvent(jobID: "fix-storm-b", date: Date().addingTimeInterval(-6 * h), error: "new bolt"),
    ]
    let splitVerdict = AMORStormSentinel.cluster(events: splitEvents, lastNonFailureByJob: [:], knownJobIDs: knownJobs, now: Date())
    check("SPLIT-ASSERT", splitVerdict.count == 2,
          "failures 24h apart fuse into 2 incidents, not 1 (chain gap law holds, count=\(splitVerdict.count))")

    print("EXEC-ASSERTS: \(pass)/\(pass + fail) PASS")
    if fail > 0 { exit(1) }
}

// ═══════════════════════════════════════════════════════════════════
// v5.0.0 — MORTAL STREAKS leg. The streak intelligence was welded to
// SwiftData @Models, so this harness could NEVER compile it — five
// versions shipped an untested health-score law. The snapshot mirror
// changes that. These asserts carry the law forever.
// ═══════════════════════════════════════════════════════════════════
do {
    var sPass = 0, sFail = 0
    func scheck(_ name: String, _ cond: Bool, _ detail: String) {
        if cond { sPass += 1; print("  ✅ \(name): PASS — \(detail)") }
        else { sFail += 1; print("  ❌ \(name): FAIL — \(detail)") }
    }
    let cal = Calendar.current
    func day(_ offset: Int) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f.string(from: cal.date(byAdding: .day, value: offset, to: Date())!)
    }

    print("=== AMOR STREAK INTELLIGENCE LIVE-FIRE — v5.0.0 mortal streaks ===")

    // LAW 1 — dates are truth. A gap breaks the chain honestly.
    let chained = [day(0), day(-1), day(-2), day(-4), day(-5)]  // gap at -3d
    scheck("CHAIN-ASSERT", AMORGroundTruthEngine.trailingStreakDays(fromDateStrings: chained) == 3,
           "gap at day-3 cuts the chain to 3 (got \(AMORGroundTruthEngine.trailingStreakDays(fromDateStrings: chained)))")
    let ancient = [day(-5), day(-6), day(-7)]
    scheck("BROKEN-ASSERT", AMORGroundTruthEngine.trailingStreakDays(fromDateStrings: ancient) == 0,
           "chain that ended 5d ago = honest 0, NOT dates.count (got \(AMORGroundTruthEngine.trailingStreakDays(fromDateStrings: ancient)))")
    let anchored = [day(-1), day(-2), day(-3)]
    scheck("ANCHOR-ASSERT", AMORGroundTruthEngine.trailingStreakDays(fromDateStrings: anchored) == 3,
           "yesterday-anchored chain counts 3 before today is done (got \(AMORGroundTruthEngine.trailingStreakDays(fromDateStrings: anchored)))")
    scheck("EMPTY-ASSERT", AMORGroundTruthEngine.trailingStreakDays(fromDateStrings: []) == 0,
           "no evidence = 0, never a lifetime counter")

    // LAW 2 — a readable ledger SETs the streak; it can lower it.
    // (Syncer law — proven here via the engine: derived chain IS the streak.)
    if let gita = AMORGroundTruthEngine.readGitaProgress() {
        let derived = AMORGroundTruthEngine.gitaStreakDays(from: gita)
        let immortal = gita.daysCompleted
        print("real ledger: derived chain = \(derived) days · lifetime counter days_completed = \(immortal) (old law displayed max(derived, \(immortal)) = \(max(derived, immortal)))")
        scheck("MORTAL-LIVE", derived <= immortal,
               "derived chain (\(derived)) no longer floored by lifetime counter (\(immortal))")
    }

    // LAW 3 — never-started practices are invitations, not wounds.
    // The live shape: 95-morning Gita devotee + two never-started practices
    // rendered 🌱 49.5/100 under the old all-practices denominator.
    let devotee = AMORPracticeSnapshot(practiceName: "Gita", currentStreak: 95, longestStreak: 95,
                                       totalCompletions: 95, lastCompletedDate: Date())
    let dormant1 = AMORPracticeSnapshot(practiceName: "Gym", currentStreak: 0, longestStreak: 0,
                                        totalCompletions: 0, lastCompletedDate: nil)
    let dormant2 = AMORPracticeSnapshot(practiceName: "Meditation", currentStreak: 0, longestStreak: 0,
                                        totalCompletions: 0, lastCompletedDate: nil)
    let summary = AMORStreakIntelligence.generateSummary(practices: [devotee, dormant1, dormant2])
    scheck("SEEDLING-ASSERT", summary.overallHealthScore >= 80 && summary.atRiskCount == 0 && summary.brokenCount == 0,
           String(format: "devotee + 2 dormant = %.1f/100 (was 49.5 🌱), dormancy never wounds", summary.overallHealthScore))

    // LAW 4 — a broken streak is finally VISIBLE. The immortal law could
    // never show a break; now a 5-day-old last completion is .broken.
    let lapsed = AMORPracticeSnapshot(practiceName: "Gita", currentStreak: 95, longestStreak: 95,
                                      totalCompletions: 95,
                                      lastCompletedDate: cal.date(byAdding: .day, value: -5, to: Date()))
    let risk = AMORStreakIntelligence.assessRisk(practice: lapsed)
    let actions = AMORStreakIntelligence.recoveryActions(for: [lapsed])
    scheck("MORTALITY-ASSERT", risk == .broken && !actions.isEmpty,
           "5-day-old completion reads .broken and reaches the recovery desk (risk=\(risk.rawValue), actions=\(actions.count))")

    // All-dormant: invitation headline, zero false alarms.
    let dormantSummary = AMORStreakIntelligence.generateSummary(practices: [dormant1, dormant2])
    scheck("ALL-DORMANT-ASSERT", dormantSummary.atRiskCount == 0 && dormantSummary.brokenCount == 0 && dormantSummary.longestStreak == 0,
           "all-dormant = pure invitation, no at-risk noise (headline: \(dormantSummary.headline))")

    // Milestones only fire for started practices.
    scheck("MILESTONE-ASSERT", AMORStreakIntelligence.detectMilestones(practices: [dormant1, dormant2]).isEmpty,
           "dormant practices never mint milestones")

    print("STREAK-ASSERTS: \(sPass)/\(sPass + sFail) PASS")
    if sFail > 0 { exit(1) }
}
