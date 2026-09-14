//
//  AMORRelay.swift
//  FlowServer — AMOR v5.9.0
//
//  ┌─────────────────────────────────────────────────────────────┐
//  │   THE OPEN VEIN + IRON PULSE + LIVING INDEX — v5.9.0        │
//  └─────────────────────────────────────────────────────────────┘
//
//  MISSION: AMOR's engines are filesystem-direct — they read the
//  Mac's ledgers at ~/.hermes/... and ~/wiki/... On the simulator
//  AND on a physical iPhone there is no shared filesystem: the
//  ground-truth card has been reading an empty sandbox since the
//  day it was forged (honest zeros, but zeros).
//
//  This relay ships the evidence VERBATIM — no law on the server.
//  The client materializes each file at the same RELATIVE path
//  under its own sandbox home, and the existing engines
//  (AMORGroundTruthSyncer, AMORCronStatusReader, the dump parser,
//  the second-brain manager) read the mirror without a single
//  change to their law. One home for the law; the harness keeps
//  guarding it.
//
//  Endpoints:
//    GET  /api/v1/amor/evidence  — flat map of relative path →
//                                  verbatim file content
//    POST /api/v1/amor/brain     — append a block to the vault's
//                                  daily note (ledger law:
//                                  append-only, never overwrite)
//
//  Architecture: static, stateless, Sendable. Swift 6 mode safe.
//

import Foundation
import Hummingbird

// MARK: - Wire types

/// The evidence payload: everything AMOR's engines need, verbatim.
struct AMOREvidenceResponse: Codable, Sendable, ResponseEncodable {
    struct ServerInfo: Codable, Sendable {
        /// Absolute path of the relayed ~/.hermes on the Mac.
        let hermesHome: String
        /// Absolute path of the relayed ~/wiki vault on the Mac.
        let vaultPath: String
        /// Bonjour/local host name — so the app can say whose Mac it mirrored.
        let host: String
    }

    struct Counts: Codable, Sendable {
        let files: Int
        let jobs: Int
        let enabledJobs: Int
        let dumps: Int
        /// v5.8.0: the run ledger snapshot shipped in `binaryFiles`.
        let executionsDB: Bool
        /// v5.8.0: total rows in the relayed executions ledger.
        let executionRows: Int
    }

    /// ISO 8601 timestamp of relay generation.
    let generatedAt: String
    let server: ServerInfo
    /// relative path ("hermes/logs/gita_progress.json",
    /// "wiki/raw/daily-summaries/session-dump-….md") → verbatim bytes.
    let files: [String: String]
    /// v5.8.0 — THE IRON PULSE: binary evidence, relative path →
    /// base64 bytes. Currently one entry: a consistent `VACUUM INTO`
    /// snapshot of `hermes/cron/executions.db`. The run-truth engine
    /// (and the alibi + storm law downstream) reads SQLite, not text —
    /// without this field the iPhone's run ledger has been dark.
    let binaryFiles: [String: String]
    let counts: Counts
}

/// Append request for the second-brain daily note.
struct AMORBrainWriteRequest: Codable, Sendable {
    /// Local day, yyyy-MM-dd (validated — never a path component).
    let date: String
    /// Markdown heading for the appended block.
    let heading: String
    /// Markdown body for the appended block.
    let markdown: String
}

/// Confirmation of a brain write.
struct AMORBrainWriteResponse: Codable, Sendable, ResponseEncodable {
    let message: String
    let path: String
    let bytes: Int
}

// MARK: - Relay

/// Stateless ground-truth relay. No law lives here — bytes only.
enum AMORRelay {

    // MARK: Paths

    static func userHome() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    static func hermesHome() -> URL {
        userHome().appendingPathComponent(".hermes")
    }

    static func vault() -> URL {
        userHome().appendingPathComponent("wiki")
    }

    /// Local yyyy-MM-dd (matches how Hermes and the ledgers write dates).
    static func localDay(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    static func isoNow() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }

    // MARK: GET /api/v1/amor/evidence

    static func evidence() -> AMOREvidenceResponse {
        var files: [String: String] = [:]

        // ── Hermes ledgers + scheduler truth (verbatim) ───────────
        let hermesFiles = [
            "logs/gita_progress.json",
            "logs/gym_selfie_progress.json",
            "logs/meditation_progress.json",
            "cron/jobs.json",
        ]
        for rel in hermesFiles {
            if let content = readText(at: hermesHome().appendingPathComponent(rel)) {
                files["hermes/\(rel)"] = content
            }
        }

        // ── v5.9.0 THE LIVING INDEX — session truth over the vein ──
        // The app's session plane was born reading sessions/*.jsonl —
        // a graveyard (one stale file, 596 API request-dumps). The
        // real sessions live in state.db (671 MB at forging — far too
        // fat for the vein). This export projects the trailing 14
        // days of the sessions table into ~100 KB of JSON relayed as
        // plain text. LAW-BOUND to AMORSessionIndex.readLedger() in
        // the shipped client: same columns, aliases, window, limit —
        // leg 13 asserts both doors agree.
        if let index = sessionIndexJSON() {
            files["hermes/sessions/index.json"] = index
        }

        // ── EOD session dumps, newest 7 (the dump parser's diet) ─
        var dumps = 0
        let dumpDir = vault().appendingPathComponent("raw/daily-summaries")
        if let names = try? FileManager.default.contentsOfDirectory(atPath: dumpDir.path) {
            let sorted = names
                .filter { $0.hasPrefix("session-dump-") && $0.hasSuffix(".md") }
                .sorted(by: >)
            for name in sorted.prefix(7) {
                if let content = readText(at: dumpDir.appendingPathComponent(name)) {
                    files["wiki/raw/daily-summaries/\(name)"] = content
                    dumps += 1
                }
            }
        }

        // ── Today's daily note + the vault changelog (Brain tab) ─
        let today = localDay()
        if let note = readText(at: vault().appendingPathComponent("daily/\(today).md")) {
            files["wiki/daily/\(today).md"] = note
        }
        if let changelog = readText(at: vault().appendingPathComponent("changelog.md")) {
            files["wiki/changelog.md"] = changelog
        }

        // ── Counts (quick asserts for the harness and the app UI) ─
        var jobs = 0
        var enabled = 0
        if let raw = files["hermes/cron/jobs.json"],
           let data = raw.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let jobArray = object["jobs"] as? [[String: Any]] {
            jobs = jobArray.count
            enabled = jobArray.filter { ($0["enabled"] as? Bool) ?? false }.count
        }

        let host = Host.current().localizedName ?? "mac"

        // ── v5.8.0 THE IRON PULSE: run-ledger snapshot ────────────────
        // The run-truth engine reads SQLite, not text. Relay a CONSISTENT
        // snapshot of the live executions ledger via the Online Backup
        // API — a point-in-time copy that escapes the WAL trap (a raw
        // snapshot of a WAL-mode db can miss recent commits, and a
        // readonly connection refuses VACUUM INTO outright). Zero new
        // server deps: the system sqlite3 CLI does the backup.
        var binaryFiles: [String: String] = [:]
        var executionRows = 0
        if let snapshot = executionSnapshot() {
            binaryFiles["hermes/cron/executions.db"] = snapshot.base64
            executionRows = snapshot.rows
        }

        return AMOREvidenceResponse(
            generatedAt: isoNow(),
            server: AMOREvidenceResponse.ServerInfo(
                hermesHome: hermesHome().path,
                vaultPath: vault().path,
                host: host
            ),
            files: files,
            binaryFiles: binaryFiles,
            counts: AMOREvidenceResponse.Counts(
                files: files.count,
                jobs: jobs,
                enabledJobs: enabled,
                dumps: dumps,
                executionsDB: !binaryFiles.isEmpty,
                executionRows: executionRows
            )
        )
    }

    // MARK: Executions ledger snapshot (v5.8.0)

    /// One vacuumed snapshot of the run ledger: base64 bytes + row count.
    private struct ExecutionSnapshot {
        let base64: String
        let rows: Int
    }

    /// Snapshots the live ledger into a temp file via the system
    /// sqlite3 CLI using the Online Backup API (`.backup`), then reads
    /// it back as base64. Physics (live-proven on this box, WAL state
    /// fluctuating with live cron writers):
    ///   • `-readonly` on a WAL db is FLAKY — error 14 while -shm/-wal
    ///     are hot, fine after a checkpoint. Unreliable = disqualified.
    ///   • `VACUUM INTO` is refused by readonly (14) and query_only (8).
    ///   • READWRITE open + `PRAGMA query_only=ON` + `.backup` ALWAYS
    ///     works: query_only guarantees no SQL writes, and the backup
    ///     API writes only the destination. This is the same law the
    ///     v4.8.0 client engine proved on this exact ledger.
    /// Returns nil when the ledger is missing or the backup fails —
    /// a dark run plane degrades to "no binary evidence", never a 500.
    private static func executionSnapshot() -> ExecutionSnapshot? {
        let source = hermesHome().appendingPathComponent("cron/executions.db")
        guard FileManager.default.fileExists(atPath: source.path) else { return nil }

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("amor-exec-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            source.path,
            "-cmd", "PRAGMA query_only=ON;",
            ".backup '\(tmp.path)'"
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }

        guard let data = FileManager.default.contents(atPath: tmp.path),
              !data.isEmpty else { return nil }

        // Row count from the snapshot itself — the harness asserts on it.
        var rows = 0
        let count = Process()
        count.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        count.arguments = [tmp.path, "SELECT COUNT(*) FROM executions;"]
        let pipe = Pipe()
        count.standardOutput = pipe
        count.standardError = FileHandle.nullDevice
        if (try? count.run()) != nil {
            count.waitUntilExit()
            if count.terminationStatus == 0,
               let out = try? pipe.fileHandleForReading.readToEnd(),
               let text = String(data: out, encoding: .utf8),
               let parsed = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                rows = parsed
            }
        }

        return ExecutionSnapshot(base64: data.base64EncodedString(), rows: rows)
    }

    // MARK: Session index export (v5.9.0)

    /// Projects the trailing 14 days of state.db's sessions table
    /// into a JSON array via the system sqlite3 CLI. Same WAL-safe
    /// physics as the executions snapshot: `PRAGMA query_only=ON`
    /// as a dot-command so no SQL write can ever occur. Wire-format
    /// LAW (live-proven on this box's sqlite 3.43.2): `-json` emits
    /// ONE pretty-printed JSON ARRAY wrapped in [ ], with a comma
    /// and newline between rows — NOT JSONL (that arrived in 3.45;
    /// this CLI is 3.43). And `PRAGMA busy_timeout=3000;` ECHOES
    /// "3000" to stdout, polluting the payload — use the silent
    /// `.timeout 3000` dot-command instead. The cutoff is inlined
    /// as a %.6f numeric literal: digits and a dot only, nothing
    /// user-controlled ever touches the SQL text. Keys are the
    /// exact aliases AMORSessionIndex decodes; leg 13 asserts both
    /// doors agree.
    private static func sessionIndexJSON() -> String? {
        let dbPath = hermesHome().appendingPathComponent("state.db").path
        guard FileManager.default.fileExists(atPath: dbPath) else { return nil }

        let cutoff = Date().timeIntervalSince1970 - Double(14 * 86_400)
        let cutoffLiteral = String(format: "%.6f", cutoff)
        // Defense-in-depth: the literal is machine-formatted, but
        // refuse anything that is not a plain number anyway.
        guard cutoffLiteral.range(of: "^[0-9.]+$", options: .regularExpression) != nil else {
            return nil
        }

        let sql = """
        SELECT id, source, COALESCE(title, display_name, id) AS title, \
        started_at AS startedAt, ended_at AS endedAt, \
        last_activity_at AS lastActivityAt, \
        message_count AS messageCount, tool_call_count AS toolCallCount, \
        (SELECT COUNT(*) FROM messages m WHERE m.session_id = sessions.id AND m.role = 'user') AS userMessageCount, \
        (SELECT COUNT(*) FROM messages m WHERE m.session_id = sessions.id AND m.role = 'assistant') AS assistantMessageCount, \
        (COALESCE(input_tokens, 0) + COALESCE(cache_read_tokens, 0)) AS inputTokens, \
        COALESCE(output_tokens, 0) AS outputTokens, \
        COALESCE(model, '') AS model \
        FROM sessions \
        WHERE started_at >= \(cutoffLiteral) AND hidden = 0 \
        ORDER BY started_at DESC \
        LIMIT 500;
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            dbPath,
            "-cmd", ".timeout 3000",
            "-cmd", "PRAGMA query_only=ON;",
            "-json",
            sql,
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        // PIPE LAW: the index (~100 KB) exceeds the 64 KB pipe
        // buffer — readToEnd BEFORE waitUntilExit, or sqlite3 blocks
        // writing while we block reaping: deadlock. readToEnd blocks
        // until EOF (process exit closes the pipe), so waitUntilExit
        // returns immediately after.
        let data = (try? pipe.fileHandleForReading.readToEnd()) ?? Data()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        guard !data.isEmpty else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: POST /api/v1/amor/brain

    /// Appends a heading block to the vault's daily note.
    /// LEDGER LAW: append-only — an existing note is never rewritten,
    /// only extended (same separator law as AMORSecondBrainManager).
    static func writeBrain(_ request: AMORBrainWriteRequest) throws -> AMORBrainWriteResponse {
        // Validate date BEFORE it touches the filesystem.
        let dayPattern = "^\\d{4}-\\d{2}-\\d{2}$"
        guard request.date.range(of: dayPattern, options: .regularExpression) != nil else {
            throw HTTPError(.badRequest)
        }
        guard !request.heading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !request.markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              request.markdown.count <= 20_000 else {
            throw HTTPError(.badRequest)
        }

        let dailyDir = vault().appendingPathComponent("daily")
        try FileManager.default.createDirectory(at: dailyDir, withIntermediateDirectories: true)
        let fileURL = dailyDir.appendingPathComponent("\(request.date).md")

        let block = "## \(request.heading)\n\n\(request.markdown.trimmingCharacters(in: .whitespacesAndNewlines))\n"

        let combined: String
        if FileManager.default.fileExists(atPath: fileURL.path),
           let existing = readText(at: fileURL) {
            combined = existing + "\n\n---\n\n" + block
        } else {
            combined = block
        }

        do {
            try combined.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw HTTPError(.internalServerError)
        }

        let bytes = (combined.data(using: .utf8)?.count ?? 0)
        return AMORBrainWriteResponse(
            message: "Appended \(request.heading) to daily/\(request.date).md",
            path: fileURL.path,
            bytes: bytes
        )
    }

    // MARK: Helpers

    static func readText(at url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }
}
