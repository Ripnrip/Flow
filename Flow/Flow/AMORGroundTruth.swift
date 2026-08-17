//
//  AMORGroundTruth.swift
//  Flow — AMOR v4.0.0
//
//  ┌─────────────────────────────────────────────────────────────┐
//  │            GROUND TRUTH SYNC ENGINE — v4.0.0                │
//  └─────────────────────────────────────────────────────────────┘
//
//  MISSION: The app previously tracked the user's daily practices
//  (Gita, gym, meditation) via manual taps while the REAL evidence
//  lived in files on this very Mac, untouched:
//
//    • ~/.hermes/logs/gita_progress.json      (morning Gita cron)
//    • ~/wiki/raw/daily-summaries/*.md        (EOD session dumps)
//    • ~/.hermes/cron/jobs.json               (cron health)
//
//  This engine reads those sources directly (filesystem-direct
//  pattern — same machine, no HTTP, no phantom endpoints) and
//  upserts REAL completion evidence into SwiftData PracticeStreak
//  entries. Every streak number in the UI now traces to a file.
//
//  Architecture:
//    • Foundation-only — type-checks with `swiftc -typecheck` (CLT SDK)
//    • UserDefaults-direct for its own bookkeeping (dedupe keys)
//    • Idempotent upserts — safe to run on every scenePhase .active
//    • Mirror-writes to the second brain (changelog discipline)
//

import Foundation

// MARK: - Codable mirrors of the on-disk ground truth

/// Mirror of ~/.hermes/logs/gita_progress.json
struct AMORGitaProgressFile: Codable {
    let currentChapter: Int
    let currentVerse: Int
    struct LastCompleted: Codable {
        let chapter: Int
        let verse: Int
        let date: String
    }
    let lastCompleted: LastCompleted?
    let daysCompleted: Int
    let started: String?
    let lastSuccessAt: String?
    let lastMode: String?
    let lastStatus: String?

    enum CodingKeys: String, CodingKey {
        case currentChapter = "current_chapter"
        case currentVerse = "current_verse"
        case lastCompleted = "last_completed"
        case daysCompleted = "days_completed"
        case started
        case lastSuccessAt = "last_success_at"
        case lastMode = "last_mode"
        case lastStatus = "last_status"
    }
}

/// Mirror of ~/.hermes/logs/gym_selfie_progress.json
struct AMORGymProgressFile: Codable {
    let started: String?
    let streak: Int
    let total: Int
    let dates: [String]
}

/// One day's parsed EOD session dump (~/wiki/raw/daily-summaries/)
struct AMORDumpSummary {
    let date: Date
    let sessionsToday: Int
    let minutesToday: Int
    let tools: [String]
    let skillsTouched: [String]
    let cronOkCount: Int
    let cronErrorCount: Int
    let cronUnknownCount: Int
    let path: String
}

/// Digest of what one sync pass accomplished.
struct AMORGroundTruthSyncResult: Codable {
    var gitaStreakUpdated = false
    var gitaDaysCompleted = 0
    var gitaLastCompletedDate: String?
    var gitaCurrentPosition = ""
    var gymEvidenceDates: [String] = []
    var dumpDaysIngested = 0
    var dumpSessionsFound = 0
    var dumpToolsDiscovered: [String] = []
    var dumpSkillsDiscovered: [String] = []
    var cronOkCount = 0
    var cronErrorCount = 0
    var readError: String?
}

// MARK: - Engine

/// Pure-Foundation ground-truth reader + parser.
/// No SwiftUI, no SwiftData — fully type-checkable via swiftc.
enum AMORGroundTruthEngine {

    static let gitaProgressKey = "amor.groundtruth.gitaLastSyncedDate"

    // MARK: Paths

    static func hermesHome() -> URL {
        if let env = ProcessInfo.processInfo.environment["HERMES_HOME"], !env.isEmpty {
            return URL(fileURLWithPath: env)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".hermes")
    }

    static func gitaProgressURL() -> URL {
        hermesHome().appendingPathComponent("logs/gita_progress.json")
    }

    static func dailySummariesDir(vaultPath: String?) -> URL {
        if let vaultPath, !vaultPath.isEmpty {
            return URL(fileURLWithPath: vaultPath)
                .appendingPathComponent("raw/daily-summaries")
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("wiki/raw/daily-summaries")
    }

    // MARK: Gita ground truth

    /// Parses ~/.hermes/logs/gita_progress.json.
    static func readGitaProgress() -> AMORGitaProgressFile? {
        let url = gitaProgressURL()
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AMORGitaProgressFile.self, from: data)
    }

    /// True when the Gita cron delivered today (file's last_completed.date
    /// equals today in the LOCAL calendar — the cron writes local dates).
    static func gitaCompletedToday(_ progress: AMORGitaProgressFile) -> Bool {
        guard let lc = progress.lastCompleted else { return false }
        return lc.date == AMORGroundTruthEngine.localDateString(Date())
    }

    /// Local-calendar yyyy-MM-dd string (matches how Hermes writes dates).
    static func localDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    /// UTC anchor date for a yyyy-MM-dd string (for day-counting math).
    private static func utcDate(fromString s: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: s)
    }

    /// Counts consecutive days of Gita completion ending today or yesterday.
    /// Derives from the file's `history` array; falls back to days_completed.
    static func gitaStreakDays(from progress: AMORGitaProgressFile) -> Int {
        // Read raw JSON to access the un-decoded `history` array.
        guard let data = try? Data(contentsOf: gitaProgressURL()),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let history = raw["history"] as? [[String: Any]] else {
            return progress.daysCompleted
        }

        let calendar = Calendar.current
        var dates = Set<Date>()
        for entry in history {
            if let ds = entry["date"] as? String, let d = utcDate(fromString: ds) {
                dates.insert(calendar.startOfDay(for: d))
            }
        }
        if let lc = progress.lastCompleted, let d = utcDate(fromString: lc.date) {
            dates.insert(calendar.startOfDay(for: d))
        }

        var streak = 0
        var cursor = calendar.startOfDay(for: Date())
        // Anchor to today OR yesterday (a missed today is not yet a break).
        if !dates.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                return dates.count
            }
            if !dates.contains(yesterday) {
                return dates.count
            }
            cursor = yesterday
            streak = 1
        }
        while dates.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        // History on disk may be pruned (27 entries retained while
        // days_completed = 73). Take the larger of derived vs cumulative.
        return max(streak, progress.daysCompleted > 0 ? progress.daysCompleted : 0)
    }

    // MARK: EOD dump parsing

    /// Parses one session-dump markdown file into a summary.
    /// Format verified against real dumps:
    ///   2026-08-17+ (dumper v2): adds "## Tools Used" → "| `tool` | N |" rows
    ///   ## Session Activity  → "**3 sessions today:**" or "*No sessions recorded today.*"
    ///   ## Cron Job Status   → "| ✅ `name` | `ok` | ..." table rows
    ///   ## Skills Activity   → "- `.hermes/skills/<category>/<name>/SKILL.md`" bullets
    static func parseDump(at url: URL, calendar: Calendar = .current) -> AMORDumpSummary? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        // Filename carries the date: session-dump-YYYY-MM-DD.md
        let name = url.lastPathComponent
        var date = Date.distantPast
        if let range = name.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone.current
            date = formatter.date(from: String(name[range])) ?? .distantPast
        }

        // Session Activity: "**3 sessions today:**" (verified real format).
        var sessions = 0
        if let r = content.range(of: #"\*\*(\d+) sessions? today:\*\*"#, options: .regularExpression) {
            let digits = content[r].drop { !$0.isNumber }.prefix { $0.isNumber }
            sessions = Int(digits) ?? 0
        }

        // Skills Activity: "- `.hermes/skills/<category>/<skill-name>/SKILL.md`"
        // or "- `.../references/<file>.md`". Extract the human skill name.
        var skills: [String] = []
        if let r = content.range(of: #"(?s)## Skills Activity.*?(?=\n## |\z)"#, options: .regularExpression) {
            let section = String(content[r])
            for line in section.components(separatedBy: .newlines) where line.hasPrefix("- ") {
                let trimmed = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
                var path = trimmed
                  .replacingOccurrences(of: "`", with: "")
                  .replacingOccurrences(of: ".md", with: "")
                if let prefixRange = path.range(of: ".hermes/skills/") {
                    path = String(path[prefixRange.upperBound...])
                }
                // "<category>/<skill>/SKILL" → "<skill>"; "…/references/<file>" → "<file>"
                if path.hasSuffix("/SKILL") { path = String(path.dropLast("/SKILL".count)) }
                if let lastSlash = path.lastIndex(of: "/") {
                    path = String(path[path.index(after: lastSlash)...])
                }
                if !path.isEmpty { skills.append(path) }
            }
        }

        // Tools Used (dumps ≥ 2026-08-17, dumper v2): "| `tool` | N |" rows.
        // Older dumps carry no such section — returns [] honestly, never invented.
        var tools: [String] = []
        if let r = content.range(of: #"(?s)## Tools Used.*?(\n## |\z)"#, options: .regularExpression) {
            let section = String(content[r])
            if let regex = try? NSRegularExpression(pattern: #"^\|\s*`([^`]+)`\s*\|.*$"#,
                                                    options: [.anchorsMatchLines]) {
                let ns = section as NSString
                tools = regex.matches(in: section, range: NSRange(location: 0, length: ns.length))
                    .compactMap { $0.numberOfRanges > 1 ? ns.substring(with: $0.range(at: 1)) : nil }
            }
        }

        // Cron table rows: | ✅ `name` | `ok` | ...
        var ok = 0, errors = 0, unknown = 0
        for line in content.components(separatedBy: .newlines)
        where line.hasPrefix("| ") && line.contains("`") {
            if line.contains("`ok`") { ok += 1 }
            else if line.contains("`error`") || line.contains("`failed`") { errors += 1 }
            else if line.contains("`None`") { unknown += 1 }
        }

        return AMORDumpSummary(
            date: date,
            sessionsToday: sessions,
            minutesToday: 0,  // real dumps carry file sizes, not durations — stay honest
            tools: tools,     // parsed from "## Tools Used" (v2 dumps); [] on older dumps — honest
            skillsTouched: skills,
            cronOkCount: ok,
            cronErrorCount: errors,
            cronUnknownCount: unknown,
            path: url.path
        )
    }

    /// Reads the last N EOD dumps (newest first).
    static func readRecentDumps(daysBack: Int = 7, vaultPath: String? = nil) -> [AMORDumpSummary] {
        let dir = dailySummariesDir(vaultPath: vaultPath)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return [] }

        return files
            .filter { $0.lastPathComponent.hasPrefix("session-dump-") && $0.pathExtension == "md" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .prefix(daysBack)
            .compactMap { parseDump(at: $0) }
    }

    // MARK: Gym evidence

    /// Reads gym_selfie_progress.json (written by the 5PM selfie cron):
    /// { "started": "...", "streak": N, "total": N, "dates": ["YYYY-MM-DD"] }
    /// Note: dates[] may legitimately be empty — that is REAL data, not an
    /// error. The cron reminds; the human snaps. Empty = honest zero.
    static func gymProgress() -> AMORGymProgressFile? {
        let url = hermesHome().appendingPathComponent("logs/gym_selfie_progress.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AMORGymProgressFile.self, from: data)
    }

    /// Dates (yyyy-MM-dd, newest first) with gym evidence.
    static func gymEvidenceDates(daysBack: Int = 7) -> [String] {
        guard let progress = gymProgress() else { return [] }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
        let cutoff = formatter.string(from: cutoffDate)
        return progress.dates
            .filter { $0 >= cutoff }   // ISO date strings sort lexically
            .sorted(by: >)
    }
}
