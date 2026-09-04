/**
 * 🌊 AMORSessionDumpAutomation — Automatic Daily Dump Generation
 *
 * "The river that flows between doing and knowing. Each day's sessions,
 * practices, and reflections coalesce into a single markdown artifact —
 * written to the second brain without thought, without friction."
 *
 * v3.3.0 — Session-Dump Automation & Progress Tracking
 *
 * This engine runs on app foreground and produces:
 * 1. A daily dump markdown file in ~/.hermes/logs/amor-dumps/
 * 2. An entry in the Obsidian vault Journal (if accessible)
 * 3. A progress snapshot in UserDefaults for quick dashboard display
 *
 * Architecture: Foundation-only (no SwiftUI). Reads SwiftData via ModelContext.
 * Writes to filesystem using FileManager. Deduplicates by date — one dump per day.
 */

import Foundation

// MARK: - DumpAutomationConfig

struct DumpAutomationConfig {
    /// Directory for AMOR daily dumps (under Hermes logs)
    static let dumpsDirName = "amor-dumps"

    /// Obsidian journal path (relative to home)
    /// v4.2.0 — the real Hermes EOD dump destination (canonical ~/wiki vault).
    static let obsidianJournalPath = "wiki/raw/daily-summaries"

    /// UserDefaults keys
    static let lastDumpDateKey = "amor.lastAutoDumpDate"
    static let progressSnapshotsKey = "amor.progressSnapshots"

    /// How many progress snapshots to retain
    static let maxSnapshots = 90
}

// MARK: - ProgressSnapshot

/// A compact progress snapshot for a single day, stored in UserDefaults.
/// Designed for quick dashboard rendering without fetching all SwiftData.
struct ProgressSnapshot: Codable, Identifiable {
    let id: String  // "yyyy-MM-dd"
    let date: Date
    let sessionCount: Int
    let totalFocusMinutes: Int
    let tasksCompleted: Int
    let practicesCompleted: Int
    let activeStreaks: Int
    let mood: String
    let topTools: [String]
    let topDomains: [String]
    let cronHealthPercentage: Double
    let reflectionCount: Int

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var focusHours: Double {
        Double(totalFocusMinutes) / 60.0
    }
}

// MARK: - DailyDumpResult

/// Result of an auto-dump generation cycle.
struct DailyDumpResult {
    let date: Date
    let dumpPath: String?
    let obsidianPath: String?
    let snapshot: ProgressSnapshot
    let markdownContent: String
    let wasNew: Bool  // true if this was the first dump for this date
}

// MARK: - AMORSessionDumpAutomation Engine

/// Auto-generates daily session dumps and progress snapshots.
///
/// Designed to be called on app foreground (via FlowApp scenePhase handler).
/// Deduplicates by date — only generates a new dump if one hasn't been created
/// today. On subsequent calls (same day), it UPDATES the existing dump with
/// the latest session data.
final class AMORSessionDumpAutomation {

    // MARK: - Properties

    /// Whether the dump directory is writable
    private(set) var isAvailable: Bool = false

    /// Full path to the AMOR dumps directory
    private let dumpsDir: URL

    /// Full path to the Obsidian journal directory (may not exist)
    private let obsidianJournalDir: URL

    /// Whether the Obsidian vault is accessible
    private(set) var isObsidianAvailable: Bool = false

    // MARK: - Init

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser

        // Dumps go to ~/.hermes/logs/amor-dumps/
        let hermesLogs = home
            .appendingPathComponent(".hermes")
            .appendingPathComponent("logs")
            .appendingPathComponent(DumpAutomationConfig.dumpsDirName)

        self.dumpsDir = hermesLogs
        self.obsidianJournalDir = home.appendingPathComponent(DumpAutomationConfig.obsidianJournalPath)

        // Check availability
        self.isAvailable = AMORSessionDumpAutomation.ensureDirectoryExists(hermesLogs)
        self.isObsidianAvailable = FileManager.default.fileExists(atPath: obsidianJournalDir.path)
    }

    // MARK: - Public API

    /// Generates (or updates) today's daily dump.
    /// Returns the result, or nil if the engine is unavailable.
    func generateDailyDump(
        sessions: [AMORSessionSnapshot],
        practices: [AMORPracticeSnapshot],
        cronJobs: [AMORCronJobSnapshot],
        summaries: [AMORDailySummarySnapshot],
        reflections: [AMORReflectionSnapshot]
    ) -> DailyDumpResult? {
        guard isAvailable else { return nil }

        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? today

        // Filter to today's data
        let todaySessions = sessions.filter { $0.date >= startOfDay && $0.date < tomorrow }
        let totalMinutes = todaySessions.reduce(0) { $0 + $1.durationMinutes }
        let totalTasks = todaySessions.reduce(0) { $0 + $1.completedTasks }
        let practicesDoneToday = practices.filter { !$0.isDueToday }.count
        let activeStreaks = practices.filter { $0.isActive }.count

        // Cron health percentage
        let enabledJobs = cronJobs.filter { $0.isEnabled }
        let healthyJobs = enabledJobs.filter { $0.healthStatus == "healthy" }
        let cronHealthPct = enabledJobs.isEmpty ? 100.0 :
            Double(healthyJobs.count) / Double(enabledJobs.count) * 100.0

        // Top tools and domains
        let allTools = todaySessions.flatMap { $0.toolsUsed.components(separatedBy: ",") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let topTools = Dictionary(grouping: allTools, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }

        let allDomains = todaySessions.map { $0.skillsLearned }
            .filter { !$0.isEmpty }
        let topDomains = Dictionary(grouping: allDomains, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }

        // Today's mood
        let mood = summaries
            .filter { $0.date >= startOfDay }
            .first?.mood ?? "neutral"

        // Today's reflections
        let todayReflections = reflections.filter { $0.date >= startOfDay }

        // Create snapshot
        let snapshot = ProgressSnapshot(
            id: Self.dateString(from: today),
            date: today,
            sessionCount: todaySessions.count,
            totalFocusMinutes: totalMinutes,
            tasksCompleted: totalTasks,
            practicesCompleted: practicesDoneToday,
            activeStreaks: activeStreaks,
            mood: mood,
            topTools: topTools,
            topDomains: topDomains,
            cronHealthPercentage: cronHealthPct,
            reflectionCount: todayReflections.count
        )

        // Check if dump already exists for today
        let dumpFileName = "amor-dump-\(Self.dateString(from: today)).md"
        let dumpURL = dumpsDir.appendingPathComponent(dumpFileName)
        let wasNew = !FileManager.default.fileExists(atPath: dumpURL.path)

        // Generate markdown
        let markdown = generateMarkdown(
            date: today,
            sessions: todaySessions,
            practices: practices,
            cronJobs: cronJobs,
            mood: mood,
            snapshot: snapshot,
            reflections: todayReflections
        )

        // Write dump file
        do {
            try markdown.data(using: .utf8)?.write(to: dumpURL, options: .atomic)
        } catch {
            return nil
        }

        // Write to Obsidian vault if available
        var obsidianPath: String? = nil
        if isObsidianAvailable {
            let obsDumpURL = obsidianJournalDir.appendingPathComponent(dumpFileName)
            try? markdown.data(using: .utf8)?.write(to: obsDumpURL, options: .atomic)
            obsidianPath = obsDumpURL.path
        }

        // Save snapshot to UserDefaults
        saveSnapshot(snapshot)

        // Update last dump date
        UserDefaults.standard.set(today, forKey: DumpAutomationConfig.lastDumpDateKey)

        return DailyDumpResult(
            date: today,
            dumpPath: dumpURL.path,
            obsidianPath: obsidianPath,
            snapshot: snapshot,
            markdownContent: markdown,
            wasNew: wasNew
        )
    }

    /// Returns all stored progress snapshots (sorted newest first).
    func loadProgressSnapshots() -> [ProgressSnapshot] {
        guard let data = UserDefaults.standard.data(forKey: DumpAutomationConfig.progressSnapshotsKey) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([ProgressSnapshot].self, from: data))?
            .sorted { $0.date > $1.date } ?? []
    }

    /// Returns the most recent snapshot, or nil if none exist.
    func loadLatestSnapshot() -> ProgressSnapshot? {
        loadProgressSnapshots().first
    }

    // v4.7.0: loadSnapshotsForDays removed — dead since forging (zero call sites).

    // MARK: - Markdown Generation

    private func generateMarkdown(
        date: Date,
        sessions: [AMORSessionSnapshot],
        practices: [AMORPracticeSnapshot],
        cronJobs: [AMORCronJobSnapshot],
        mood: String,
        snapshot: ProgressSnapshot,
        reflections: [AMORReflectionSnapshot]
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy"
        let prettyDate = dateFormatter.string(from: date)

        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: date)

        dateFormatter.dateFormat = "HH:mm"
        let generatedAt = dateFormatter.string(from: Date())

        var output = ""

        // YAML frontmatter for Obsidian
        output += "---\n"
        output += "date: \(dateStr)\n"
        output += "type: amor-daily-dump\n"
        output += "sessions: \(sessions.count)\n"
        output += "focus_minutes: \(snapshot.totalFocusMinutes)\n"
        output += "mood: \(mood)\n"
        output += "practices_done: \(snapshot.practicesCompleted)\n"
        output += "cron_health: \(String(format: "%.0f", snapshot.cronHealthPercentage))%\n"
        output += "tags: [amor, daily-dump, auto-generated]\n"
        output += "---\n\n"

        // Title
        output += "# 🧘 AMOR Daily Dump — \(prettyDate)\n\n"
        output += "> Auto-generated by AMOR Session-Dump Automation at \(generatedAt).\n"
        output += "> *The day's rhythm, captured in a single breath.*\n\n"

        // Summary metrics
        output += "## 📊 Summary\n\n"
        output += "| Metric | Value |\n"
        output += "|--------|-------|\n"
        output += "| Sessions | \(snapshot.sessionCount) |\n"
        output += "| Focus Time | \(Self.formatDuration(snapshot.totalFocusMinutes)) |\n"
        output += "| Tasks Completed | \(snapshot.tasksCompleted) |\n"
        output += "| Practices Done | \(snapshot.practicesCompleted) |\n"
        output += "| Active Streaks | \(snapshot.activeStreaks) |\n"
        output += "| Mood | \(mood.capitalized) |\n"
        output += "| Cron Health | \(String(format: "%.0f%%", snapshot.cronHealthPercentage)) |\n"
        output += "| Reflections | \(snapshot.reflectionCount) |\n"
        output += "\n"

        // Sessions detail
        if sessions.isEmpty {
            output += "## 📝 Sessions\n\n*No sessions logged today yet.*\n\n"
        } else {
            output += "## 📝 Sessions\n\n"
            for session in sessions.sorted(by: { $0.timestamp < $1.timestamp }) {
                output += "### \(session.title)\n"
                output += "- **Duration:** \(Self.formatDuration(session.durationMinutes))\n"
                output += "- **Mood:** \(session.mood.capitalized)\n"
                output += "- **Tasks:** \(session.completedTasks)\n"
                if !session.toolsUsed.isEmpty {
                    output += "- **Tools:** \(session.toolsUsed)\n"
                }
                if !session.skillsLearned.isEmpty {
                    output += "- **Skills:** \(session.skillsLearned)\n"
                }
                if !session.notes.isEmpty {
                    output += "- **Notes:** \(session.notes)\n"
                }
                output += "\n"
            }
        }

        // Practices
        if !practices.isEmpty {
            output += "## 🔥 Practices\n\n"
            output += "| Practice | Streak | Status | Goal |\n"
            output += "|----------|--------|--------|------|\n"
            for practice in practices.sorted(by: { $0.practiceName < $1.practiceName }) {
                let status = practice.isDueToday ? "⏳ Due" : "✅ Done"
                output += "| \(practice.practiceName) | \(practice.currentStreak)🔥 | \(status) | \(practice.goal) |\n"
            }
            output += "\n"
        }

        // System Health
        if !cronJobs.isEmpty {
            output += "## ⚙️ System Health\n\n"
            output += "| Job | Status | Last Run |\n"
            output += "|-----|--------|----------|\n"
            for job in cronJobs.sorted(by: { $0.jobName < $1.jobName }) {
                let lastRun = job.lastRunDate.map { Self.relativeTime(from: $0) } ?? "Never"
                output += "| \(job.statusEmoji) \(job.jobName) | \(job.healthStatus) | \(lastRun) |\n"
            }
            output += "\n"
        }

        // Reflections
        if !reflections.isEmpty {
            output += "## 🌙 Reflections\n\n"
            for reflection in reflections {
                // v5.2.0: fixed latent field-name mismatch (promptText →
                // prompt, responseText → response). This code path had
                // never been compiled until the Full Illumination.
                output += "### \(reflection.prompt.prefix(80))\n"
                output += "*Mood: \(reflection.moodBefore.capitalized) → \(reflection.moodAfter.capitalized)*\n\n"
                output += "\(reflection.response)\n\n"
            }
        }

        // Footer
        output += "---\n"
        output += "*Generated by AMOR v3.3.0 — Session-Dump Automation Engine*\n"
        output += "*Path: `\(dumpsDir.path)/amor-dump-\(dateStr).md`*\n"

        return output
    }

    // MARK: - Snapshot Persistence

    private func saveSnapshot(_ snapshot: ProgressSnapshot) {
        var snapshots = loadProgressSnapshots()

        // Replace existing snapshot for same day, or append
        snapshots.removeAll { $0.id == snapshot.id }
        snapshots.append(snapshot)

        // Sort newest first and trim to max
        snapshots.sort { $0.date > $1.date }
        if snapshots.count > DumpAutomationConfig.maxSnapshots {
            snapshots = Array(snapshots.prefix(DumpAutomationConfig.maxSnapshots))
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(snapshots) {
            UserDefaults.standard.set(data, forKey: DumpAutomationConfig.progressSnapshotsKey)
        }
    }

    // MARK: - Helpers

    private static func ensureDirectoryExists(_ url: URL) -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) { return true }
        do {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
            return true
        } catch {
            return false
        }
    }

    private static func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    private static func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let mins = minutes % 60
        return mins == 0 ? "\(hours)h" : "\(hours)h \(mins)m"
    }

    private static func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
