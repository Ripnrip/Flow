/**
 * 🧠 AMORSecondBrainView — Second Brain Integration Interface
 *
 * "Where the day's experience crystallizes into permanent knowledge.
 * A contemplative space for filing the ephemeral into the eternal."
 */

import SwiftUI
import SwiftData

struct AMORSecondBrainView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var brainManager = AMORSecondBrainManager()
    @State private var dumpGenerator = AMORDumpGenerator()

    @Query private var sessions: [DailySession]
    @Query private var practices: [PracticeStreak]
    @Query private var summaries: [DailySummary]

    @State private var selectedView: BrainViewMode = .summary
    @State private var reflection: String = ""
    @State private var showWriteSuccess = false
    @State private var vaultNotes: [(path: String, title: String, modified: Date)] = []
    @State private var selectedNotePath: String?
    @State private var noteContent: String?
    // v4.6.0 — the two REAL vault shelves (were built in v4.2.0, never wired):
    @State private var hermesDumps: [AMORSecondBrainManager.HermesSessionDump] = []
    @State private var dailyNotes: [(date: Date, content: String, path: String)] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Connection status
                    connectionCard

                    // Mode picker
                    Picker("View Mode", selection: $selectedView) {
                        Text("Summary").tag(BrainViewMode.summary)
                        Text("Vault Browser").tag(BrainViewMode.browser)
                        Text("Recent Notes").tag(BrainViewMode.recent)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Content based on mode
                    switch selectedView {
                    case .summary:
                        summaryWriterCard
                    case .browser:
                        vaultBrowserCard
                    case .recent:
                        recentNotesCard
                    }
                }
                .padding()
            }
            .navigationTitle("Second Brain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        brainManager.discoverVault()
                        loadVaultData()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                brainManager.discoverVault()
                loadVaultData()
            }
            .alert("Filed to Vault", isPresented: $showWriteSuccess) {
                Button("OK") { }
            } message: {
                Text(brainManager.statusMessage)
            }
        }
    }

    // MARK: - Connection Card

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: brainManager.isVaultAvailable ? "checkmark.seal.fill" : "questionmark.circle.fill")
                    .foregroundStyle(brainManager.isVaultAvailable ? AMORColorPalette.sageGreen : .secondary)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(brainManager.isVaultAvailable ? "Vault Connected" : "No Vault Found")
                        .font(AMORTypography.bodyFont.bold())
                    Text(brainManager.statusMessage)
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }
            }

            if brainManager.isVaultAvailable, let vault = brainManager.vault {
                Text("📁 \(vault.name)")
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)
            } else {
                Text("Obsidian vaults are searched in ~/Documents/ and ~/")
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Summary Writer

    private var summaryWriterCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("File Today's Summary")
                .font(AMORTypography.titleFont)
                .foregroundStyle(AMORColorPalette.deepIndigo)

            // Preview of what will be filed
            summaryPreview

            // Reflection input
            VStack(alignment: .leading, spacing: 8) {
                Text("Daily Reflection")
                    .font(AMORTypography.bodyFont.bold())
                TextEditor(text: $reflection)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.thinMaterial))
            }

            // File button
            Button {
                fileSummary()
            } label: {
                Label("File to Vault", systemImage: "tray.and.arrow.down.fill")
                    .font(AMORTypography.bodyFont)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(brainManager.isVaultAvailable ? AMORColorPalette.deepIndigo : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!brainManager.isVaultAvailable)
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var summaryPreview: some View {
        let todaySessions = sessions.filter {
            $0.date >= Calendar.current.startOfDay(for: Date())
        }
        let totalMinutes = todaySessions.reduce(0) { $0 + $1.durationMinutes }
        let tasksCompleted = todaySessions.reduce(0) { $0 + $1.completedTasks }
        let completedPractices = practices.filter { $0.isActive }.map { $0.practiceName }

        return AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("\(todaySessions.count)", systemImage: "clock")
                        .font(AMORTypography.captionFont.bold())
                    Spacer()
                    Label("\(totalMinutes)m", systemImage: "bolt.fill")
                        .font(AMORTypography.captionFont.bold())
                    Spacer()
                    Label("\(tasksCompleted)", systemImage: "checkmark.circle")
                        .font(AMORTypography.captionFont.bold())
                    Spacer()
                    Label("\(completedPractices.count)", systemImage: "flame.fill")
                        .font(AMORTypography.captionFont.bold())
                }

                if !completedPractices.isEmpty {
                    Text("Practices: \(completedPractices.joined(separator: ", "))")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Vault Browser

    private var vaultBrowserCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vault Browser")
                .font(AMORTypography.titleFont)
                .foregroundStyle(AMORColorPalette.deepIndigo)

            if vaultNotes.isEmpty {
                Text("No notes found in vault")
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)
                    .padding(.vertical)
            } else {
                ForEach(Array(vaultNotes.prefix(30).enumerated()), id: \.offset) { _, note in
                    Button {
                        selectedNotePath = note.path
                        noteContent = brainManager.readNote(path: note.path)
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundStyle(AMORColorPalette.deepIndigo)
                            VStack(alignment: .leading) {
                                Text(note.title)
                                    .font(AMORTypography.bodyFont)
                                Text(note.path)
                                    .font(AMORTypography.captionFont)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(note.modified.formatted(date: .abbreviated, time: .omitted))
                                .font(AMORTypography.captionFont)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                if let content = noteContent, let path = selectedNotePath {
                    Divider()
                    VStack(alignment: .leading) {
                        Text("Preview: \(path)")
                            .font(AMORTypography.captionFont.bold())
                            .foregroundStyle(.secondary)
                        ScrollView {
                            Text(content)
                                .font(AMORTypography.bodyFont)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 300)
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Recent Notes

    private var recentNotesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Days in the Vault")
                .font(AMORTypography.titleFont)
                .foregroundStyle(AMORColorPalette.deepIndigo)

            // v4.6.0 — the real shelves. Before this, this tab read a SwiftData
            // table nothing ever wrote while 14 real Hermes dumps and the
            // vault's daily notes sat two directories away, unread.
            if dailyNotes.isEmpty && hermesDumps.isEmpty && brainManager.recentSummaries.isEmpty {
                Text("Nothing on the daily shelf yet. Hermes files a reflective note at day's end (~/wiki/daily/), and you can write one above.")
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)
                    .padding(.vertical)
            }

            // Daily notes — the reflective shelf (~/wiki/daily/YYYY-MM-DD.md)
            if !dailyNotes.isEmpty {
                Text("Daily Notes")
                    .font(AMORTypography.bodyFont.bold())
                    .foregroundStyle(.secondary)

                ForEach(dailyNotes, id: \.date) { note in
                    Button {
                        selectedNotePath = note.path
                        noteContent = note.content
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(AMORColorPalette.sageGreen)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(AMORTypography.bodyFont.bold())
                                Text(firstReflectionLine(note.content))
                                    .font(AMORTypography.captionFont)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(AMORTypography.captionFont)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
                }
            }

            // Hermes EOD session dumps — the telemetry shelf
            // (~/wiki/raw/daily-summaries/session-dump-YYYY-MM-DD.md)
            if !hermesDumps.isEmpty {
                Divider()
                Text("Hermes Session Dumps")
                    .font(AMORTypography.bodyFont.bold())
                    .foregroundStyle(.secondary)

                ForEach(hermesDumps) { dump in
                    HStack {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .foregroundStyle(AMORColorPalette.deepIndigo)
                        Text(dump.date.formatted(date: .abbreviated, time: .omitted))
                            .font(AMORTypography.bodyFont)
                        Spacer()
                        Text("\(dump.sessions) sessions · \(dump.toolCalls) calls")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            // Manual summaries filed from this app (kept; now the third shelf)
            if !brainManager.recentSummaries.isEmpty {
                Divider()
                Text("Filed From This App")
                    .font(AMORTypography.bodyFont.bold())
                    .foregroundStyle(.secondary)

                ForEach(brainManager.recentSummaries) { summary in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(summary.date.formatted(date: .complete, time: .omitted))
                            .font(AMORTypography.bodyFont.bold())
                        HStack {
                            Text("\(summary.sessionsLogged) sessions")
                            Text("•")
                            Text("\(summary.totalFocusMinutes)m focus")
                            Text("•")
                            Text(summary.mood)
                        }
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// First meaningful line of a daily note for the list preview —
    /// skips YAML frontmatter and headers, returns the first prose.
    private func firstReflectionLine(_ content: String) -> String {
        var inFrontmatter = false
        var seenFrontmatterDelimiter = false
        for raw in content.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line == "---" {
                if !seenFrontmatterDelimiter {
                    seenFrontmatterDelimiter = true
                    inFrontmatter = true
                } else {
                    inFrontmatter = false
                }
                continue
            }
            if inFrontmatter { continue }
            if line.hasPrefix("#") { continue }
            if line.isEmpty { continue }
            return line
        }
        return "Empty note"
    }

    // MARK: - Actions

    private func fileSummary() {
        let todaySessions = sessions.filter {
            $0.date >= Calendar.current.startOfDay(for: Date())
        }
        let totalMinutes = todaySessions.reduce(0) { $0 + $1.durationMinutes }
        let tasksCompleted = todaySessions.reduce(0) { $0 + $1.completedTasks }
        let completedPractices = practices.filter { $0.isActive }.map { $0.practiceName }
        let tools = Set(todaySessions.flatMap { $0.toolsUsed.components(separatedBy: ",") }
                        .map { $0.trimmingCharacters(in: .whitespaces) })
        let skills = Set(todaySessions.flatMap { $0.skillsLearned.components(separatedBy: ",") }
                         .map { $0.trimmingCharacters(in: .whitespaces) })

        let summary = VaultDailySummary(
            date: Date(),
            sessionsLogged: todaySessions.count,
            totalFocusMinutes: totalMinutes,
            tasksCompleted: tasksCompleted,
            practicesCompleted: completedPractices,
            toolsUsed: Array(tools).filter { !$0.isEmpty },
            skillsLearned: Array(skills).filter { !$0.isEmpty },
            mood: todaySessions.first?.mood ?? "neutral",
            reflection: reflection,
            topDomains: []
        )

        if brainManager.writeDailySummary(summary) {
            showWriteSuccess = true
            reflection = ""
        }
    }

    private func loadVaultData() {
        if brainManager.isVaultAvailable {
            vaultNotes = brainManager.listVaultNotes(limit: 50)
            // v4.6.0 — the shelves that were always there, finally read.
            hermesDumps = brainManager.readHermesSessionDumps(daysBack: 14)
            dailyNotes = brainManager.readDailyNotes(daysBack: 7)
        }
    }
}

// MARK: - View Mode Enum

enum BrainViewMode: String, CaseIterable {
    case summary
    case browser
    case recent
}

// MARK: - Second Brain Dashboard Card

struct SecondBrainCard: View {
    @State private var brainManager = AMORSecondBrainManager()

    var body: some View {
        AMORComponents.ContemplativeCard {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(AMORColorPalette.twilightPurple)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Second Brain")
                        .font(AMORTypography.bodyFont.bold())
                    Text(brainManager.isVaultAvailable ? brainManager.statusMessage : "Not connected")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: brainManager.isVaultAvailable ? "checkmark.circle.fill" : "questionmark.circle")
                    .foregroundStyle(brainManager.isVaultAvailable ? .green : .secondary)
            }
        }
    }
}
