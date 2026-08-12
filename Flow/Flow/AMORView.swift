/**
 * 🧘 AMORView — Main Dashboard for Daily Operating Rhythm
 *
 * "The heart of contemplation — where sessions are logged, practices honored,
 * and the health of systems silently watched over."
 *
 * v3.1.0 Navigation Architecture: 5 intentional primary tabs.
 * Secondary destinations are reached through elegant sub-navigation
 * within each tab — no buried "More" menu, no lost features.
 *
 * Primary Tabs:
 *   Today     — Living briefing + quick metrics + glanceable health
 *   Practice  — Practices + Activity Heatmap (the doing)
 *   Review    — Sessions + Insights + Dump (the analysis)
 *   Systems   — Cron Health + Hermes Sync + Second Brain (the infrastructure)
 *   Reflect   — Guided Reflection + Rhythm Intelligence (the contemplation)
 */

import SwiftUI
import SwiftData

// MARK: - AMOR Tab Definition

enum AMORTab: Int, CaseIterable {
    case today = 0
    case practice = 1
    case review = 2
    case systems = 3
    case reflect = 4

    var label: String {
        switch self {
        case .today: return "Today"
        case .practice: return "Practice"
        case .review: return "Review"
        case .systems: return "Systems"
        case .reflect: return "Reflect"
        }
    }

    var icon: String {
        switch self {
        case .today: return AMORIconSet.meditation
        case .practice: return AMORIconSet.streak
        case .review: return AMORIconSet.clock
        case .systems: return AMORIconSet.settings
        case .reflect: return "moon.stars.fill"
        }
    }
}

// MARK: - Sub-Navigation Section (for multi-view tabs)

enum AMORSubSection: String, CaseIterable, Hashable {
    // Practice tab
    case practices = "Streaks"
    case activity = "Activity"
    // Review tab
    case sessions = "Sessions"
    case insights = "Insights"
    case weekly = "Weekly"
    case timeline = "Timeline"
    case dump = "Dump"
    // Systems tab
    case cron = "Cron"
    case sync = "Sync"
    case brain = "Brain"
    // Reflect tab
    case reflection = "Reflect"
    case rhythm = "Rhythm"
}

// MARK: - AMORView (Main)

struct AMORView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: AMORTab = .today
    @State private var isLoggingSession = false
    @State private var isCompletingPractice = false

    var body: some View {
        AMORComponents.GradientBackground(gradient: AMORColorPalette.calmWaters) {
            TabView(selection: $selectedTab) {
                // ── 1. Today ──────────────────────────────
                DashboardView()
                    .tabItem {
                        Label(AMORTab.today.label, systemImage: AMORTab.today.icon)
                    }
                    .tag(AMORTab.today)

                // ── 2. Practice (Practices + Activity) ───
                AMORSubNavigationTab(
                    tab: .practice,
                    sections: [.practices, .activity],
                    initialSection: .practices
                ) { section in
                    switch section {
                    case .practices:
                        PracticesView()
                    case .activity:
                        AMORActivityHeatmapView()
                    default:
                        EmptyView()
                    }
                }
                .tabItem {
                    Label(AMORTab.practice.label, systemImage: AMORTab.practice.icon)
                }
                .tag(AMORTab.practice)

                // ── 3. Review (Sessions + Insights + Weekly + Timeline + Dump)
                AMORSubNavigationTab(
                    tab: .review,
                    sections: [.sessions, .insights, .weekly, .timeline, .dump],
                    initialSection: .sessions
                ) { section in
                    switch section {
                    case .sessions:
                        SessionsLogView()
                    case .insights:
                        AMORInsightsView()
                    case .weekly:
                        AMORWeeklyReviewView()
                    case .timeline:
                        AMORProgressTimelineView()
                    case .dump:
                        AMORDumpView()
                    default:
                        EmptyView()
                    }
                }
                .tabItem {
                    Label(AMORTab.review.label, systemImage: AMORTab.review.icon)
                }
                .tag(AMORTab.review)

                // ── 4. Systems (Cron + Sync + Brain) ──────
                AMORSubNavigationTab(
                    tab: .systems,
                    sections: [.cron, .sync, .brain],
                    initialSection: .cron
                ) { section in
                    switch section {
                    case .cron:
                        AMORCronHealthDashboard()
                    case .sync:
                        HermesSessionSyncView()
                    case .brain:
                        AMORSecondBrainView()
                    default:
                        EmptyView()
                    }
                }
                .tabItem {
                    Label(AMORTab.systems.label, systemImage: AMORTab.systems.icon)
                }
                .tag(AMORTab.systems)

                // ── 5. Reflect (Reflection + Rhythm) ──────
                AMORSubNavigationTab(
                    tab: .reflect,
                    sections: [.reflection, .rhythm],
                    initialSection: .reflection
                ) { section in
                    switch section {
                    case .reflection:
                        AMORReflectionView()
                    case .rhythm:
                        AMORRhythmView()
                    default:
                        EmptyView()
                    }
                }
                .tabItem {
                    Label(AMORTab.reflect.label, systemImage: AMORTab.reflect.icon)
                }
                .tag(AMORTab.reflect)
            }
            .sheet(isPresented: $isLoggingSession) {
                LogSessionSheet()
            }
            .sheet(isPresented: $isCompletingPractice) {
                CompletePracticeSheet()
            }
            .onReceive(NotificationCenter.default.publisher(for: .amorLogSession)) { _ in
                isLoggingSession = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .amorCompletePractice)) { _ in
                isCompletingPractice = true
            }
        }
    }
}

// MARK: - Sub-Navigation Tab Container

/// A tab that hosts multiple sub-sections with an elegant segmented selector.
/// Used for tabs that group related features (Review, Systems, Reflect, Practice).
struct AMORSubNavigationTab<Content: View>: View {
    let tab: AMORTab
    let sections: [AMORSubSection]
    let initialSection: AMORSubSection
    @ViewBuilder let content: (AMORSubSection) -> Content

    @State private var selectedSection: AMORSubSection

    init(
        tab: AMORTab,
        sections: [AMORSubSection],
        initialSection: AMORSubSection,
        @ViewBuilder content: @escaping (AMORSubSection) -> Content
    ) {
        self.tab = tab
        self.sections = sections
        self.initialSection = initialSection
        self.content = content
        self._selectedSection = State(initialValue: initialSection)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sub-section selector — elegant segmented strip
                if sections.count > 1 {
                    AMORSectionSelector(
                        sections: sections,
                        selection: $selectedSection
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }

                // Active section content
                content(selectedSection)
            }
            .navigationTitle(tab.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            NotificationCenter.default.post(name: .amorLogSession, object: nil)
                        } label: {
                            Label("Log Session", systemImage: "plus.circle")
                        }

                        Button {
                            NotificationCenter.default.post(name: .amorCompletePractice, object: nil)
                        } label: {
                            Label("Complete Practice", systemImage: "checkmark.circle")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AMORColorPalette.deepIndigo)
                    }
                }
            }
        }
    }
}

// MARK: - Section Selector

/// An elegant scrollable segmented selector for sub-navigation.
/// Uses AMOR's contemplative aesthetic — no harsh system segmented picker.
struct AMORSectionSelector: View {
    let sections: [AMORSubSection]
    @Binding var selection: AMORSubSection

    @Namespace private var animationNamespace

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(sections, id: \.self) { section in
                    let isSelected = section == selection
                    Button {
                        withAnimation(AMORAnimations.thoughtfulAppear) {
                            selection = section
                        }
                    } label: {
                        Text(section.rawValue)
                            .font(AMORTypography.bodyFont)
                            .foregroundStyle(isSelected ? .white : AMORColorPalette.deepIndigo)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(AMORColorPalette.deepIndigo)
                                        .matchedGeometryEffect(id: "selector", in: animationNamespace)
                                } else {
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Notification Names (for cross-tab quick actions)

extension Notification.Name {
    static let amorLogSession = Notification.Name("amorLogSession")
    static let amorCompletePractice = Notification.Name("amorCompletePractice")
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // v3.0.0: Daily Briefing — time-aware synthesis (replaces static header)
                    AMORBriefingView()
                        .frame(maxWidth: .infinity)

                    // v3.7.0: Proactive Nudge Status — shows active alerts and notification health
                    AMORNudgeStatusCard()

                    // Today's Summary Cards (quick metrics)
                    TodaySummaryCard(
                        minutes: totalMinutesToday,
                        sessions: sessionsToday.count,
                        streaks: activeStreaks
                    )

                    // Practices Due Today
                    if !practices.filter({ $0.isDueToday }).isEmpty {
                        PracticesDueSection(practices: practices.filter { $0.isDueToday })
                    }

                    // Activity Heatmap (compact)
                    ActivityHeatmapCard()

                    // v3.4.0: Streak Intelligence card
                    StreakIntelligenceCompactCard()

                    // Hermes Integration card (session-dump automation)
                    HermesSyncCard()

                    // v3.3.0: Auto-Dump Status card
                    AutoDumpStatusCard()

                    // Second Brain status
                    SecondBrainCard()

                    // System Health Overview (from real cron data)
                    SystemHealthOverview(jobs: cronJobs.filter { $0.healthStatus != "healthy" })

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            NotificationCenter.default.post(name: .amorLogSession, object: nil)
                        } label: {
                            Label("Log Session", systemImage: "plus.circle")
                        }

                        Button {
                            NotificationCenter.default.post(name: .amorCompletePractice, object: nil)
                        } label: {
                            Label("Complete Practice", systemImage: "checkmark.circle")
                        }

                        Divider()

                        AMORSettingsButton()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AMORColorPalette.deepIndigo)
                    }
                }
            }
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

    // v3.5.0: Use configurable mood labels from settings
    private var moodOptions: [String] {
        AMORSettingsManager.shared.defaultMoodLabels
    }
    
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
        try? modelContext.save()  // v3.3.0: fix missing save (DATA LOSS bug)
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
                        try? modelContext.save()  // v3.3.0: fix missing save (STREAK DATA LOSS bug)
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

// MARK: - v3.7.0: Nudge Status Card

/// Dashboard card showing the current nudge/notification status.
/// Displays active alerts (streaks at risk, cron failures) and notification health.
struct AMORNudgeStatusCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var practices: [PracticeStreak]
    @Query private var cronJobs: [CronJobHealth]
    @Query private var sessions: [DailySession]

    private var nudgeResult: AMORNudgeResult {
        AMORNudgeEngine.evaluate(
            practices: practices,
            cronJobs: cronJobs,
            sessions: sessions
        )
    }

    private var immediateNudges: [AMORNudgeDescriptor] {
        nudgeResult.allNudges.filter { $0.trigger == .immediate }
    }

    private var hasAlerts: Bool { !immediateNudges.isEmpty }

    var body: some View {
        AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: hasAlerts ? "bell.badge.fill" : "bell.fill")
                        .foregroundStyle(hasAlerts ? AMORColorPalette.dawnOrange : AMORColorPalette.sageGreen)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Proactive Nudges")
                            .font(AMORTypography.titleFont)
                            .foregroundStyle(.primary)
                        Text(hasAlerts ? nudgeResult.summary : "All clear — no alerts")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !AMORNudgeEngine.isNotificationsEnabled() {
                        Image(systemName: "bell.slash.fill")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    }
                }

                // Active alerts list (up to 3)
                if hasAlerts {
                    Divider()

                    ForEach(Array(immediateNudges.prefix(3))) { nudge in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(priorityColor(nudge.priority))
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(nudge.title)
                                    .font(AMORTypography.bodyFont)
                                    .foregroundStyle(.primary)
                                if nudge.priority == .critical || nudge.priority == .high {
                                    Text(nudge.body)
                                        .font(AMORTypography.captionFont)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }

                            Spacer()

                            Image(systemName: nudge.category.icon)
                                .foregroundStyle(.tertiary)
                                .font(.caption)
                        }
                    }

                    if immediateNudges.count > 3 {
                        Text("+ \(immediateNudges.count - 3) more alert\(immediateNudges.count - 3 == 1 ? "" : "s")")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                    }
                } else if AMORNudgeEngine.isNotificationsEnabled() {
                    // Show scheduled notification count
                    Divider()

                    HStack(spacing: 8) {
                        Image(systemName: "clock.badge.checkmark")
                            .foregroundStyle(.secondary)
                            .font(.caption)

                        Text("3 scheduled: morning briefing, evening review, weekly summary")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                }
            }
        }
    }

    private func priorityColor(_ priority: AMORNudgePriority) -> Color {
        switch priority {
        case .critical: return .red
        case .high:     return AMORColorPalette.dawnOrange
        case .normal:   return AMORColorPalette.sageGreen
        case .low:      return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    AMORView()
        .modelContainer(for: [Item.self, DailySession.self, PracticeStreak.self, CronJobHealth.self, DailySummary.self, SecondBrainEntry.self, ReflectionEntry.self])
}