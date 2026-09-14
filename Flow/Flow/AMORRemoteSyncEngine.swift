//
//  AMORRemoteSyncEngine.swift
//  Flow — AMOR v5.9.0
//
//  ┌─────────────────────────────────────────────────────────────┐
//  │   THE OPEN VEIN, CLIENT SIDE — v5.9.0 LIVING INDEX MIRROR   │
//  └─────────────────────────────────────────────────────────────┘
//
//  MISSION: AMOR's engines are filesystem-direct by law. On a
//  physical iPhone that law reads an empty sandbox — honest zeros,
//  but zeros. The Open Vein fixes this without touching ONE line
//  of engine law:
//
//    1. GET /api/v1/amor/evidence from FlowServer (on the Mac)
//    2. Materialize each verbatim file under the SANDBOX home at
//       the same relative path (`.hermes/logs/gita_progress.json`,
//       `wiki/raw/daily-summaries/session-dump-….md`, …)
//    3. Existing engines read the mirror and run their law as-is.
//
//  The laws stay in ONE place (the harness-compiled engines); the
//  phone becomes a mirror of the Mac's evidence plane.
//
//  Plus the WRITE path: POST /api/v1/amor/brain appends a block to
//  the real vault's daily note — the second brain, writable from
//  the phone for the first time.
//
//  Architecture: Foundation-only mirror materializer + async client.
//  No SwiftUI — type-checkable under CLT, harness-assertable.
//

import Foundation

// MARK: - Wire types (mirror of FlowServer AMORRelay)

struct AMOREvidenceFile: Codable, Sendable {
    let generatedAt: String
    struct ServerInfo: Codable, Sendable {
        let hermesHome: String
        let vaultPath: String
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
    let server: ServerInfo
    let files: [String: String]
    /// v5.8.0 — THE IRON PULSE: binary evidence (relative path →
    /// base64). Currently the run-ledger snapshot; the run-truth,
    /// storm-sentinel and alibi law read SQLite, not text.
    let binaryFiles: [String: String]
    let counts: Counts
}

struct AMORBrainAppend: Codable, Sendable {
    let date: String
    let heading: String
    let markdown: String
}

// MARK: - Result

/// What one remote sync accomplished — for the card + harness.
struct AMORRemoteSyncResult {
    let ok: Bool
    let filesMaterialized: Int
    let host: String
    let generatedAt: String
    let error: String?

    static func failure(_ message: String) -> AMORRemoteSyncResult {
        AMORRemoteSyncResult(ok: false, filesMaterialized: 0, host: "", generatedAt: "", error: message)
    }
}

// MARK: - Engine

/// The Open Vein client: fetch evidence, materialize the mirror.
/// No law here either — bytes onto disk, in the shape the engines expect.
enum AMORRemoteSyncEngine {

    // MARK: Configuration

    /// Where the engine prefers FlowServer when Info.plist is silent.
    /// v5.7.0: was a phantom `http://localhost:8085` default while the
    /// daemon actually serves :17777 — a fresh install talked to a ghost.
    static let defaultBaseURL = "http://127.0.0.1:17777"

    static func baseURL() -> String {
        let plist = Bundle.main.object(forInfoDictionaryKey: "FlowServerBaseURL") as? String
        if let plist, !plist.isEmpty { return plist }
        if let env = ProcessInfo.processInfo.environment["AMOR_FLOWSERVER_URL"], !env.isEmpty {
            return env
        }
        return defaultBaseURL
    }

    static func evidenceURL(base: String) -> URL? {
        URL(string: "\(base)/api/v1/amor/evidence")
    }

    static func brainURL(base: String) -> URL? {
        URL(string: "\(base)/api/v1/amor/brain")
    }

    // MARK: Sandbox mirror home

    /// The home the engines already treat as ground truth: `~` on macOS,
    /// the app container on iOS — `FileManager` resolves it per-platform.
    /// The mirror materializes evidence AT THE SAME RELATIVE PATHS the
    /// engines read (`.hermes/logs/…`, `wiki/raw/daily-summaries/…`),
    /// which on iOS is the app's private sandbox — never the Mac's files.
    static func defaultHome() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    /// Maps a relay key ("hermes/logs/gita_progress.json") to its
    /// materialization destination under `home` (".hermes/logs/…").
    /// Defense-in-depth: path traversal segments are dropped.
    static func mirrorDest(for rel: String, under home: URL) -> URL? {
        let parts = rel.split(separator: "/").filter { !$0.isEmpty && $0 != ".." && $0 != "." }
        guard let first = parts.first else { return nil }
        let rootName = first == "hermes" ? ".hermes" : String(first)
        var url = home.appendingPathComponent(rootName, isDirectory: true)
        for part in parts.dropFirst() {
            url = url.appendingPathComponent(String(part))
        }
        return url
    }

    // MARK: Sync (the read vein)

    /// Fetch evidence from FlowServer and materialize every file under the
    /// app sandbox home, at the exact paths the engines already read.
    /// Idempotent; safe to run on every scenePhase .active. Returns a
    /// digest for the card. `home` is injectable so the live-fire harness
    /// can mirror into a temp directory — LEDGER LAW: the harness never
    /// writes the real evidence plane.
    @discardableResult
    static func sync(base: String? = nil, home: URL? = nil) async -> AMORRemoteSyncResult {
        let base = base ?? baseURL()
        let home = home ?? defaultHome()
        guard let url = evidenceURL(base: base) else {
            return .failure("Invalid FlowServer URL")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            return .failure("FlowServer unreachable: \(error.localizedDescription)")
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return .failure("FlowServer rejected evidence: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        let payload: AMOREvidenceFile
        do {
            payload = try JSONDecoder().decode(AMOREvidenceFile.self, from: data)
        } catch {
            return .failure("Evidence decode failed: \(error.localizedDescription)")
        }

        let written = materialize(payload: payload, under: home)

        let defaults = UserDefaults.standard
        defaults.set(Date().timeIntervalSince1970, forKey: lastRemoteSyncKey)
        defaults.set(payload.server.host, forKey: lastMirrorHostKey)

        return AMORRemoteSyncResult(
            ok: true,
            filesMaterialized: written,
            host: payload.server.host,
            generatedAt: payload.generatedAt,
            error: nil
        )
    }

    /// Writes every evidence file under the given home, at the exact
    /// relative paths the engines already read. Returns count written.
    static func materialize(payload: AMOREvidenceFile, under home: URL) -> Int {
        var written = 0
        let fm = FileManager.default

        for (rel, content) in payload.files {
            guard let dest = mirrorDest(for: rel, under: home) else { continue }
            let dir = dest.deletingLastPathComponent()
            do {
                // TRUE IDEMPOTENCE (LEDGER LAW): when the destination
                // already holds these exact bytes — the Mac case, where
                // the mirror meets the real evidence plane — we write
                // nothing. The vein never re-touches unchanged evidence.
                if let existing = try? String(contentsOf: dest, encoding: .utf8),
                   existing == content {
                    written += 1
                    continue
                }
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                try content.write(to: dest, atomically: true, encoding: .utf8)
                written += 1
            } catch {
                // One unreadable file never sinks the whole mirror.
                continue
            }
        }

        // v5.8.0 — THE IRON PULSE: binary evidence (SQLite snapshots).
        written += materializeBinary(payload: payload, under: home)

        return written
    }

    // MARK: Binary mirror law (v5.8.0)

    /// Sidecar marker stamped next to every binary file the vein
    /// writes: `<name>.vein`. Presence of the marker is the ONLY
    /// proof a binary file belongs to the mirror.
    static let veinMarkerSuffix = "vein"

    /// v5.8.0: binary mirror law — base64 → raw bytes on disk.
    ///
    /// MARKER LAW (the Mac must never be wounded): a binary
    /// destination that exists WITHOUT our marker is LIVE evidence —
    /// the Mac's own run ledger — and is never clobbered by the
    /// mirror. The iPhone sandbox has no such file, so it receives
    /// the snapshot; the Mac's live ledger is untouchable. Idempotence
    /// for marked mirrors: same bytes → no write.
    static func materializeBinary(payload: AMOREvidenceFile, under home: URL) -> Int {
        guard !payload.binaryFiles.isEmpty else { return 0 }
        let fm = FileManager.default
        var written = 0

        for (rel, b64) in payload.binaryFiles {
            guard let data = Data(base64Encoded: b64), !data.isEmpty else { continue }
            guard let dest = mirrorDest(for: rel, under: home) else { continue }
            let dir = dest.deletingLastPathComponent()
            let marker = dest.appendingPathExtension(veinMarkerSuffix)

            do {
                let exists = fm.fileExists(atPath: dest.path)
                let marked = fm.fileExists(atPath: marker.path)
                if exists && !marked {
                    // Live evidence — the Mac's own ledger. Untouchable.
                    continue
                }
                if exists && marked {
                    // Our mirror: idempotence — same bytes, no write.
                    if fm.contents(atPath: dest.path) == data {
                        written += 1
                        continue
                    }
                }
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                try data.write(to: dest, options: .atomic)
                try "vein".write(to: marker, atomically: true, encoding: .utf8)
                written += 1
            } catch {
                // One failed binary never sinks the whole mirror.
                continue
            }
        }
        return written
    }

    static let lastRemoteSyncKey = "amor.remote.lastSyncAt"
    static let lastMirrorHostKey = "amor.remote.lastHost"

    // MARK: Brain write (the write vein)

    /// Appends a heading block to the real vault daily note, via the server.
    static func appendToBrain(
        date: String,
        heading: String,
        markdown: String,
        base: String? = nil
    ) async -> Bool {
        let base = base ?? baseURL()
        guard let url = brainURL(base: base) else { return false }

        let body = AMORBrainAppend(date: date, heading: heading, markdown: markdown)
        guard let encoded = try? JSONEncoder().encode(body) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = encoded
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
