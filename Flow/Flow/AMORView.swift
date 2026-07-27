/**
 * 🧘 AMORView — Main Dashboard for Daily Operating Rhythm
 *
 * "The heart of contemplation — where sessions are logged, practices honored,
 * and the health of systems silently watched over."
 */

import SwiftUI
import SwiftData

struct AMORView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = 0
    @State private var isLoggingSession = false
    @State private var isCompletingPractice = false
    
    var body: some View {
        AMORComponents.GradientBackground(gradient: AMORColorPalette.calmWaters) {
            NavigationStack {
                TabView(selection: $selectedTab) {
                    // Dashboard Tab
                    DashboardView()
                        .tabItem {
                            Label("Today", systemImage: AMORIconSet.meditation)
                        }
                        .tag(0)
                    
                    // Sessions Tab
                    SessionsLogView()
                        .tabItem {
                            Label("Sessions", systemImage: AMORIconSet.clock)
                        }
                        .tag(1)
                    
                    // Practices Tab
                    PracticesView()
                        .tabItem {
                            Label("Practices", systemImage: AMORIconSet.streak)
                        }
                        .tag(2)

                    // Insights Tab
                    AMORInsightsView()
                        .tabItem {
                            Label("Insights", systemImage: AMORIconSet.chart)
                        }
                        .tag(3)

                    // Dump Tab
                    AMORDumpView()
                        .tabItem {
                            Label("Dump", systemImage: "doc.text")
                        }
                        .tag(4)

                    // Hermes Sync Tab (session-dump automation)
                    HermesSessionSyncView()
                        .tabItem {
                            Label("Sync", systemImage: "antenna.radiowaves.left.and.right")
                        }
                        .tag(5)

                    // Second Brain Tab (Obsidian vault integration)
                    AMORSecondBrainView()
                        .tabItem {
                            Label("Brain", systemImage: "brain.head.profile")
                        }
                        .tag(6)

                    // Health Tab (live cron status)
                    AMORCronHealthDashboard()
                        .tabItem {
                            Label("Systems", systemImage: AMORIconSet.settings)
                        }
                        .tag(7)
                }
                .navigationTitle("AMOR")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                isLoggingSession = true
                            } label: {
                                Label("Log Session", systemImage: "plus.circle")
                            }
                            
                            Button {
                                isCompletingPractice = true
                            } label: {
                                Label("Complete Practice", systemImage: "checkmark.circle")
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(AMORColorPalette.deepIndigo)
                        }
                    }
                }
                .sheet(isPresented: $isLoggingSession) {
                    LogSessionSheet()
                }
                .sheet(isPresented: $isCompletingPractice) {
                    CompletePracticeSheet()
                }
            }
        }
    }
}

// MARK: - Dashboard View

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [DailySession]
    @Query private var practices: [PracticeStreak]
    @Query private var cronJobs: [CronJobHealth]
    
    var today: Date { Date() }
    
    var sessionsToday: [DailySession] {
        sessions.filter { $0.date >= Calendar.current.startOfDay(for: today) }
    }
    
    var totalMinutesToday: Int {
        sessionsToday.reduce(0) { $0 + $1.durationMinutes }
    }
    
    var activeStreaks: Int {
        practices.filter { $0.isActive }.count
    }
    
    var healthyJobs: Int {
        cronJobs.filter { $0.healthStatus == "healthy" }.count
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HeaderSection()
                
                // Today's Summary Cards
                TodaySummaryCard(
                    minutes: totalMinutesToday,
                    sessions: sessionsToday.count,
                    streaks: activeStreaks
                )
                
                // Practices Due Today
                if !practices.filter({ $0.isDueToday }).isEmpty {
                    PracticesDueSection(practices: practices.filter { $0.isDueToday })
                }
                
                // Hermes Integration Card (session-dump automation)
                HermesSyncCard()

                // Second Brain status
                SecondBrainCard()

                // System Health Overview (from real cron data)
                SystemHealthOverview(jobs: cronJobs.filter { $0.healthStatus != "healthy" })

                // Reflective Quote
                AMORComponents.ReflectiveQuote(
                    text: "The quieter you become, the more you are able to hear.",
                    author: "Rumi"
                )
                .padding(.vertical)
                
                Spacer(minLength: 40)
            }
            .padding()
        }
    }
}

// MARK: - Header Section

struct HeaderSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var summary: [DailySummary]
    
    var todaySummary: DailySummary? {
        summary.filter { $0.date >= Calendar.current.startOfDay(for: Date()) }.first
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Good \(greeting), seeker.")
                .font(AMORTypography.headingFont)
                .foregroundStyle(AMORColorPalette.deepIndigo)
            
            Text(todaySummary?.notes ?? "What will you reflect upon today?")
                .font(AMORTypography.subtitleFont)
                .foregroundStyle(.secondary)
        }
    }
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<22: return "evening"
        default: return "night"
        }
    }
}

// MARK: - Today Summary Card

struct TodaySummaryCard: View {
    let minutes: Int
    let sessions: Int
    let streaks: Int
    
    var body: some View {
        AMORComponents.ContemplativeCard {
            HStack(spacing: 20) {
                // Focus Ring
                VStack {
                    AMORComponents.ProgressRing(
                        progress: CGFloat(min(minutes, 120)) / 120.0,
                        size: 70,
                        lineWidth: 6
                    )
                    Text("\(minutes)m")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                    .frame(height: 50)
                
                // Sessions
                VStack {
                    Image(systemName: AMORIconSet.journal)
                        .font(.title2)
                        .foregroundStyle(AMORColorPalette.growth)
                    Text("\(sessions)")
                        .font(.title3.bold())
                    Text("sessions")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                    .frame(height: 50)
                
                // Streaks
                VStack {
                    Image(systemName: AMORIconSet.streak)
                        .font(.title2)
                        .foregroundStyle(AMORColorPalette.energy)
                    Text("\(streaks)")
                        .font(.title3.bold())
                    Text("active")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

// MARK: - Practices Due Section

struct PracticesDueSection: View {
    let practices: [PracticeStreak]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Practices Due")
                .font(AMORTypography.titleFont)
                .foregroundStyle(AMORColorPalette.deepIndigo)
            
            ForEach(practices, id: \.id) { practice in
                PracticeRow(practice: practice)
            }
        }
    }
}

// MARK: - System Health Overview

struct SystemHealthOverview: View {
    let jobs: [CronJobHealth]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Health")
                .font(AMORTypography.titleFont)
                .foregroundStyle(AMORColorPalette.deepIndigo)
            
            if jobs.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("All systems healthy")
                        .font(AMORTypography.bodyFont)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(jobs.prefix(3), id: \.id) { job in
                    CronHealthRow(job: job)
                }
            }
        }
    }
}

// MARK: - Practice Row

struct PracticeRow: View {
    let practice: PracticeStreak
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(practice.practiceName)
                    .font(AMORTypography.bodyFont.bold())
                Text("Goal: \(practice.goal)")
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            AMORComponents.StreakFlame(
                count: practice.currentStreak,
                isBroken: !practice.isActive
            )
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }
}

// MARK: - Cron Health Row

struct CronHealthRow: View {
    let job: CronJobHealth
    
    var body: some View {
        HStack {
            Text(job.statusEmoji)
                .font(.title2)
            
            VStack(alignment: .leading) {
                Text(job.jobName)
                    .font(AMORTypography.bodyFont)
                if let error = job.errorMessage {
                    Text(error)
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text(job.healthStatus)
                .font(AMORTypography.captionFont)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.2))
                .cornerRadius(6)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }
    
    private var statusColor: Color {
        switch job.healthStatus {
        case "healthy": return .green
        case "warning": return .yellow
        case "critical": return .red
        case "disabled": return .gray
        default: return .blue
        }
    }
}

// MARK: - Log Session Sheet

struct LogSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var title = ""
    @State private var durationMinutes = 30
    @State private var notes = ""
    @State private var toolsUsed = ""
    @State private var skillsLearned = ""
    @State private var mood = "focused"
    @State private var completedTasks = 0
    
    var moodOptions = ["focused", "tired", "energized", "neutral", "stressed", "calm"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Session Details") {
                    TextField("Session Title", text: $title)
                    Stepper("Duration: \(durationMinutes) minutes", value: $durationMinutes, in: 5...180, step: 5)
                    Picker("Mood", selection: $mood) {
                        ForEach(moodOptions, id: \.self) { mood in
                            Text(mood.capitalized).tag(mood)
                        }
                    }
                    Stepper("Tasks Completed: \(completedTasks)", value: $completedTasks, in: 0...20)
                }
                
                Section("What did you work with?") {
                    TextField("Tools (comma-separated)", text: $toolsUsed)
                    TextField("Skills learned (comma-separated)", text: $skillsLearned)
                }
                
                Section("Reflections") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Log Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSession()
                    }
                    .disabled(title.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func saveSession() {
        let session = DailySession(
            date: .now,
            title: title,
            notes: notes,
            durationMinutes: durationMinutes,
            toolsUsed: toolsUsed,
            skillsLearned: skillsLearned,
            mood: mood,
            completedTasks: completedTasks
        )
        modelContext.insert(session)
        dismiss()
    }
}

// MARK: - Complete Practice Sheet

struct CompletePracticeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var practices: [PracticeStreak]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(practices, id: \.id) { practice in
                    Button {
                        practice.complete()
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(practice.practiceName)
                                    .font(AMORTypography.bodyFont)
                                Text("Current streak: \(practice.currentStreak)")
                                    .font(AMORTypography.captionFont)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .navigationTitle("Complete Practice")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Sessions Log View

struct SessionsLogView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @Query private var sessions: [DailySession]
    
    var filteredSessions: [DailySession] {
        if searchText.isEmpty {
            return sessions.sorted(by: { $0.date > $1.date })
        }
        return sessions.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.notes.localizedCaseInsensitiveContains(searchText)
        }
        .sorted(by: { $0.date > $1.date })
    }
    
    var body: some View {
        NavigationStack {
            List(filteredSessions) { session in
                SessionRow(session: session)
            }
            .searchable(text: $searchText, prompt: "Search sessions")
            .navigationTitle("Session Log")
        }
    }
}

struct SessionRow: View {
    let session: DailySession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.title)
                    .font(AMORTypography.bodyFont.bold())
                Spacer()
                Text("\(session.durationMinutes)m")
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)
            }
            
            Text(session.formattedDate)
                .font(AMORTypography.captionFont)
                .foregroundStyle(.secondary)
            
            if !session.toolsUsed.isEmpty {
                Text("🛠️ \(session.toolsUsed)")
                    .font(AMORTypography.captionFont)
            }
        }
    }
}

// MARK: - Practices View

struct PracticesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var practices: [PracticeStreak]
    
    var body: some View {
        NavigationStack {
            List {
                Section("Your Practices") {
                    ForEach(practices, id: \.id) { practice in
                        PracticeDetailRow(practice: practice)
                    }
                }
            }
            .navigationTitle("Practices")
        }
    }
}

struct PracticeDetailRow: View {
    let practice: PracticeStreak
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(practice.practiceName)
                    .font(AMORTypography.bodyFont.bold())
                Text("Longest: \(practice.longestStreak) days")
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            AMORComponents.StreakFlame(
                count: practice.currentStreak,
                isBroken: !practice.isActive
            )
        }
    }
}

// MARK: - Cron Health View

struct CronHealthView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var jobs: [CronJobHealth]
    
    var body: some View {
        NavigationStack {
            List {
                Section("Cron Jobs") {
                    ForEach(jobs, id: \.id) { job in
                        CronJobDetailRow(job: job)
                    }
                }
            }
            .navigationTitle("System Health")
        }
    }
}

struct CronJobDetailRow: View {
    let job: CronJobHealth
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(job.statusEmoji)
                    .font(.title2)
                Text(job.jobName)
                    .font(AMORTypography.bodyFont.bold())
                Spacer()
                Text(job.healthStatus.uppercased())
                    .font(AMORTypography.captionFont)
                    .fontWeight(.bold)
                    .foregroundStyle(statusColor)
            }
            
            if let lastRun = job.lastRunDate {
                Text("Last run: \(Self.formatDate(lastRun))")
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)
            }
            
            if let error = job.errorMessage {
                Text("⚠️ \(error)")
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.red)
            }
        }
    }
    
    private var statusColor: Color {
        switch job.healthStatus {
        case "healthy": return .green
        case "warning": return .yellow
        case "critical": return .red
        case "disabled": return .gray
        default: return .blue
        }
    }
    
    private static func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    AMORView()
        .modelContainer(for: [Item.self, DailySession.self, PracticeStreak.self, CronJobHealth.self, DailySummary.self, SecondBrainEntry.self])
}