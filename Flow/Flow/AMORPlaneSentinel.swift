/**
 * AMORPlaneSentinel — v6.3.0 "The Dead Plane Detector"
 *
 * "Twelve jobs missed their slots" is a lie the dashboard tells when
 * the scheduler itself is a corpse. On 2026-09-18 the gateway's GIL
 * watchdog exited 75 and the restarted process wedged on a port
 * conflict; for SIXTEEN DAYS not one cron fired — Gita, gym,
 * meditation, every EOD dump — while a per-job health view would
 * have rendered a wall of misleading orange. The sentinel reads the
 * executions ledger's day-histogram and names the actual truth:
 * the PLANE is dark, since this day, for this long, restarted here.
 *
 * Laws:
 *   - HISTORY ≡ LEDGER: outages are derived from every UTC day in
 *     the 28-day horizon with zero claimed runs — the same ledger
 *     the run-truth engine reads, no new source of truth.
 *   - QUIET-DAY LAW: a single quiet day is weather (a day can be
 *     legitimately idle); TWO OR MORE consecutive quiet days naming
 *     an outage, and an open stretch reaching today = the plane is
 *     DARK. Anti-wolf by construction: one quiet day never cries.
 *   - OPEN ≡ DARK: a quiet stretch still open at today with ≥2
 *     quiet days is the corpse signature. Closed stretches are
 *     history — rendered neutral, never as current failure.
 *   - NO-EVIDENCE ≡ UNKNOWN: a missing ledger or one with zero
 *     claimed rows in the horizon yields .unknown — silence about
 *     silence. The sentinel never invents a verdict.
 *   - DAY-KEY LAW: day keys are the ledger's own substr(claimed_at,
 *     1,10) — UTC "YYYY-MM-DD" — and calendar walking happens on
 *     parsed Dates (UTC gregorian), so month/year boundaries are
 *     exact; no string arithmetic on dates, ever.
 *
 * Foundation-only (app target + live-fire harness compile the same
 * source; drift is impossible by construction).
 */

import Foundation
import SQLite3

// MARK: - Verdict

enum AMORPlaneVerdict: String, Equatable {
    /// Runs happened today or yesterday at the latest — heartbeat moving.
    case alive
    /// An open quiet stretch of ≥2 days reaches today — the scheduler
    /// itself is not running. Per-job "missed" chips are noise below
    /// this verdict; the outage is the cause, the jobs are casualties.
    case dark
    /// No ledger, or no claimed rows in the horizon — nothing to judge.
    case unknown
}

// MARK: - Report Shapes

/// One UTC day in the horizon and how many runs it claimed.
struct AMORPlaneDay: Identifiable, Equatable {
    /// UTC day key "YYYY-MM-DD".
    let day: String
    /// Claimed executions that day (0 = quiet).
    let runs: Int
    var id: String { day }
    var isQuiet: Bool { runs == 0 }
}

/// A closed or open stretch of consecutive quiet days.
struct AMORPlaneOutage: Identifiable, Equatable {
    /// First quiet UTC day key.
    let firstQuietDay: String
    /// Last quiet UTC day key (== today when the outage is still open).
    let lastQuietDay: String
    /// Consecutive quiet days in the stretch.
    let quietDays: Int
    /// True when the stretch reaches today — the plane is dark NOW.
    let isOpen: Bool

    var id: String { "\(firstQuietDay)…\(lastQuietDay)" }
    var isSingleDay: Bool { quietDays == 1 }

    /// "2026-09-19 → 2026-10-04" (or the lone day, no arrow).
    var spanText: String {
        isSingleDay ? firstQuietDay : "\(firstQuietDay) → \(lastQuietDay)"
    }

    /// "16 days dark" / "1 day dark" — the plain-language duration.
    var durationText: String {
        quietDays == 1 ? "1 day" : "\(quietDays) days"
    }
}

/// A day that shows the restart-scar shape: executions reaped to
/// `unknown` when a supervisor kill raced the terminal write.
struct AMORPlaneRestart: Identifiable, Equatable {
    /// UTC day key of the reaped cluster.
    let day: String
    /// Reaped (`unknown`) rows that day.
    let reapedRuns: Int

    var id: String { day }
}

// MARK: - Report

/// The plane's own story over the trailing horizon.
struct AMORPlaneReport: Equatable {
    let verdict: AMORPlaneVerdict
    /// Every UTC day in the horizon, ascending, with run counts
    /// (quiet days included at 0 — the histogram is the evidence).
    let days: [AMORPlaneDay]
    /// Quiet stretches of ≥2 days, ascending. The last entry is the
    /// OPEN outage when the verdict is dark.
    let outages: [AMORPlaneOutage]
    /// Days carrying reaped-execution clusters, ascending.
    let restarts: [AMORPlaneRestart]
    /// UTC day key of the most recent claimed run in the horizon.
    let lastRunDay: String?
    /// Whole UTC days between the last run and today (0 = ran today).
    let daysSinceLastRun: Int?
    /// True when the ledger was found and read.
    let isAvailable: Bool

    /// The open outage, when the plane is dark now.
    var openOutage: AMORPlaneOutage? {
        guard verdict == .dark else { return nil }
        return outages.last { $0.isOpen }
    }

    /// Closed (historical) outages — neutral truth for the history card.
    var closedOutages: [AMORPlaneOutage] {
        outages.filter { !$0.isOpen }
    }

    /// One-line headline naming the plane's state.
    var headlineText: String {
        switch verdict {
        case .dark:
            let since = lastRunDay ?? "unknown"
            return "Automation plane dark — no runs since \(since)"
        case .alive:
            if outages.isEmpty {
                return "Automation plane alive — every day in the window has runs"
            }
            let word = outages.count == 1 ? "outage" : "outages"
            return "Automation plane alive — \(outages.count) \(word) in the last \(Self.horizonText)"
        case .unknown:
            return "Automation plane unknown — no execution history to judge"
        }
    }

    /// Supporting line with the numbers that matter.
    var sublineText: String {
        switch verdict {
        case .dark:
            if let open = openOutage {
                return "\(open.durationText) of silence (\(open.spanText)). This is not missed jobs — the scheduler heartbeat itself stopped."
            }
            return "The scheduler heartbeat itself stopped."
        case .alive:
            if let last = lastRunDay {
                return "Last run \(last)\(daysSinceLastRun == 0 ? " (today)" : "") · \(days.filter { !$0.isQuiet }.count) living days of \(days.count)."
            }
            return "Runs are flowing."
        case .unknown:
            return "A quiet ledger is not a dead plane — it is no evidence. The sentinel stays silent."
        }
    }

    static var horizonText: String { "28 days" }
}

// MARK: - Sentinel

enum AMORPlaneSentinel {

    /// How far back the histogram reads (days).
    static let horizonDays = 28
    /// Consecutive quiet UTC days (with the stretch reaching today)
    /// required to call the plane dark (QUIET-DAY LAW).
    static let quietDayThreshold = 2

    // UTC day-key plumbing — en_US_POSIX + UTC, the ledger-proven law.
    private static let utcCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC") ?? .current
        return c
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// UTC day key for a Date ("2026-10-05").
    static func dayKey(from date: Date) -> String {
        dayFormatter.string(from: date)
    }

    /// Parses a UTC day key; nil for malformed input.
    static func parseDay(_ key: String) -> Date? {
        dayFormatter.date(from: key)
    }

    /// Start of the UTC day containing `date`.
    static func startOfUTCDay(_ date: Date) -> Date {
        let comps = utcCalendar.dateComponents([.year, .month, .day], from: date)
        return utcCalendar.date(from: comps) ?? date
    }

    // MARK: Read

    /// Reads the plane's story from the executions ledger. Never
    /// throws: a missing/unreadable ledger yields `.unknown`.
    static func read(hermesHome: URL, now: Date = Date()) -> AMORPlaneReport {
        let dbURL = hermesHome
            .appendingPathComponent("cron")
            .appendingPathComponent("executions.db")

        guard FileManager.default.fileExists(atPath: dbURL.path) else {
            return AMORPlaneReport(verdict: .unknown, days: [], outages: [],
                                   restarts: [], lastRunDay: nil,
                                   daysSinceLastRun: nil, isAvailable: false)
        }

        // READWRITE + query_only — the WAL readonly trap law, proven
        // live by the run-truth engine: readonly connections see 0
        // rows while the -wal holds recent commits.
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK, let d = db else {
            if db != nil { sqlite3_close(db) }
            return AMORPlaneReport(verdict: .unknown, days: [], outages: [],
                                   restarts: [], lastRunDay: nil,
                                   daysSinceLastRun: nil, isAvailable: false)
        }
        defer { sqlite3_close(d) }
        sqlite3_exec(d, "PRAGMA query_only=ON; PRAGMA busy_timeout=2000;", nil, nil, nil)

        let histogram = fetchDayHistogram(d, now: now)
        let reapedByDay = fetchReapedClusters(d, now: now)

        // NO-EVIDENCE ≡ UNKNOWN.
        if histogram.isEmpty {
            return AMORPlaneReport(verdict: .unknown, days: [], outages: [],
                                   restarts: [], lastRunDay: nil,
                                   daysSinceLastRun: nil, isAvailable: true)
        }

        return analyze(histogram: histogram, reapedByDay: reapedByDay, now: now)
    }

    // MARK: SQL

    /// UTC day → claimed-run counts over the horizon. Day keys come
    /// from the ledger's own substr — zero date-parsing risk.
    private static func fetchDayHistogram(_ d: OpaquePointer, now: Date) -> [String: Int] {
        let cutoff = dayKey(from: now.addingTimeInterval(-Double(horizonDays) * 86400))
        let sql = """
        SELECT substr(claimed_at, 1, 10) AS day, count(*)
        FROM executions
        WHERE claimed_at IS NOT NULL AND claimed_at >= '\(cutoff)'
        GROUP BY day
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(d, sql, -1, &stmt, nil) == SQLITE_OK, let s = stmt else {
            if stmt != nil { sqlite3_finalize(stmt) }
            return [:]
        }
        defer { sqlite3_finalize(s) }

        var out: [String: Int] = [:]
        while sqlite3_step(s) == SQLITE_ROW {
            guard let dayC = sqlite3_column_text(s, 0) else { continue }
            let day = String(cString: dayC)
            out[day] = Int(sqlite3_column_int64(s, 1))
        }
        return out
    }

    /// UTC day → reaped (`unknown`) execution counts over the horizon.
    private static func fetchReapedClusters(_ d: OpaquePointer, now: Date) -> [String: Int] {
        let cutoff = dayKey(from: now.addingTimeInterval(-Double(horizonDays) * 86400))
        let sql = """
        SELECT substr(claimed_at, 1, 10) AS day, count(*)
        FROM executions
        WHERE status = 'unknown' AND claimed_at IS NOT NULL AND claimed_at >= '\(cutoff)'
        GROUP BY day
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(d, sql, -1, &stmt, nil) == SQLITE_OK, let s = stmt else {
            if stmt != nil { sqlite3_finalize(stmt) }
            return [:]
        }
        defer { sqlite3_finalize(s) }

        var out: [String: Int] = [:]
        while sqlite3_step(s) == SQLITE_ROW {
            guard let dayC = sqlite3_column_text(s, 0) else { continue }
            out[String(cString: dayC)] = Int(sqlite3_column_int64(s, 1))
        }
        return out
    }

    // MARK: Analysis

    /// Walks the horizon calendar day by day (UTC) and derives the
    /// verdict, outages, and restart scars from the histogram.
    static func analyze(histogram: [String: Int], reapedByDay: [String: Int], now: Date) -> AMORPlaneReport {
        let today = startOfUTCDay(now)
        let horizonStart = utcCalendar.date(byAdding: .day, value: -(horizonDays - 1), to: today) ?? today

        // PRE-HISTORY LAW: quiet days before the ledger's first-ever
        // recorded day are not outages — the ledger did not exist.
        // Without this trim a fresh ledger renders a phantom outage
        // the length of its own adolescence (live-caught: this Mac's
        // ledger was born 2026-09-16; Sep 7–15 is pre-history, not
        // sixteen days of silence).
        let firstRecordedDay = histogram.keys.compactMap { parseDay($0) }.min() ?? today
        let walkStart = max(horizonStart, firstRecordedDay)

        var days: [AMORPlaneDay] = []
        var outages: [AMORPlaneOutage] = []
        var lastRunDay: String?

        var cursor = walkStart
        var quietStart: Date?
        var quietCount = 0

        while cursor <= today {
            let key = dayKey(from: cursor)
            let runs = histogram[key] ?? 0
            days.append(AMORPlaneDay(day: key, runs: runs))

            if runs > 0 {
                // A living day closes any pending quiet stretch.
                if let qs = quietStart, quietCount >= quietDayThreshold {
                    let lastQuiet = utcCalendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
                    outages.append(AMORPlaneOutage(
                        firstQuietDay: dayKey(from: qs),
                        lastQuietDay: dayKey(from: lastQuiet),
                        quietDays: quietCount,
                        isOpen: false))
                }
                quietStart = nil
                quietCount = 0
                lastRunDay = key
            } else {
                if quietStart == nil { quietStart = cursor }
                quietCount += 1
            }
            cursor = utcCalendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            if cursor == walkStart { break } // degenerate guard
        }

        // OPEN ≡ DARK: an unclosed stretch reaching today.
        var verdict: AMORPlaneVerdict = .alive
        if let qs = quietStart, quietCount >= quietDayThreshold {
            outages.append(AMORPlaneOutage(
                firstQuietDay: dayKey(from: qs),
                lastQuietDay: dayKey(from: today),
                quietDays: quietCount,
                isOpen: true))
            verdict = .dark
        }

        var daysSince: Int? = nil
        if let lastKey = lastRunDay, let lastDate = parseDay(lastKey) {
            daysSince = Int(startOfUTCDay(now).timeIntervalSince(lastDate) / 86400)
        }

        let restarts = reapedByDay
            .sorted { $0.key < $1.key }
            .map { AMORPlaneRestart(day: $0.key, reapedRuns: $0.value) }

        return AMORPlaneReport(verdict: verdict, days: days, outages: outages,
                               restarts: restarts, lastRunDay: lastRunDay,
                               daysSinceLastRun: daysSince, isAvailable: true)
    }
}
