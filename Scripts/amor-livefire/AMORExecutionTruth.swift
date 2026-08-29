//
//  AMORExecutionTruth.swift
//  Flow — AMOR v4.8.0
//
//  ┌─────────────────────────────────────────────────────────────┐
//  │              RUN TRUTH ENGINE — v4.8.0                      │
//  └─────────────────────────────────────────────────────────────┘
//
//  MISSION: jobs.json is the *scheduler's* story — lastRunAt banks
//  only on completion, and last_status says "ok" for a run that
//  finished in 0.5 seconds having done nothing at all. The *runs
//  themselves* live in ~/.hermes/cron/executions.db:
//
//    • status     claimed → running → completed | failed | unknown
//    • claimed_at / started_at / finished_at    (real durations)
//    • error      (the actual failure text)
//
//  This engine distills that ledger into per-job stats the health
//  dashboard renders directly:
//
//    • runs & failures over 7 days (history, not just "last")
//    • average + last run duration ("⚡ ~49s" — the hollow-run truth
//      that jobs.json can never tell: 205 "completed" runs at 0.5s
//      each is an idempotent no-op guard, not work)
//    • stuck detection: claimed/running with no finish and no newer
//      attempt for hours — invisible to every lastRunAt-anchored
//      detector (the v4.5.0 lesson, one level deeper)
//
//  ANTI-WOLF LAW (v4.4.0): fast runs are NOT failures. An idempotent
//  guard completing in half a second is legitimate by design. Durations
//  are surfaced as neutral facts; only `failed` rows and genuinely
//  stuck runs raise color. The app tells the truth — it does not cry.
//
//  WAL TRAP (live-proven): opening the ledger SQLITE_OPEN_READONLY
//  fails with rc=14 "unable to open database file" while the -wal
//  sidecar holds recent commits. Opening READWRITE + immediately
//  setting `PRAGMA query_only=ON` (plus busy_timeout) sees every row
//  and still cannot write a byte.
//
//  Foundation-only outside the SQLite3 import — buildable by the
//  CLT live-fire harness (swiftc -sdk … -lsqlite3).
//

import Foundation
import SQLite3

/// Swift's SQLite3 module does not expose SQLITE_TRANSIENT (the -1
/// destructor sentinel). Recreate it the standard way.
private let AMORSQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - Per-Job Run Statistics

/// Run-truth stats for one job, distilled from the executions ledger.
struct AMORJobExecutionStats: Identifiable {
    let jobID: String
    var id: String { jobID }

    /// Total executions claimed in the trailing 7 days.
    let runs7d: Int
    /// Executions that ended `failed` in the trailing 7 days.
    let failures7d: Int
    /// Mean wall-clock duration of completed runs (7d). Nil = no completed runs.
    let avgDurationSeconds: Double?
    /// Duration of the most recent completed run. Nil = none in window.
    let lastDurationSeconds: Double?
    /// Error text from the most recent failed run (7d), truncated.
    let lastError: String?
    /// True when a claimed/running row has sat unfinished so long that
    /// no plausible run remains (default 6h) AND no newer attempt exists.
    let stuck: Bool
    /// How long the stuck row has been claimed, in minutes (0 when not stuck).
    let stuckMinutes: Double

    /// Human-readable average duration — the hollow-run truth chip.
    var avgDurationText: String? {
        Self.durationText(avgDurationSeconds)
    }

    var lastDurationText: String? {
        Self.durationText(lastDurationSeconds)
    }

    var stuckText: String? {
        guard stuck else { return nil }
        if stuckMinutes >= 60 { return String(format: "stuck %.1fh", stuckMinutes / 60) }
        return String(format: "stuck %.0fm", stuckMinutes)
    }

    /// Formats seconds as a compact human truth: "0.5s", "49s", "12m", "1.4h".
    static func durationText(_ seconds: Double?) -> String? {
        guard let s = seconds, s.isFinite, s >= 0 else { return nil }
        if s < 60 { return String(format: "~%.0fs", s.rounded()) }
        if s < 3600 { return String(format: "~%.0fm", s / 60) }
        return String(format: "~%.1fh", s / 3600)
    }
}

// MARK: - Ledger Read Result

struct AMORExecutionTruthResult {
    /// Per-job stats keyed by job id.
    var stats: [String: AMORJobExecutionStats] = [:]
    /// Total execution rows seen in the 7d window (all jobs).
    var totalExecutions: Int = 0
    /// True when the ledger was found and read successfully.
    var isAvailable: Bool = false
}

// MARK: - Execution Truth Reader

/// Reads the Hermes executions ledger — the run-level ground truth
/// beneath jobs.json's scheduler-level summary.
enum AMORExecutionTruth {

    /// A row from the executions ledger.
    private struct Row {
        let jobID: String
        let status: String
        let claimedAt: Date?
        let finishedAt: Date?
        let durationSeconds: Double?
        let error: String?
    }

    /// Jobs claimed-but-unfinished longer than this are stuck (6h —
    /// the longest legitimate agent runs run ~35m; 6h is 10× headroom
    /// so a heavyweight unbroker scan never false-trips).
    static let stuckThresholdSeconds: Double = 6 * 3600

    /// Statistics window (7 days — matches the EOD dump horizon).
    static let windowSeconds: Double = 7 * 86400

    /// Reads and distills the ledger. Never throws: a missing or
    /// unreadable ledger yields an unavailable result, not an alarm.
    static func read(hermesHome: URL) -> AMORExecutionTruthResult {
        let dbURL = hermesHome
            .appendingPathComponent("cron")
            .appendingPathComponent("executions.db")

        var result = AMORExecutionTruthResult()
        guard FileManager.default.fileExists(atPath: dbURL.path) else { return result }

        // READWRITE + query_only: escapes the WAL readonly trap while
        // guaranteeing this engine cannot mutate the ledger (live-proven:
        // readonly sees 0 rows when -wal holds recent commits; this open
        // sees all of them).
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK, let d = db else {
            if db != nil { sqlite3_close(db) }
            return result
        }
        defer { sqlite3_close(d) }
        sqlite3_exec(d, "PRAGMA query_only=ON; PRAGMA busy_timeout=2000;", nil, nil, nil)

        let rows = fetchRows(d)
        result.isAvailable = true
        result.totalExecutions = rows.count
        result.stats = distill(rows: rows, now: Date())
        return result
    }

    // MARK: Row fetch

    private static func fetchRows(_ d: OpaquePointer) -> [Row] {
        // 7d window via SQLite's own ISO parser (format-agnostic — the
        // ledger writes "...T20:20:26.245505+00:00"), plus every lingering
        // claimed/running row regardless of age — stuck rows are often
        // older than the window itself.
        let sql = """
        SELECT job_id, status, claimed_at, finished_at, error
        FROM executions
        WHERE date(claimed_at) >= date('now', '-7 day') OR status IN ('claimed','running')
        ORDER BY claimed_at ASC
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(d, sql, -1, &stmt, nil) == SQLITE_OK, let s = stmt else {
            if stmt != nil { sqlite3_finalize(stmt) }
            return []
        }
        defer { sqlite3_finalize(s) }

        var rows: [Row] = []
        let parser = LedgerDateFormatter.shared
        while sqlite3_step(s) == SQLITE_ROW {
            let jobID = String(cString: sqlite3_column_text(s, 0))
            let status = String(cString: sqlite3_column_text(s, 1))
            let claimed = sqlite3_column_text(s, 2).map { parser.date(from: String(cString: $0)) } ?? nil
            let finished = sqlite3_column_text(s, 3).map { parser.date(from: String(cString: $0)) } ?? nil
            let err = sqlite3_column_text(s, 4).map { String(cString: $0) } ?? nil
            var duration: Double?
            if let f = finished, let c = claimed {
                duration = max(0, f.timeIntervalSince(c))
            }
            rows.append(Row(jobID: jobID, status: status, claimedAt: claimed,
                            finishedAt: finished, durationSeconds: duration, error: err))
        }
        return rows
    }

    // MARK: Distillation

    private static func distill(rows: [Row], now: Date) -> [String: AMORJobExecutionStats] {
        // Group by job.
        var byJob: [String: [Row]] = [:]
        for row in rows { byJob[row.jobID, default: []].append(row) }

        var stats: [String: AMORJobExecutionStats] = [:]
        for (jobID, jobRows) in byJob {
            let completed = jobRows.filter { $0.status == "completed" }
            let failed = jobRows.filter { $0.status == "failed" }

            let durations = completed.compactMap { $0.durationSeconds }
            let avg = durations.isEmpty ? nil : durations.reduce(0, +) / Double(durations.count)
            let lastCompleted = completed.last?.durationSeconds

            // Most recent failure text — prefer the newest failed row that
            // actually carries an error (a bare reaped row answers nil).
            let recentError = failed.reversed().first(where: { !($0.error ?? "").isEmpty })?.error

            // Stuck: a claimed/running row past the threshold with NO newer
            // attempt for the same job — a newer row means the scheduler
            // moved on (the old row is a reaped orphan, not a live hang).
            let unfinished = jobRows.filter { $0.status == "claimed" || $0.status == "running" }
            var stuck = false
            var stuckMinutes: Double = 0
            if let oldest = unfinished.compactMap({ $0.claimedAt }).min() {
                let age = now.timeIntervalSince(oldest)
                let hasNewerAttempt = jobRows.contains { row in
                    guard let c = row.claimedAt else { return false }
                    return c > oldest
                }
                if age > stuckThresholdSeconds && !hasNewerAttempt {
                    stuck = true
                    stuckMinutes = age / 60
                }
            }

            stats[jobID] = AMORJobExecutionStats(
                jobID: jobID,
                runs7d: jobRows.count,
                failures7d: failed.count,
                avgDurationSeconds: avg,
                lastDurationSeconds: lastCompleted,
                lastError: recentError?.prefix(140).description,
                stuck: stuck,
                stuckMinutes: stuckMinutes
            )
        }
        return stats
    }
}

// MARK: - Date plumbing

/// The ledger stores ISO 8601 timestamps with fractional seconds and an
/// explicit offset ("2026-08-29T20:20:26.245505+00:00" — live-proven).
/// Falls back to naive "YYYY-MM-DD HH:mm:ss" for safety.
private struct LedgerDateFormatter {
    let isoFractional: ISO8601DateFormatter
    let isoPlain: ISO8601DateFormatter
    let naive: DateFormatter
    static let shared = LedgerDateFormatter()

    init() {
        let frac = ISO8601DateFormatter()
        frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.isoFractional = frac

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        self.isoPlain = plain

        let n = DateFormatter()
        n.dateFormat = "yyyy-MM-dd HH:mm:ss"
        n.timeZone = TimeZone(identifier: "UTC")
        n.locale = Locale(identifier: "en_US_POSIX")
        self.naive = n
    }

    func date(from s: String) -> Date? {
        isoFractional.date(from: s) ?? isoPlain.date(from: s) ?? naive.date(from: s)
    }
}
