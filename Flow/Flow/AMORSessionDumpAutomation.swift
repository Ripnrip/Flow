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
import SwiftData

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
        sessions: [DailySession],
        practices: [PracticeStreak],
        cronJobs: [CronJobHealth],
        summaries: [DailySummary],
        reflections: [ReflectionEntry]
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

    /// Returns snapshots for the last N days (including days with zero activity).
    func loadSnapshotsForDays(_ days: Int) -> [ProgressSnapshot] {
        let all = loadProgressSnapshots()
        guard all.count > days else { return all }
        return Array(all.prefix(days))
    }

    // MARK: - Markdown Generation

    private func generateMarkdown(
        date: Date,
        sessions: [DailySession],
        practices: [PracticeStreak],
        cronJobs: [CronJobHealth],
        mood: String,
        snapshot: ProgressSnapshot,
        reflections: [ReflectionEntry]
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
                output += "### \(reflection.promptText.prefix(80))\n"
                output += "*Mood: \(reflection.moodBefore.capitalized) → \(reflection.moodAfter.capitalized)*\n\n"
                output += "\(reflection.responseText)\n\n"
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

// MARK: - Dashboard Card

/// Compact dashboard card showing the latest auto-dump status.
/// Placed on the Today tab so the user can see their daily dump at a glance.
struct AutoDumpStatusCard: View {
    @State private var automation = AMORSessionDumpAutomation()
    @State private var latestSnapshot: ProgressSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(AMORColorPalette.deepIndigo)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Dump")
                        .font(AMORTypography.bodyFont.bold())
                    Text(automation.isAvailable ? "Auto-generated daily" : "Dump directory unavailable")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let snapshot = latestSnapshot {
                    VStack(alignment: .trailing) {
                        Text("\(snapshot.sessionCount)")
                            .font(AMORTypography.titleFont.bold())
                            .foregroundStyle(AMORColorPalette.deepIndigo)
                        Text("sessions")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let snapshot = latestSnapshot {
                HStack(spacing: 16) {
                    dumpMetric(
                        icon: "clock.fill",
                        value: Self.formatFocus(snapshot.totalFocusMinutes),
                        label: "Focus"
                    )
                    Divider().frame(height: 30)
                    dumpMetric(
                        icon: "checkmark.circle.fill",
                        value: "\(snapshot.tasksCompleted)",
                        label: "Tasks"
                    )
                    Divider().frame(height: 30)
                    dumpMetric(
                        icon: "flame.fill",
                        value: "\(snapshot.activeStreaks)",
                        label: "Streaks"
                    )
                    Divider().frame(height: 30)
                    dumpMetric(
                        icon: "heart.fill",
                        value: String(format: "%.0f%%", snapshot.cronHealthPercentage),
                        label: "Health"
                    )
                }

                if !snapshot.topTools.isEmpty {
                    HStack {
                        Text("Top tools:")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                        ForEach(snapshot.topTools.prefix(3), id: \.self) { tool in
                            Text(tool)
                                .font(AMORTypography.captionFont)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.thinMaterial)
                                .clipShape(Capsule())
                        }
                    }
                }
            } else if automation.isAvailable {
                Text("No dumps generated yet. Sessions will be captured automatically.")
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            latestSnapshot = automation.loadLatestSnapshot()
        }
    }

    private func dumpMetric(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(AMORColorPalette.deepIndigo)
            Text(value)
                .font(AMORTypography.captionFont.bold())
            Text(label)
                .font(AMORTypography.captionFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private static func formatFocus(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let mins = minutes % 60
        return mins == 0 ? "\(hours)h" : "\(hours)h\(mins)"
    }
}

// MARK: - Progress Timeline View

/// A timeline view showing the last 14 days of progress snapshots.
/// Accessed from the Review tab sub-navigation.
struct AMORProgressTimelineView: View {
    @State private var automation = AMORSessionDumpAutomation()
    @State private var snapshots: [ProgressSnapshot] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if snapshots.isEmpty {
                        ContentUnavailableView(
                            "No Progress Data",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text("Progress snapshots are generated automatically when you open AMOR.")
                        )
                        .padding(.top, 40)
                    } else {
                        // Weekly average card
                        if snapshots.count >= 7 {
                            weeklyAverageCard
                        }

                        // Timeline
                        Text("Daily Timeline")
                            .font(AMORTypography.titleFont)
                            .foregroundStyle(AMORColorPalette.deepIndigo)
                            .padding(.top, 8)

                        ForEach(snapshots.prefix(30)) { snapshot in
                            ProgressSnapshotRow(snapshot: snapshot)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Progress Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                snapshots = automation.loadProgressSnapshots()
            }
        }
    }

    private var weeklyAverageCard: some View {
        let recent7 = Array(snapshots.prefix(7))
        let avgSessions = recent7.reduce(0) { $0 + $1.sessionCount } / recent7.count
        let avgMinutes = recent7.reduce(0) { $0 + $1.totalFocusMinutes } / recent7.count
        let totalTasks = recent7.reduce(0) { $0 + $1.tasksCompleted }
        let avgPractices = recent7.reduce(0) { $0 + $1.practicesCompleted } / recent7.count

        return AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("7-Day Average")
                    .font(AMORTypography.titleFont)
                    .foregroundStyle(AMORColorPalette.deepIndigo)

                HStack {
                    weeklyStat(value: "\(avgSessions)", label: "Sessions/day")
                    Divider().frame(height: 40)
                    weeklyStat(value: Self.formatFocus(avgMinutes), label: "Focus/day")
                    Divider().frame(height: 40)
                    weeklyStat(value: "\(totalTasks)", label: "Tasks (7d)")
                    Divider().frame(height: 40)
                    weeklyStat(value: "\(avgPractices)", label: "Practices/day")
                }
            }
        }
    }

    private func weeklyStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AMORTypography.titleFont.bold())
                .foregroundStyle(AMORColorPalette.deepIndigo)
            Text(label)
                .font(AMORTypography.captionFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private static func formatFocus(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        return String(format: "%.1fh", Double(minutes) / 60.0)
    }
}

// MARK: - Progress Snapshot Row

struct ProgressSnapshotRow: View {
    let snapshot: ProgressSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(snapshot.formattedDate)
                    .font(AMORTypography.bodyFont.bold())

                Spacer()

                // Mood indicator
                Text(moodEmoji)
                    .font(.title3)
            }

            HStack(spacing: 12) {
                metricBadge(icon: "clock", value: "\(snapshot.totalFocusMinutes)m", color: AMORColorPalette.deepIndigo)
                metricBadge(icon: "doc.text", value: "\(snapshot.sessionCount)", color: AMORColorPalette.growth)
                metricBadge(icon: "checkmark.circle", value: "\(snapshot.tasksCompleted)", color: AMORColorPalette.accomplishment)
                metricBadge(icon: "flame.fill", value: "\(snapshot.practicesCompleted)", color: AMORColorPalette.energy)
            }

            if !snapshot.topTools.isEmpty {
                HStack(spacing: 4) {
                    ForEach(snapshot.topTools.prefix(4), id: \.self) { tool in
                        Text(tool)
                            .font(AMORTypography.captionFont)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var moodEmoji: String {
        switch snapshot.mood.lowercased() {
        case "energized", "happy": return "⚡"
        case "focused": return "🎯"
        case "calm": return "🧘"
        case "tired": return "😴"
        case "stressed": return "😰"
        case "neutral": return "⚪"
        default: return "📝"
        }
    }

    private func metricBadge(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(value)
                .font(AMORTypography.captionFont.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}
