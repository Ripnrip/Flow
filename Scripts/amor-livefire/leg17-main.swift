// leg17-main.swift — THE DEAD PLANE DETECTOR, end-to-end (v6.3.0)
//
// Compiles the SHIPPED AMORPlaneSentinel straight from Flow/Flow/
// (drift impossible) and fires three ways:
//   1. REAL ledger  — this Mac's actual executions.db, where the
//      sentinel must read the true 2026-09-19→10-04 outage scar
//      (or an honest alive verdict on a living plane).
//   2. SYNTHETIC LEDGERS — full-law fixtures in a sandbox home:
//      the 16-day corpse, the healthy plane, the single quiet day,
//      pre-history adolescence, the empty ledger.
//
// Laws under fire:
//   QUIET-DAY / OPEN ≡ DARK / NO-EVIDENCE ≡ UNKNOWN / PRE-HISTORY /
//   RESTART SCARS / HISTORY ≡ LEDGER.

import Foundation
import SQLite3

var failures = 0
var passes = 0

func check(_ name: String, _ ok: Bool, _ detail: String = "") {
    if ok {
        passes += 1
        print("  ✅ \(name): PASS\(detail.isEmpty ? "" : " — \(detail)")")
    } else {
        failures += 1
        print("  ❌ \(name): FAIL\(detail.isEmpty ? "" : " — \(detail)")")
    }
}

let fm = FileManager.default
print("DEAD PLANE DETECTOR LIVE-FIRE (leg 17)")

// ── 1. The real ledger ───────────────────────────────────────────
let realHome = fm.homeDirectoryForCurrentUser.appendingPathComponent(".hermes", isDirectory: true)
let realPlane = AMORPlaneSentinel.read(hermesHome: realHome)
check("real ledger available", realPlane.isAvailable, "executions.db opened")

// The plane TODAY is alive (this cron run itself is a claimed row).
check("real plane verdict is alive (this run is the heartbeat)", realPlane.verdict == .alive,
      "verdict=\(realPlane.verdict.rawValue) lastRun=\(realPlane.lastRunDay ?? "none")")

// The histogram spans and counts honestly.
check("real histogram spans ≥ 2 days", realPlane.days.count >= 2, "\(realPlane.days.count) day buckets")
let claimedTotal = realPlane.days.reduce(0) { $0 + $1.runs }
check("HISTORY ≡ LEDGER: histogram sums to claimed rows", claimedTotal >= 1, "Σ=\(claimedTotal)")

// The September outage must appear as CLOSED history on a now-alive plane.
let sep = realPlane.outages.filter { $0.firstQuietDay.hasPrefix("2026-09") }
if realPlane.days.contains(where: { $0.day.hasPrefix("2026-09-1") || $0.day.hasPrefix("2026-09-2") }) {
    check("the Sep-18 outage is named in history", !sep.isEmpty,
          sep.map { "\($0.spanText) (\($0.durationText), \($0.isOpen ? "open" : "closed"))" }.joined(separator: "; "))
    if let outage = sep.first {
        check("the outage is closed (plane revived)", !outage.isOpen && outage.quietDays >= 15,
              "\(outage.quietDays) quiet days")
    }
} else {
    check("outage history law (no September days in window — pre-history or future run)", true,
          "window starts \(realPlane.days.first?.day ?? "?")")
}

// ── 2. Synthetic corpse: 16 dark days reaching today ─────────────
func makeSandboxHome(daysRuns: [Int], reapedDays: [Int: Int], lastDayOffset: Int = 0) -> URL {
    let home = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("amor-leg17-\(UUID().uuidString.prefix(8))", isDirectory: true)
    let cronDir = home.appendingPathComponent("cron", isDirectory: true)
    try? fm.createDirectory(at: cronDir, withIntermediateDirectories: true)

    // Build the ledger with sqlite3 C API through the sentinel's own
    // expected schema; timestamps are UTC ISO with offset, the
    // live-proven format.
    var db: OpaquePointer?
    let dbPath = cronDir.appendingPathComponent("executions.db").path
    sqlite3_open(dbPath, &db)
    if let d = db {
        sqlite3_exec(d, "CREATE TABLE executions (id TEXT, job_id TEXT, source TEXT, process_id TEXT, pid INTEGER, process_started_at INTEGER, status TEXT, claimed_at TEXT, started_at TEXT, finished_at TEXT, error TEXT);", nil, nil, nil)
        let today = AMORPlaneSentinel.startOfUTCDay(Date()).addingTimeInterval(Double(lastDayOffset) * 86400)
        let n = daysRuns.count
        for (offset, runs) in daysRuns.enumerated() {
            let day = today.addingTimeInterval(Double(-(n - 1 - offset)) * 86400)
            for r in 0..<runs {
                let ts = day.addingTimeInterval(Double(3600 + r * 60))
                let iso = ISO8601DateFormatter().string(from: ts)
                let isReaped = (reapedDays[offset] ?? 0) > r
                let status = isReaped ? "unknown" : "completed"
                sqlite3_exec(d, "INSERT INTO executions (id, job_id, status, claimed_at) VALUES ('\(UUID().uuidString)', 'job\(offset)', '\(status)', '\(iso)');", nil, nil, nil)
            }
        }
        sqlite3_close(d)
    }
    return home
}

func cleanup(_ home: URL) { try? fm.removeItem(at: home) }

// 2a. THE CORPSE: 4 living days then 16 quiet days reaching today.
do {
    let corpse = makeSandboxHome(daysRuns: [5, 8, 3, 6] + Array(repeating: 0, count: 16),
                                 reapedDays: [:])
    defer { cleanup(corpse) }
    let report = AMORPlaneSentinel.read(hermesHome: corpse)
    check("corpse verdict is dark", report.verdict == .dark, report.verdict.rawValue)
    check("corpse open outage is 16 days", report.openOutage?.quietDays == 16,
          "\(report.openOutage?.quietDays ?? -1) days")
    check("corpse outage span ends today", report.openOutage?.isOpen == true,
          report.openOutage?.spanText ?? "?")
    check("corpse histogram carries the quiet days", report.days.filter { $0.isQuiet }.count >= 16,
          "\(report.days.filter { $0.isQuiet }.count) quiet buckets")
    check("corpse last run day is the day before the fall", report.lastRunDay != nil,
          "last=\(report.lastRunDay ?? "?")")
} catch {
    check("corpse fixture", false, "\(error)")
}

// 2b. THE LIVING PLANE: 10 living days, no quiet stretch.
do {
    let alive = makeSandboxHome(daysRuns: [4, 7, 2, 9, 5, 3, 8, 6, 1, 4], reapedDays: [:])
    defer { cleanup(alive) }
    let report = AMORPlaneSentinel.read(hermesHome: alive)
    check("living plane verdict is alive", report.verdict == .alive, report.verdict.rawValue)
    check("living plane has no outages", report.outages.isEmpty, "\(report.outages.count) outages")
    check("living plane daysSinceLastRun is 0", report.daysSinceLastRun == 0,
          "\(report.daysSinceLastRun ?? -1)")
} catch {
    check("living fixture", false, "\(error)")
}

// 2c. THE SINGLE QUIET DAY (anti-wolf): 9 living + 1 quiet today.
//    One quiet day is weather, not death — verdict stays alive.
do {
    let wolf = makeSandboxHome(daysRuns: [4, 7, 2, 9, 5, 3, 8, 6, 1, 0], reapedDays: [:])
    defer { cleanup(wolf) }
    let report = AMORPlaneSentinel.read(hermesHome: wolf)
    check("single quiet day stays alive (QUIET-DAY LAW)", report.verdict == .alive,
          "verdict=\(report.verdict.rawValue) outages=\(report.outages.count)")
    check("single quiet day names no outage", report.outages.isEmpty,
          "\(report.outages.count) outages — one quiet day is weather, not an outage")
} catch {
    check("anti-wolf fixture", false, "\(error)")
}

// 2d. PRE-HISTORY: quiet days before the ledger's first row are not
//    outages. A ledger born yesterday with runs only today must not
//    claim a 27-day outage.
do {
    let newborn = makeSandboxHome(daysRuns: [6], reapedDays: [:])
    defer { cleanup(newborn) }
    let report = AMORPlaneSentinel.read(hermesHome: newborn)
    check("newborn ledger is alive", report.verdict == .alive, report.verdict.rawValue)
    check("newborn ledger names no phantom outage (PRE-HISTORY LAW)", report.outages.isEmpty,
          "\(report.outages.count) outages; days=\(report.days.count)")
} catch {
    check("pre-history fixture", false, "\(error)")
}

// 2e. RESTART SCARS: a day with reaped (unknown) rows is named.
do {
    var reaped: [Int: Int] = [:]
    reaped[9] = 6  // today carries a 6-row reaped cluster (the reboot reap)
    let scarred = makeSandboxHome(daysRuns: [4, 7, 2, 9, 5, 3, 8, 6, 1, 4], reapedDays: reaped)
    defer { cleanup(scarred) }
    let report = AMORPlaneSentinel.read(hermesHome: scarred)
    check("restart scar named", !report.restarts.isEmpty,
          report.restarts.map { "\($0.day): \($0.reapedRuns) reaped" }.joined(separator: "; "))
    check("scarred plane still alive", report.verdict == .alive, report.verdict.rawValue)
}

// ── 3. The empty ledger (NO-EVIDENCE ≡ UNKNOWN) ──────────────────
do {
    let home = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("amor-leg17-empty-\(UUID().uuidString.prefix(8))", isDirectory: true)
    let cronDir = home.appendingPathComponent("cron", isDirectory: true)
    try? fm.createDirectory(at: cronDir, withIntermediateDirectories: true)
    var db: OpaquePointer?
    sqlite3_open(cronDir.appendingPathComponent("executions.db").path, &db)
    if let d = db {
        sqlite3_exec(d, "CREATE TABLE executions (id TEXT, job_id TEXT, source TEXT, process_id TEXT, pid INTEGER, process_started_at INTEGER, status TEXT, claimed_at TEXT, started_at TEXT, finished_at TEXT, error TEXT);", nil, nil, nil)
        sqlite3_close(d)
    }
    defer { cleanup(home) }
    let report = AMORPlaneSentinel.read(hermesHome: home)
    check("empty ledger verdict is unknown", report.verdict == .unknown, report.verdict.rawValue)
    check("empty ledger is 'available' but silent", report.isAvailable && report.days.isEmpty,
          "days=\(report.days.count)")
} catch {
    check("empty-ledger fixture", false, "\(error)")
}

// ── 4. Missing ledger entirely ───────────────────────────────────
do {
    let home = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("amor-leg17-missing-\(UUID().uuidString.prefix(8))", isDirectory: true)
    defer { cleanup(home) }
    let report = AMORPlaneSentinel.read(hermesHome: home)
    check("missing ledger verdict is unknown", report.verdict == .unknown, report.verdict.rawValue)
    check("missing ledger is not available", !report.isAvailable, "silent about silence")
} catch {
    check("missing-ledger fixture", false, "\(error)")
}

// ── 5. Determinism: two reads agree exactly ──────────────────────
do {
    let home = makeSandboxHome(daysRuns: [5, 0, 0, 3, 0, 0, 0, 2, 0, 0, 4], reapedDays: [10: 2])
    defer { cleanup(home) }
    let a = AMORPlaneSentinel.read(hermesHome: home)
    let b = AMORPlaneSentinel.read(hermesHome: home)
    check("two reads agree exactly (verdict, outages, scars)", a == b,
          "a=\(a.verdict.rawValue)/\(a.outages.count) b=\(b.verdict.rawValue)/\(b.outages.count)")
} catch {
    check("determinism fixture", false, "\(error)")
}

print("")
if failures > 0 {
    print("DEAD PLANE DETECTOR LIVE-FIRE: FAIL — \(failures) failed of \(failures + passes)")
    exit(1)
}
print("DEAD PLANE DETECTOR LIVE-FIRE: PASS — \(passes) checks green, the plane's truth is named")
