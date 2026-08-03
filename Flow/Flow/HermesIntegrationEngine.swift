/**
 * 🌉 HermesIntegrationEngine — The Bridge Between Worlds
 *
 * "Where the digital exhalations of Hermes flow into the contemplative
 * halls of AMOR. Sessions breathe in, practices align, and the pulse
 * of automation is felt rather than merely observed."
 *
 * Architecture: Foundation-only engine (no SwiftUI). Reads Hermes data
 * directly from the local filesystem (~/.hermes/) when running on the
 * same Mac. Converts session JSONL files and cron job status into
 * AMOR's SwiftData models.
 *
 * v2.1.0 — Session-Dump Automation & Real Hermes Integration
 */

import Foundation
import SwiftData
import Combine

// MARK: - Data Structures

/// Represents a parsed Hermes conversation session from JSONL files.
struct HermesSession: Codable, Identifiable {
    let id: String           // filename without extension
    let date: Date           // first message timestamp
    let lastActivity: Date   // last message timestamp
    let messageCount: Int    // total user+assistant messages
    let userMessageCount: Int
    let assistantMessageCount: Int
    let title: String        // derived from first user message
    let toolsAvailable: [String]  // tool names from session_meta
    let estimatedDurationMinutes: Int
    let firstUserMessage: String

    /// Infers the primary tool/domain from the title and tool list
    var inferredDomain: String {
        let lowerTitle = title.lowercased()
        if lowerTitle.contains("swift") || lowerTitle.contains("ios") || lowerTitle.contains("xcode") { return "iOS Development" }
        if lowerTitle.contains("python") || lowerTitle.contains("django") || lowerTitle.contains("flask") { return "Python" }
        if lowerTitle.contains("docker") || lowerTitle.contains("kubernetes") || lowerTitle.contains("deploy") { return "DevOps" }
        if lowerTitle.contains("git") || lowerTitle.contains("github") || lowerTitle.contains("pr ") { return "Git" }
        if lowerTitle.contains("react") || lowerTitle.contains("javascript") || lowerTitle.contains("typescript") { return "Web Dev" }
        if lowerTitle.contains("hermes") || lowerTitle.contains("agent") || lowerTitle.contains("cron") { return "Hermes" }
        if lowerTitle.contains("gita") || lowerTitle.contains("meditat") || lowerTitle.contains("practice") { return "Practice" }
        if lowerTitle.contains("research") || lowerTitle.contains("paper") || lowerTitle.contains("arxiv") { return "Research" }
        if lowerTitle.contains("write") || lowerTitle.contains("blog") || lowerTitle.contains("article") { return "Writing" }
        return "General"
    }

    /// Infers tools used from title keywords
    var inferredTools: String {
        var tools: [String] = []
        let lower = (title + " " + firstUserMessage).lowercased()
        let toolMap: [(keyword: String, tool: String)] = [
            ("swift", "Swift"), ("ios", "Xcode"), ("xcode", "Xcode"),
            ("python", "Python"), ("django", "Django"), ("flask", "Flask"),
            ("docker", "Docker"), ("kubernetes", "K8s"), ("deploy", "Deployment"),
            ("git", "Git"), ("github", "GitHub"), ("pull request", "GitHub"),
            ("react", "React"), ("typescript", "TypeScript"),
            ("hermes", "Hermes"), ("agent", "Hermes"), ("cron", "Cron"),
            ("terminal", "Terminal"), ("shell", "Shell"),
            ("browser", "Browser"), ("web", "Web"),
            ("obsidian", "Obsidian"), ("markdown", "Markdown"),
            ("api", "API"), ("database", "Database"), ("postgres", "PostgreSQL"),
            ("ml", "ML"), ("ai", "AI"), ("model", "AI Model"),
            ("gita", "Gita"), ("meditat", "Meditation"),
            ("tail", "Tailscale"), ("ssh", "SSH"),
            ("latex", "LaTeX"), ("paper", "Research"),
        ]
        for entry in toolMap {
            if lower.contains(entry.keyword) {
                if !tools.contains(entry.tool) {
                    tools.append(entry.tool)
                }
            }
        }
        return tools.isEmpty ? "Hermes" : tools.joined(separator: ", ")
    }

    var hasToolUse: Bool {
        messageCount > 4 // heuristic: sessions with tool calls tend to have more messages
    }
}

/// Represents a cron job's health status parsed from Hermes.
struct HermesCronJob: Codable, Identifiable {
    let id: String
    let name: String
    let schedule: String
    let lastRun: Date?
    let lastStatus: String    // "ok", "failed", "pending"
    let isActive: Bool
    let nextRun: Date?

    var statusEmoji: String {
        switch lastStatus {
        case "ok": return "✅"
        case "failed": return "❌"
        case "pending": return "⏳"
        default: return "❓"
        }
    }

    var healthStatus: String {
        if !isActive { return "disabled" }
        guard let last = lastRun else { return "never_run" }
        let hoursAgo = Date().timeIntervalSince(last) / 3600
        if hoursAgo > 48 { return "stale" }
        if lastStatus == "failed" { return "warning" }
        return "healthy"
    }
}

// MARK: - Integration Engine

/// The main integration engine — reads Hermes data from the local filesystem
/// and syncs it into AMOR's SwiftData models.
///
/// Designed to run on the same Mac as Hermes (simulator or Mac Catalyst).
/// Gracefully degrades to no-op when the Hermes home directory is not found.
@Observable
final class HermesIntegrationEngine {

    // MARK: - Published State (for UI status display)

    /// Current sync status
    var syncStatus: SyncStatus = .idle

    /// Total sessions discovered in last scan
    var totalSessionsDiscovered = 0

    /// Sessions imported in last sync
    var sessionsImportedThisCycle = 0

    /// Total cron jobs discovered
    var totalCronJobsDiscovered = 0

    /// Last successful sync timestamp
    var lastSyncDate: Date?

    /// Whether Hermes home directory is accessible
    var isHermesAvailable: Bool = false

    /// Recently imported session previews (for dashboard card)
    var recentImports: [HermesSession] = []

    // MARK: - Configuration

    /// The Hermes home directory path. Defaults to ~/.hermes
    private let hermesHome: URL

    /// Sessions subdirectory
    private var sessionsDir: URL { hermesHome.appendingPathComponent("sessions") }

    /// UserDefaults key for tracking already-imported session IDs
    private let importedSessionsKey = "amor.importedHermesSessions"

    // MARK: - Combine

    var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        // Resolve Hermes home — check environment variable first, then default
        if let envPath = ProcessInfo.processInfo.environment["HERMES_HOME"] {
            self.hermesHome = URL(fileURLWithPath: envPath)
        } else {
            self.hermesHome = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".hermes")
        }

        self.isHermesAvailable = FileManager.default.fileExists(atPath: hermesHome.path)
    }

    // MARK: - Session Parsing

    /// Scans the Hermes sessions directory and parses all JSONL files.
    /// Returns sessions sorted by date (newest first).
    func discoverSessions(limit: Int = 100) -> [HermesSession] {
        guard FileManager.default.fileExists(atPath: sessionsDir.path) else {
            return []
        }

        guard let files = try? FileManager.default.contentsOfDirectory(at: sessionsDir, includingPropertiesForKeys: [.contentModificationDateKey], options: []) else {
            return []
        }

        let jsonlFiles = files
            .filter { $0.pathExtension == "jsonl" }
            .sorted { (a, b) in
                let dateA = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                let dateB = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                return dateA > dateB
            }
            .prefix(limit)

        var sessions: [HermesSession] = []

        for file in jsonlFiles {
            if let session = parseSessionFile(file) {
                sessions.append(session)
            }
        }

        return sessions.sorted { $0.date > $1.date }
    }

    /// Parses a single JSONL session file into a HermesSession.
    private func parseSessionFile(_ url: URL) -> HermesSession? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count >= 2 else { return nil }

        let sessionId = url.deletingPathExtension().lastPathComponent

        // Parse metadata from first line if it's session_meta
        var toolsAvailable: [String] = []
        if let firstLineData = lines.first?.data(using: .utf8),
           let meta = try? JSONSerialization.jsonObject(with: firstLineData) as? [String: Any],
           meta["role"] as? String == "session_meta" {
            if let tools = meta["tools"] as? [[String: Any]] {
                for tool in tools {
                    if let function = tool["function"] as? [String: Any],
                       let name = function["name"] as? String {
                        toolsAvailable.append(name)
                    }
                }
            }
        }

        // Parse message lines
        var firstUserMessage = ""
        var firstTimestamp: Date?
        var lastTimestamp: Date?
        var userCount = 0
        var assistantCount = 0

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoFormatterNoFractional = ISO8601DateFormatter()
        isoFormatterNoFractional.formatOptions = [.withInternetDateTime]

        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let msg = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }

            let role = msg["role"] as? String ?? ""
            guard role == "user" || role == "assistant" else { continue }

            if role == "user" { userCount += 1 }
            if role == "assistant" { assistantCount += 1 }

            // Extract timestamp
            if let timestampStr = msg["timestamp"] as? String {
                let date = isoFormatter.date(from: timestampStr) ?? isoFormatterNoFractional.date(from: timestampStr)
                if let date = date {
                    if firstTimestamp == nil { firstTimestamp = date }
                    lastTimestamp = date
                }
            }

            // Extract first user message for title
            if role == "user", firstUserMessage.isEmpty {
                if let content = msg["content"] as? String {
                    firstUserMessage = content
                } else if let contentArray = msg["content"] as? [[String: Any]],
                          let firstContent = contentArray.first,
                          let text = firstContent["text"] as? String {
                    firstUserMessage = text
                }
            }
        }

        guard let sessionDate = firstTimestamp else { return nil }
        let lastActivity = lastTimestamp ?? sessionDate

        // Derive title from first user message
        let title = deriveTitle(from: firstUserMessage, fallback: sessionId)

        // Estimate duration from timestamps
        let durationMinutes = max(1, Int(lastActivity.timeIntervalSince(sessionDate) / 60))

        return HermesSession(
            id: sessionId,
            date: sessionDate,
            lastActivity: lastActivity,
            messageCount: userCount + assistantCount,
            userMessageCount: userCount,
            assistantMessageCount: assistantCount,
            title: title,
            toolsAvailable: toolsAvailable,
            estimatedDurationMinutes: durationMinutes,
            firstUserMessage: firstUserMessage
        )
    }

    /// Derives a clean title from the first user message.
    private func deriveTitle(from message: String, fallback: String) -> String {
        let cleaned = message
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.isEmpty { return "Session \(fallback.suffix(8))" }

        // Take first sentence or first 60 chars
        if let firstSentence = cleaned.components(separatedBy: ".").first,
           firstSentence.count <= 80 {
            return firstSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return String(cleaned.prefix(60)) + (cleaned.count > 60 ? "…" : "")
    }

    // MARK: - Session Sync (into SwiftData)

    /// Syncs discovered Hermes sessions into AMOR's DailySession model.
    /// Only imports sessions not already imported (deduplication by session ID).
    func syncSessions(into modelContext: ModelContext, daysBack: Int = 7) {
        syncStatus = .syncing
        isHermesAvailable = FileManager.default.fileExists(atPath: sessionsDir.path)

        guard isHermesAvailable else {
            syncStatus = .unavailable
            return
        }

        let sessions = discoverSessions(limit: 200)
        totalSessionsDiscovered = sessions.count

        // Filter to recent sessions
        let cutoff = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
        let recentSessions = sessions.filter { $0.date >= cutoff }

        // Load already-imported IDs
        var importedIds = getImportedSessionIds()
        var newImports: [HermesSession] = []

        for session in recentSessions {
            // Skip already imported
            if importedIds.contains(session.id) { continue }

            // Check if a DailySession with this title+date already exists
            let startOfDay = Calendar.current.startOfDay(for: session.date)
            let existingDescriptor = FetchDescriptor<DailySession>(
                predicate: #Predicate<DailySession> { ds in
                    ds.date >= startOfDay && ds.title == "[Hermes] \(session.title)"
                }
            )

            let existing = (try? modelContext.fetch(existingDescriptor)) ?? []
            if !existing.isEmpty {
                importedIds.insert(session.id)
                continue
            }

            // Create new DailySession
            let dailySession = DailySession(
                date: session.date,
                title: "[Hermes] \(session.title)",
                notes: "Auto-imported from Hermes session. \(session.userMessageCount) user messages, \(session.assistantMessageCount) assistant responses. Domain: \(session.inferredDomain)",
                durationMinutes: session.estimatedDurationMinutes,
                toolsUsed: session.inferredTools,
                skillsLearned: session.inferredDomain,
                mood: "focused",
                completedTasks: 0
            )

            modelContext.insert(dailySession)
            importedIds.insert(session.id)
            newImports.append(session)
        }

        // Save
        do {
            try modelContext.save()
            saveImportedSessionIds(importedIds)
            sessionsImportedThisCycle = newImports.count
            recentImports = Array(newImports.prefix(5))
            lastSyncDate = Date()
            syncStatus = .synced
        } catch {
            syncStatus = .error
        }
    }

    // MARK: - Cron Job Sync (Real Data from jobs.json)

    /// Syncs REAL cron job status from ~/.hermes/cron/jobs.json into SwiftData.
    ///
    /// This replaces the old hardcoded phantom-job approach (v2.1.0) that seeded
    /// 11 fake entries with status="pending" — which meant the briefing engine,
    /// progress tracker, and dump generator always saw stale data.
    ///
    /// Now reads from the same AMORCronStatusReader used by the Cron Health
    /// Dashboard, ensuring a single source of truth.
    func syncCronJobs(into modelContext: ModelContext) {
        let cronReader = AMORCronStatusReader()
        cronReader.refresh()

        guard cronReader.isHermesCronAvailable else {
            totalCronJobsDiscovered = 0
            return
        }

        let realJobs = cronReader.jobs
        totalCronJobsDiscovered = realJobs.count

        // Collect real job names for phantom cleanup
        var realJobNames = Set<String>()
        for realJob in realJobs {
            realJobNames.insert(realJob.name)

            // Fetch existing entry by job name
            let jobName = realJob.name
            let descriptor = FetchDescriptor<CronJobHealth>(
                predicate: #Predicate<CronJobHealth> { cj in
                    cj.jobName == jobName
                }
            )

            let existing = (try? modelContext.fetch(descriptor))?.first

            // Normalize status: Hermes uses "ok"/"failed"/"pending"/"error"
            // SwiftData CronJobHealth uses "success"/"failed"/"pending"
            let normalizedStatus: String
            switch realJob.lastStatus {
            case "ok": normalizedStatus = "success"
            case "failed", "error": normalizedStatus = "failed"
            case "pending": normalizedStatus = "pending"
            default: normalizedStatus = "pending"
            }

            if let existing = existing {
                // Update existing entry with real data
                existing.lastRunDate = realJob.lastRunAt
                existing.lastStatus = normalizedStatus
                existing.errorMessage = realJob.lastError
                existing.schedule = realJob.scheduleDisplay
                existing.isEnabled = realJob.enabled

                // Compute consecutive failures from status
                if realJob.lastStatus == "failed" || realJob.lastStatus == "error" {
                    existing.consecutiveFailures = max(existing.consecutiveFailures, 1)
                } else if realJob.lastStatus == "ok" {
                    existing.consecutiveFailures = 0
                    existing.lastSuccessDate = realJob.lastRunAt
                }
            } else {
                // Create new entry with real data
                let newJob = CronJobHealth(
                    jobName: realJob.name,
                    lastRunDate: realJob.lastRunAt,
                    lastStatus: normalizedStatus,
                    errorMessage: realJob.lastError,
                    schedule: realJob.scheduleDisplay,
                    isEnabled: realJob.enabled,
                    consecutiveFailures: (realJob.lastStatus == "failed" || realJob.lastStatus == "error") ? 1 : 0,
                    lastSuccessDate: realJob.lastStatus == "ok" ? realJob.lastRunAt : nil
                )
                modelContext.insert(newJob)
            }
        }

        // Purge phantom entries — SwiftData CronJobHealth records that don't
        // exist in the real jobs.json. This cleans up old v2.1.0 hardcoded entries.
        let allDescriptor = FetchDescriptor<CronJobHealth>()
        if let allJobs = try? modelContext.fetch(allDescriptor) {
            for job in allJobs {
                if !realJobNames.contains(job.jobName) {
                    modelContext.delete(job)
                }
            }
        }

        try? modelContext.save()
    }

    // MARK: - Full Sync

    /// Runs a full sync cycle: sessions + cron jobs.
    func performFullSync(into modelContext: ModelContext) {
        syncSessions(into: modelContext)
        syncCronJobs(into: modelContext)
    }

    // MARK: - Deduplication Helpers

    private func getImportedSessionIds() -> Set<String> {
        if let array = UserDefaults.standard.array(forKey: importedSessionsKey) as? [String] {
            return Set(array)
        }
        return []
    }

    private func saveImportedSessionIds(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: importedSessionsKey)
    }

    // MARK: - Stats for Dashboard

    /// Returns summary statistics for the dashboard.
    func getSessionStats(daysBack: Int = 7) -> SessionStats {
        let sessions = discoverSessions(limit: 500)
        let cutoff = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
        let recent = sessions.filter { $0.date >= cutoff }

        let totalMinutes = recent.reduce(0) { $0 + $1.estimatedDurationMinutes }
        let domains = Dictionary(grouping: recent) { $0.inferredDomain }
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }

        return SessionStats(
            totalSessions: recent.count,
            totalFocusMinutes: totalMinutes,
            averageSessionMinutes: recent.isEmpty ? 0 : totalMinutes / recent.count,
            topDomains: Array(domains.prefix(5)),
            avgMessagesPerSession: recent.isEmpty ? 0 : recent.reduce(0) { $0 + $1.messageCount } / recent.count
        )
    }
}

// MARK: - Supporting Types

enum SyncStatus: String {
    case idle = "⚪️ Idle"
    case syncing = "🔄 Syncing…"
    case synced = "✅ Synced"
    case error = "❌ Error"
    case unavailable = "🌙 Hermes Not Found"
}

struct SessionStats {
    let totalSessions: Int
    let totalFocusMinutes: Int
    let averageSessionMinutes: Int
    let topDomains: [(domain: String, count: Int)]
    let avgMessagesPerSession: Int

    var totalFocusHours: Double {
        Double(totalFocusMinutes) / 60.0
    }
}
