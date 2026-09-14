//
//  AMORSessionIndex.swift
//  Flow — AMOR v5.9.0
//
//  ┌─────────────────────────────────────────────────────────────┐
//  │          THE LIVING INDEX — v5.9.0 SESSION TRUTH            │
//  └─────────────────────────────────────────────────────────────┘
//
//  MISSION: the app's session plane was born reading
//  ~/.hermes/sessions/*.jsonl — a graveyard holding one stale
//  file and 596 API request-dumps. The REAL sessions (1,893+
//  at forging) live in ~/.hermes/state.db, and its own
//  sessions.json mirror says it plainly: "This is NOT the
//  session list." Since v2.1.0 the briefing's "sessions today",
//  the rhythm score, and the EOD dump have imported GHOSTS.
//
//  This engine restores the truth through two doors:
//
//    1. THE INDEX (iPhone path): FlowServer exports a lean
//       14-day projection of the sessions table as JSON —
//       relayed verbatim over the Open Vein and materialized
//       at hermes/sessions/index.json in the sandbox. state.db
//       itself is 671 MB; the index is ~100 KB. Evidence-plane
//       doctrine: bytes over the vein, law in the client.
//
//    2. THE LEDGER (Mac path): read state.db directly with the
//       law AMORExecutionTruth proved on this exact machine —
//       READWRITE open + immediate PRAGMA query_only=ON — never
//       SQLITE_OPEN_READONLY, which is flaky on a hot WAL.
//
//  Index-first, ledger-second: on the Mac the index usually
//  wins because the daemon just wrote it; on the iPhone the
//  ledger does not exist and the index is the only door.
//
//  Foundation + SQLite3 only — buildable by the CLT live-fire
//  harness (swiftc -sdk … -lsqlite3), same as the run-truth
//  engine. The SQL column list is BOUND BY LAW to the server's
//  export in AMORRelay.sessionIndexJSON() — leg 13 asserts the
//  two doors return the same count, so drift cannot survive.
//

import Foundation
import SQLite3

// MARK: - Index Row

/// One session in the living index — a projection of the
/// state.db `sessions` row, nothing more, nothing inferred.
struct AMORIndexedSession: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let source: String
    /// COALESCE(title, display_name, id) — never empty.
    let title: String
    /// Unix seconds.
    let startedAt: Double
    /// Unix seconds; nil while the session still runs.
    let endedAt: Double?
    /// Unix seconds of last observed activity (optional relay).
    let lastActivityAt: Double?
    let messageCount: Int
    let toolCallCount: Int
    /// Honest split from the messages table (correlated counts).
    let userMessageCount: Int
    let assistantMessageCount: Int
    let inputTokens: Int
    let outputTokens: Int
    let model: String

    /// Wall-clock minutes the session actually ran. Truthful:
    /// ended−started when both exist and are sane, else a floor
    /// of 1 (the session happened — it was not zero minutes).
    var durationMinutes: Int {
        if let end = endedAt, end > startedAt {
            return max(1, Int((end - startedAt) / 60))
        }
        if let last = lastActivityAt, last > startedAt {
            return max(1, Int((last - startedAt) / 60))
        }
        return 1
    }

    var startDate: Date { Date(timeIntervalSince1970: startedAt) }
}

// MARK: - Index Load Result

/// What the loader found, and through which door.
struct AMORSessionIndexResult: Sendable {
    let sessions: [AMORIndexedSession]
    /// "index" (vein-mirrored JSON) or "ledger" (direct SQLite).
    let origin: String
    var count: Int { sessions.count }
}

// MARK: - The Engine

enum AMORSessionIndex {

    /// How far back the index reaches. The server exports the
    /// same window; keep the two in lockstep or leg 13 burns.
    static let windowDays = 14
    static let indexRelPath = "sessions/index.json"
    static let stateDBRelPath = "state.db"

    // MARK: Public entry

    /// Index-first, ledger-second. Returns nil only when BOTH
    /// doors are dark (no mirror, no state.db) — the caller then
    /// falls back to the legacy jsonl scan.
    static func load(hermesHome: URL) -> AMORSessionIndexResult? {
        let indexURL = hermesHome.appendingPathComponent(indexRelPath)
        if let sessions = readIndex(at: indexURL), !sessions.isEmpty {
            return AMORSessionIndexResult(sessions: sessions, origin: "index")
        }
        if let sessions = readLedger(hermesHome: hermesHome), !sessions.isEmpty {
            return AMORSessionIndexResult(sessions: sessions, origin: "ledger")
        }
        return nil
    }

    // MARK: Door 1 — the mirrored index (iPhone path)

    /// Decodes the vein-materialized index. The server's sqlite3
    /// `-json` mode emits JSONL — one object per line (the 3.43
    /// CLI has no array mode) — so parse line-by-line; a true
    /// JSON array is also accepted for forward compatibility.
    /// Tolerant: a corrupt or absent file is darkness, never a
    /// crash, and malformed lines are skipped, never fatal.
    static func readIndex(at url: URL) -> [AMORIndexedSession]? {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Whole-payload array form (future servers may adopt it).
        if trimmed.hasPrefix("["),
           let data = trimmed.data(using: .utf8),
           let sessions = try? JSONDecoder().decode([AMORIndexedSession].self, from: data) {
            return sessions
        }

        // JSONL form — the wire law of v5.9.0.
        var sessions: [AMORIndexedSession] = []
        for line in trimmed.components(separatedBy: .newlines) {
            let clean = line.trimmingCharacters(in: .whitespaces)
            guard !clean.isEmpty else { continue }
            guard let data = clean.data(using: .utf8),
                  let session = try? JSONDecoder().decode(AMORIndexedSession.self, from: data) else {
                continue
            }
            sessions.append(session)
        }
        return sessions
    }

    // MARK: Door 2 — the live ledger (Mac path)

    /// Reads state.db directly with the proven WAL-safe law:
    /// READWRITE open + immediate `PRAGMA query_only=ON` (+
    /// busy_timeout). SQLITE_OPEN_READONLY is disqualified —
    /// flaky rc=14 while the gateway holds the WAL hot.
    ///
    /// The SELECT is LAW-BOUND to AMORRelay.sessionIndexJSON()
    /// on the server: same columns, same aliases, same window.
    /// Leg 13 asserts both doors agree.
    static func readLedger(hermesHome: URL) -> [AMORIndexedSession]? {
        let dbURL = hermesHome.appendingPathComponent(stateDBRelPath)
        guard FileManager.default.fileExists(atPath: dbURL.path) else { return nil }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK, let d = db else {
            sqlite3_close(db)
            return nil
        }
        defer { sqlite3_close(d) }

        // WAL LAW: open readwrite, then lock the door to writes.
        sqlite3_exec(d, "PRAGMA busy_timeout=3000;", nil, nil, nil)
        sqlite3_exec(d, "PRAGMA query_only=ON;", nil, nil, nil)

        let cutoff = Date().timeIntervalSince1970 - Double(windowDays * 86_400)
        let sql = """
        SELECT id, source, COALESCE(title, display_name, id) AS title,
               started_at AS startedAt, ended_at AS endedAt,
               last_activity_at AS lastActivityAt,
               message_count AS messageCount, tool_call_count AS toolCallCount,
               (SELECT COUNT(*) FROM messages m WHERE m.session_id = sessions.id AND m.role = 'user') AS userMessageCount,
               (SELECT COUNT(*) FROM messages m WHERE m.session_id = sessions.id AND m.role = 'assistant') AS assistantMessageCount,
               input_tokens AS inputTokens, output_tokens AS outputTokens,
               COALESCE(model, '') AS model
        FROM sessions
        WHERE started_at >= ? AND hidden = 0
        ORDER BY started_at DESC
        LIMIT 500
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(d, sql, -1, &stmt, nil) == SQLITE_OK, let s = stmt else {
            sqlite3_finalize(stmt)
            return nil
        }
        defer { sqlite3_finalize(s) }

        sqlite3_bind_double(s, 1, cutoff)

        var rows: [AMORIndexedSession] = []
        while sqlite3_step(s) == SQLITE_ROW {
            func colText(_ i: Int32) -> String {
                guard let c = sqlite3_column_text(s, i) else { return "" }
                return String(cString: c)
            }
            func colInt(_ i: Int32) -> Int { Int(sqlite3_column_int64(s, i)) }
            func colDouble(_ i: Int32) -> Double { sqlite3_column_double(s, i) }

            let endedAt: Double? = sqlite3_column_type(s, 4) == SQLITE_NULL ? nil : colDouble(4)
            let lastActivity: Double? = sqlite3_column_type(s, 5) == SQLITE_NULL ? nil : colDouble(5)

            rows.append(AMORIndexedSession(
                id: colText(0),
                source: colText(1),
                title: colText(2),
                startedAt: colDouble(3),
                endedAt: endedAt,
                lastActivityAt: lastActivity,
                messageCount: colInt(6),
                toolCallCount: colInt(7),
                userMessageCount: colInt(8),
                assistantMessageCount: colInt(9),
                inputTokens: colInt(10),
                outputTokens: colInt(11),
                model: colText(12)
            ))
        }
        return rows
    }
}
