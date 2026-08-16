/**
 * 📡 AMORCronStatusReader — Real Cron Health from Hermes
 *
 * "The vigilant sentinel of automated rhythms. Where the pulse of
 * every scheduled task is felt in real time, and the health of the
 * system becomes a living, breathing awareness rather than a guess."
 *
 * Parses real cron job status from ~/.hermes/cron/jobs.json — the
 * actual source of truth for Hermes scheduled jobs.
 *
 * Architecture: Foundation-only. No SwiftUI. Uses the filesystem-direct
 * pattern to read Hermes data from the local machine.
 */

import Foundation

// MARK: - Cron Job Data Structures

/// A cron job parsed from the Hermes jobs.json file.
struct AMORCronJob: Codable, Identifiable {
    let id: String
    let name: String
    let scheduleDisplay: String
    let enabled: Bool
    let state: String       // "active", "paused", etc.
    let lastStatus: String  // "ok", "failed", "pending"
    let lastRunAt: Date?
    let nextRunAt: Date?
    let lastError: String?
    let completedRuns: Int
    let deliver: String

    enum CodingKeys: String, CodingKey {
        case id, name, enabled, state, deliver
        case scheduleDisplay = "schedule_display"
        case lastStatus = "last_status"
        case lastRunAt = "last_run_at"
        case nextRunAt = "next_run_at"
        case lastError = "last_error"
    }

    // Handle the repeat object which has a completed count
    struct RepeatConfig: Codable {
        let times: Int?
        let completed: Int?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let superContainer = try decoder.container(keyedBy: SuperCodingKeys.self)

        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.scheduleDisplay = try container.decode(String.self, forKey: .scheduleDisplay)
        self.enabled = try container.decode(Bool.self, forKey: .enabled)
        self.state = try container.decode(String.self, forKey: .state)
        self.lastStatus = try container.decodeIfPresent(String.self, forKey: .lastStatus) ?? "pending"
        self.deliver = try container.decodeIfPresent(String.self, forKey: .deliver) ?? "local"

        // Parse dates (ISO 8601 strings)
        if let runStr = try container.decodeIfPresent(String.self, forKey: .lastRunAt) {
            self.lastRunAt = AMORCronStatusReader.parseISODate(runStr)
        } else {
            self.lastRunAt = nil
        }

        if let nextStr = try container.decodeIfPresent(String.self, forKey: .nextRunAt) {
            self.nextRunAt = AMORCronStatusReader.parseISODate(nextStr)
        } else {
            self.nextRunAt = nil
        }

        self.lastError = try container.decodeIfPresent(String.self, forKey: .lastError)

        // Parse repeat.completed from the nested object
        if let repeatConfig = try? superContainer.decodeIfPresent(RepeatConfig.self, forKey: .repeatConfig) {
            self.completedRuns = repeatConfig.completed ?? 0
        } else {
            self.completedRuns = 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(scheduleDisplay, forKey: .scheduleDisplay)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(state, forKey: .state)
        try container.encode(lastStatus, forKey: .lastStatus)
        try container.encode(deliver, forKey: .deliver)
        try container.encodeIfPresent(lastRunAt, forKey: .lastRunAt)
        try container.encodeIfPresent(nextRunAt, forKey: .nextRunAt)
        try container.encodeIfPresent(lastError, forKey: .lastError)
    }

    enum SuperCodingKeys: String, CodingKey {
        case repeatConfig = "repeat"
    }

    // MARK: - Computed Properties

    var statusEmoji: String {
        if !enabled { return "⏸️" }
        switch lastStatus {
        case "ok": return "✅"
        case "failed": return "❌"
        case "pending": return "⏳"
        default: return "❓"
        }
    }

    var healthStatus: String {
        if !enabled { return "paused" }
        switch lastStatus {
        case "ok":
            if let lastRun = lastRunAt {
                let hoursAgo = Date().timeIntervalSince(lastRun) / 3600
                if hoursAgo > 48 { return "stale" }
                return "healthy"
            }
            return "never_run"
        case "failed": return "failing"
        case "pending": return "pending"
        default: return "unknown"
        }
    }

    var healthColor: String {
        switch healthStatus {
        case "healthy": return "green"
        case "failing", "stale": return "red"
        case "pending", "never_run", "unknown": return "yellow"
        case "paused": return "gray"
        default: return "blue"
        }
    }

    var relativeLastRun: String {
        guard let lastRun = lastRunAt else { return "never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastRun, relativeTo: Date())
    }

    var relativeNextRun: String {
        guard let nextRun = nextRunAt else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: nextRun, relativeTo: Date())
    }
}

// MARK: - Cron Status Reader

/// Reads real cron job status from the Hermes filesystem.
@Observable
final class AMORCronStatusReader {

    // MARK: - Published State

    /// All discovered cron jobs
    var jobs: [AMORCronJob] = []

    /// Whether the Hermes cron system was found
    var isHermesCronAvailable: Bool = false

    /// Last refresh timestamp
    var lastRefresh: Date?

    /// Summary stats for dashboard
    var totalActive: Int = 0
    var totalHealthy: Int = 0
    var totalFailing: Int = 0
    var totalPaused: Int = 0

    // MARK: - Configuration

    private let hermesHome: URL
    private var cronDir: URL { hermesHome.appendingPathComponent("cron") }
    private var jobsFile: URL { cronDir.appendingPathComponent("jobs.json") }

    // MARK: - Init

    init() {
        if let envPath = ProcessInfo.processInfo.environment["HERMES_HOME"] {
            self.hermesHome = URL(fileURLWithPath: envPath)
        } else {
            self.hermesHome = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".hermes")
        }

        self.isHermesCronAvailable = FileManager.default.fileExists(atPath: jobsFile.path)
    }

    // MARK: - Refresh

    /// Reloads cron job data from the Hermes filesystem.
    func refresh() {
        guard FileManager.default.fileExists(atPath: jobsFile.path) else {
            isHermesCronAvailable = false
            jobs = []
            return
        }

        isHermesCronAvailable = true

        guard let data = try? Data(contentsOf: jobsFile) else {
            return
        }

        // Parse the { "jobs": [...] } structure
        struct JobsContainer: Codable {
            let jobs: [AMORCronJob]
        }

        let decoder = JSONDecoder()
        if let container = try? decoder.decode(JobsContainer.self, from: data) {
            jobs = container.jobs.sorted { jobA, jobB in
                // Active jobs first, then by name
                if jobA.enabled != jobB.enabled {
                    return jobA.enabled && !jobB.enabled
                }
                return jobA.name < jobB.name
            }
        }

        // Compute summary stats
        totalActive = jobs.filter { $0.enabled }.count
        totalHealthy = jobs.filter { $0.healthStatus == "healthy" }.count
        totalFailing = jobs.filter { $0.healthStatus == "failing" || $0.healthStatus == "stale" }.count
        totalPaused = jobs.filter { !$0.enabled }.count

        lastRefresh = Date()
    }

    /// Returns only the active (enabled) jobs.
    var activeJobs: [AMORCronJob] {
        jobs.filter { $0.enabled }
    }

    /// Returns jobs that need attention (failing, stale, or error).
    var jobsNeedingAttention: [AMORCronJob] {
        jobs.filter { $0.healthStatus == "failing" || $0.healthStatus == "stale" }
    }

    /// Overall system health percentage (0-100).
    var healthPercentage: Double {
        guard !jobs.isEmpty else { return 0 }
        let healthy = Double(jobs.filter { $0.healthStatus == "healthy" }.count)
        let total = Double(jobs.count)
        return (healthy / total) * 100.0
    }

    // MARK: - Date Parsing Helper

    /// Parses ISO 8601 date strings with optional fractional seconds.
    static func parseISODate(_ str: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let withoutFractional = ISO8601DateFormatter()
        withoutFractional.formatOptions = [.withInternetDateTime]

        return withFractional.date(from: str) ?? withoutFractional.date(from: str)
    }
}
