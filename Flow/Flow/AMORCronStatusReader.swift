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
    /// When the job was created — anchors zombie detection for never-run jobs (v4.5.0).
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, enabled, state, deliver
        case scheduleDisplay = "schedule_display"
        case lastStatus = "last_status"
        case lastRunAt = "last_run_at"
        case nextRunAt = "next_run_at"
        case lastError = "last_error"
        case createdAt = "created_at"
    }

    // Handle the repeat object which has a completed count
    struct RepeatConfig: Codable {
        let times: Int?
        let completed: Int?
    }

    /// Nested schedule object from jobs.json (`{kind, expr, minutes}`).
    struct ScheduleConfig: Codable {
        let kind: String?
        let expr: String?
        let minutes: Int?
    }

    /// Raw schedule from jobs.json — drives missed-slot detection (v4.3.0).
    let schedule: ScheduleConfig?

    /// Grace windows for missed-slot detection (mirror of watchdog v2).
    static let dailyGraceMinutes: Double = 90
    static let intervalGraceMultiplier: Double = 2.5

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
        self.schedule = try? superContainer.decodeIfPresent(ScheduleConfig.self, forKey: .scheduleName)

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

        // v4.5.0: creation date anchors zombie detection for never-run jobs.
        if let createdStr = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            self.createdAt = AMORCronStatusReader.parseISODate(createdStr)
        } else {
            self.createdAt = nil
        }

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
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
    }

    enum SuperCodingKeys: String, CodingKey {
        case scheduleName = "schedule"
        case repeatConfig = "repeat"
    }

    // MARK: - Computed Properties

    var statusEmoji: String {
        if !enabled { return "⏸️" }
        if healthStatus == "zombie" { return "🧟" }
        if healthStatus == "missed" { return "🟠" }
        switch lastStatus {
        case "ok": return "✅"
        case "failed": return "❌"
        case "pending": return "⏳"
        default: return "❓"
        }
    }

    /// Most recent expected run time for this job's schedule, from Hermes's
    /// own cron expr — not from next/last run deltas (v4.4.0).
    var mostRecentExpectedSlot: Date? {
        guard enabled else { return nil }
        // Interval jobs: expected every `minutes` *after* the last actual run.
        if let minutes = schedule?.minutes, minutes > 0 {
            guard let lastRun = lastRunAt else { return nil }
            return lastRun.addingTimeInterval(TimeInterval(minutes) * 60)
        }
        // Calendar cron exprs: parse the expr into the most recent scheduled slot.
        // jobs.json exprs are UTC-normalized (live-proven by watchdog v2).
        guard let expr = schedule?.expr else { return nil }
        return AMORCronStatusReader.mostRecentSlot(forExpr: expr, onOrBefore: Date())
    }

    /// True when the most recent expected slot has passed without a run
    /// since that slot — the real stale-ok test (v4.4.0).
    var hasMissedSchedule: Bool {
        guard enabled, lastStatus == "ok" else { return false }
        guard let expected = mostRecentExpectedSlot else { return false }
        let grace: TimeInterval
        if let minutes = schedule?.minutes, minutes > 0 {
            // Interval: missed when the last run is older than 3.5× the period.
            grace = Self.intervalGraceMultiplier * Double(minutes) * 60
        } else {
            // Calendar: scale grace with period so sub-daily schedules don't cry wolf.
            // Daily: 90m. 2h job: 60m. Capped at 90m so dailies still catch next-day misses.
            let period = (nextRunAt?.timeIntervalSince(expected) ?? Self.dailyGraceMinutes * 60)
            grace = min(Self.dailyGraceMinutes * 60, max(period, 1) / 2)
        }
        // Still inside the grace window after the slot — not a miss yet.
        guard Date().timeIntervalSince(expected) > grace else { return false }
        // The job ran after its most recent expected slot → it satisfied that slot.
        if let lastRun = lastRunAt, lastRun >= expected { return false }
        return true
    }

    /// True for an enabled never-run job whose schedule has drifted well past
    /// its creation — the scheduler kept advancing next_run_at without ever
    /// firing (v4.5.0). Live shape: created Jul 18, 48h interval, next_run
    /// Nov 15 — 60 silently skipped intervals, invisible to every other
    /// detector because they all anchor on lastRunAt.
    var isZombie: Bool {
        guard enabled, lastRunAt == nil, completedRuns == 0, let created = createdAt else { return false }
        let period: TimeInterval
        if let minutes = schedule?.minutes, minutes > 0 {
            period = Double(minutes) * 60
        } else if let next = nextRunAt {
            // Calendar job: infer the period from next − created when sane (≤ 31d).
            let p = next.timeIntervalSince(created)
            guard p > 0, p <= 31 * 86400 else { return false }
            period = p
        } else {
            return false
        }
        // Two full periods of silence (min 6h) before crying zombie —
        // a freshly created job gets its first real slot first.
        return Date().timeIntervalSince(created) > max(period * 2, 6 * 3600)
    }

    var healthStatus: String {
        if !enabled { return "paused" }
        // v4.5.0: zombie outranks everything — never ran while the schedule
        // drifted on without it. Stale-ok and missed-slot tests both anchor
        // on lastRunAt and are structurally blind to this shape.
        if isZombie { return "zombie" }
        switch lastStatus {
        case "ok":
            if hasMissedSchedule { return "missed" }
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
        case "zombie": return "purple"
        case "failing", "stale": return "red"
        case "missed": return "orange"
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

    var relativeCreatedAt: String {
        guard let created = createdAt else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: created, relativeTo: Date())
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
    /// Enabled jobs whose latest expected slot passed without a run (v4.3.0).
    var totalMissed: Int = 0
    /// Enabled never-run jobs silently skipped since creation (v4.5.0).
    var totalZombies: Int = 0
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
        totalMissed = jobs.filter { $0.healthStatus == "missed" }.count
        totalZombies = jobs.filter { $0.healthStatus == "zombie" }.count
        totalPaused = jobs.filter { !$0.enabled }.count

        lastRefresh = Date()
    }

    /// Returns only the active (enabled) jobs.
    var activeJobs: [AMORCronJob] {
        jobs.filter { $0.enabled }
    }

    /// Returns jobs that need attention (failing, stale, missed, or zombie).
    var jobsNeedingAttention: [AMORCronJob] {
        jobs.filter { ["failing", "stale", "missed", "zombie"].contains($0.healthStatus) }
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

    /// Computes the most recent scheduled slot from a 5-field cron expr.
    /// Supports fixed daily (`M H * * *`) and hour-step (`M */n * * *`).
    /// jobs.json exprs are UTC-normalized, so this uses UTC (v4.4.0).
    static func mostRecentSlot(forExpr expr: String, onOrBefore now: Date) -> Date? {
        let fields = expr.split(separator: " ").map(String.init)
        guard fields.count == 5, fields[2] == "*", fields[3] == "*", fields[4] == "*" else {
            return nil
        }
        guard let minute = Int(fields[0]), (0...59).contains(minute) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone.current

        let hourField = fields[1]
        // Fixed hour: `M H * * *`
        if let hour = Int(hourField), (0...23).contains(hour) {
            var comps = calendar.dateComponents([.year, .month, .day], from: now)
            comps.hour = hour; comps.minute = minute; comps.second = 0
            guard var slot = calendar.date(from: comps) else { return nil }
            if slot > now {
                slot = calendar.date(byAdding: .day, value: -1, to: slot) ?? slot
            }
            return slot
        }
        // Hour step: `M */n * * *`
        if hourField.hasPrefix("*/"), let step = Int(hourField.dropFirst(2)), step > 0, step <= 23 {
            var cand = now
            // Step back whole hours until we find an hour that is a multiple of `step`
            // and the resulting minute-of-hour is on or before `now`.
            for _ in 0..<((24 / step) + 2) {
                let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: cand)
                let currentHour = comps.hour ?? 0
                var slotComps = DateComponents()
                slotComps.year = comps.year; slotComps.month = comps.month; slotComps.day = comps.day
                slotComps.hour = currentHour; slotComps.minute = minute; slotComps.second = 0
                guard let slot = calendar.date(from: slotComps) else { return nil }
                if currentHour % step == 0, slot <= now {
                    return slot
                }
                // Move cand back one whole hour so we eventually land on a valid multiple.
                guard let prevHourStart = calendar.date(bySettingHour: currentHour, minute: 0, second: 0, of: cand),
                      let prev = calendar.date(byAdding: .hour, value: -1, to: prevHourStart) else { return nil }
                cand = prev
            }
            return nil
        }
        return nil
    }
}
