//
//  AMORRelay.swift
//  FlowServer — AMOR v5.7.0
//
//  ┌─────────────────────────────────────────────────────────────┐
//  │            THE OPEN VEIN — v5.7.0 EVIDENCE RELAY            │
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
    }

    /// ISO 8601 timestamp of relay generation.
    let generatedAt: String
    let server: ServerInfo
    /// relative path ("hermes/logs/gita_progress.json",
    /// "wiki/raw/daily-summaries/session-dump-….md") → verbatim bytes.
    let files: [String: String]
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

        return AMOREvidenceResponse(
            generatedAt: isoNow(),
            server: AMOREvidenceResponse.ServerInfo(
                hermesHome: hermesHome().path,
                vaultPath: vault().path,
                host: host
            ),
            files: files,
            counts: AMOREvidenceResponse.Counts(files: files.count, jobs: jobs, enabledJobs: enabled, dumps: dumps)
        )
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
