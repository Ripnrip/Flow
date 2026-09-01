/**
 * AMORSettings — Configuration & Settings Engine
 *
 * "The compass by which AMOR orients itself — configurable paths, preferences,
 * and defaults that shape the user's daily operating rhythm. No more hardcoded
 * assumptions. The user defines their own sanctuary."
 *
 * v3.5.0 — Settings & Configuration Engine
 *
 * Features:
 *   - Hermes home directory configuration (auto-detected, user-overridable)
 *   - Obsidian vault path for second-brain integration
 *   - Dump automation preferences (daily/weekly/auto-write)
 *   - Notification settings (briefing reminders, streak alerts, cron failures)
 *   - Default practice management (add/remove/reorder)
 *   - Data management (export, clear, storage stats)
 *   - Appearance preferences (gradient theme selection)
 */

import Foundation
import SwiftUI

// MARK: - AMORSettingsManager

/// Centralized settings manager using UserDefaults with @AppStorage-compatible keys.
/// Foundation-only — no SwiftUI dependencies for the logic layer.
final class AMORSettingsManager: ObservableObject {

    // MARK: - Keys

    enum Key: String {
        case hermesHomePath = "amor.settings.hermesHomePath"
        case obsidianVaultPath = "amor.settings.obsidianVaultPath"
        case autoDumpEnabled = "amor.settings.autoDumpEnabled"
        case autoDumpTime = "amor.settings.autoDumpTime"
        case weeklyDumpEnabled = "amor.settings.weeklyDumpEnabled"
        case notificationEnabled = "amor.settings.notificationsEnabled"
        case briefingReminderTime = "amor.settings.briefingReminderTime"
        case streakAlertsEnabled = "amor.settings.streakAlertsEnabled"
        case cronFailureAlerts = "amor.settings.cronFailureAlerts"
        case selectedTheme = "amor.settings.selectedTheme"
        case defaultMoodLabels = "amor.settings.defaultMoodLabels"
        case defaultToolLabels = "amor.settings.defaultToolLabels"
        case sessionDurationPresets = "amor.settings.sessionDurationPresets"
    }

    // MARK: - Singleton

    static let shared = AMORSettingsManager()
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Hermes Integration Paths

    /// Hermes home directory. Auto-detected from HERMES_HOME env var or defaults to ~/.hermes
    var hermesHomePath: String {
        get {
            if let stored = defaults.string(forKey: Key.hermesHomePath.rawValue), !stored.isEmpty {
                return stored
            }
            // Auto-detect
            if let envPath = ProcessInfo.processInfo.environment["HERMES_HOME"] {
                return envPath
            }
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".hermes").path
        }
        set {
            defaults.set(newValue, forKey: Key.hermesHomePath.rawValue)
        }
    }

    var hermesHomeURL: URL {
        URL(fileURLWithPath: hermesHomePath)
    }

    var isHermesAvailable: Bool {
        FileManager.default.fileExists(atPath: hermesHomePath)
    }

    /// Obsidian vault root path. Auto-detected by searching common locations.
    var obsidianVaultPath: String {
        get {
            if let stored = defaults.string(forKey: Key.obsidianVaultPath.rawValue), !stored.isEmpty {
                return stored
            }
            // Auto-detect: ~/wiki is the canonical vault location
            let home = FileManager.default.homeDirectoryForCurrentUser
            return home.appendingPathComponent("wiki").path
        }
        set {
            defaults.set(newValue, forKey: Key.obsidianVaultPath.rawValue)
        }
    }

    var obsidianVaultURL: URL {
        URL(fileURLWithPath: obsidianVaultPath)
    }

    var isObsidianAvailable: Bool {
        FileManager.default.fileExists(atPath: obsidianVaultPath)
    }

    // MARK: - Dump Automation

    var autoDumpEnabled: Bool {
        get { defaults.object(forKey: Key.autoDumpEnabled.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.autoDumpEnabled.rawValue) }
    }

    var weeklyDumpEnabled: Bool {
        get { defaults.object(forKey: Key.weeklyDumpEnabled.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.weeklyDumpEnabled.rawValue) }
    }

    // MARK: - Notifications

    var notificationsEnabled: Bool {
        get { defaults.object(forKey: Key.notificationEnabled.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.notificationEnabled.rawValue) }
    }

    var streakAlertsEnabled: Bool {
        get { defaults.object(forKey: Key.streakAlertsEnabled.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.streakAlertsEnabled.rawValue) }
    }

    var cronFailureAlertsEnabled: Bool {
        get { defaults.object(forKey: Key.cronFailureAlerts.rawValue) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.cronFailureAlerts.rawValue) }
    }

    var briefingReminderTime: String {
        get { defaults.string(forKey: Key.briefingReminderTime.rawValue) ?? "07:00" }
        set { defaults.set(newValue, forKey: Key.briefingReminderTime.rawValue) }
    }

    // MARK: - Appearance

    var selectedTheme: String {
        get { defaults.string(forKey: Key.selectedTheme.rawValue) ?? "calmWaters" }
        set { defaults.set(newValue, forKey: Key.selectedTheme.rawValue) }
    }

    /// Returns the gradient for the currently selected theme
    var activeGradient: LinearGradient {
        switch selectedTheme {
        case "morningDawn": return AMORColorPalette.morningDawn
        case "warmEmbrace": return AMORColorPalette.warmEmbrace
        case "calmWaters": return AMORColorPalette.calmWaters
        default: return AMORColorPalette.calmWaters
        }
    }

    // MARK: - Default Labels (for quick session logging)

    var defaultMoodLabels: [String] {
        get {
            if let data = defaults.data(forKey: Key.defaultMoodLabels.rawValue),
               let decoded = try? JSONDecoder().decode([String].self, from: data) {
                return decoded
            }
            return ["focused", "energized", "calm", "tired", "neutral", "creative", "frustrated"]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.defaultMoodLabels.rawValue)
            }
        }
    }

    var defaultToolLabels: [String] {
        get {
            if let data = defaults.data(forKey: Key.defaultToolLabels.rawValue),
               let decoded = try? JSONDecoder().decode([String].self, from: data) {
                return decoded
            }
            return ["Hermes", "Terminal", "Xcode", "Browser", "Obsidian", "Python", "Swift", "Git"]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.defaultToolLabels.rawValue)
            }
        }
    }

    var sessionDurationPresets: [Int] {
        get {
            if let data = defaults.data(forKey: Key.sessionDurationPresets.rawValue),
               let decoded = try? JSONDecoder().decode([Int].self, from: data) {
                return decoded
            }
            return [15, 25, 30, 45, 60, 90, 120]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.sessionDurationPresets.rawValue)
            }
        }
    }

    // MARK: - Data Management

    /// Calculate the storage size of AMOR's SwiftData store
    var swiftDataStoreSize: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let appSupport = appSupport else { return "Unknown" }

        let storeURL = appSupport.appendingPathComponent("default.store")
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: storeURL.path),
              let size = attrs[.size] as? Int else {
            return "Unknown"
        }

        if size > 1_000_000 {
            return String(format: "%.1f MB", Double(size) / 1_000_000)
        } else if size > 1_000 {
            return String(format: "%.1f KB", Double(size) / 1_000)
        }
        return "\(size) bytes"
    }

    /// Count of dump files generated
    var dumpFileCount: Int {
        let dumpDir = hermesHomeURL.appendingPathComponent("logs/amor-dumps")
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dumpDir.path) else {
            return 0
        }
        return contents.filter { $0.hasSuffix(".md") }.count
    }

    // MARK: - Reset

    /// Reset all settings to defaults
    func resetToDefaults() {
        for key in [Key.hermesHomePath, .obsidianVaultPath, .autoDumpEnabled, .autoDumpTime,
                     .weeklyDumpEnabled, .notificationEnabled, .briefingReminderTime,
                     .streakAlertsEnabled, .cronFailureAlerts, .selectedTheme,
                     .defaultMoodLabels, .defaultToolLabels, .sessionDurationPresets] {
            defaults.removeObject(forKey: key.rawValue)
        }
    }
}

// MARK: - Theme Options

enum AMORThemeOption: String, CaseIterable, Identifiable {
    case calmWaters = "calmWaters"
    case morningDawn = "morningDawn"
    case warmEmbrace = "warmEmbrace"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .calmWaters: return "Calm Waters"
        case .morningDawn: return "Morning Dawn"
        case .warmEmbrace: return "Warm Embrace"
        }
    }

    var description: String {
        switch self {
        case .calmWaters: return "Serene blues and gentle greens"
        case .morningDawn: return "Deep indigo to warm sunrise"
        case .warmEmbrace: return "Warm sand, clay, and gold"
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .calmWaters: return AMORColorPalette.calmWaters
        case .morningDawn: return AMORColorPalette.morningDawn
        case .warmEmbrace: return AMORColorPalette.warmEmbrace
        }
    }

    var previewColors: [Color] {
        switch self {
        case .calmWaters:
            return [Color(red: 0.4, green: 0.6, blue: 0.7), Color(red: 0.8, green: 0.85, blue: 0.9)]
        case .morningDawn:
            return [AMORColorPalette.deepIndigo, AMORColorPalette.dawnOrange]
        case .warmEmbrace:
            return [AMORColorPalette.warmSand, AMORColorPalette.mutedGold]
        }
    }
}

// MARK: - Settings View

struct AMORSettingsView: View {
    @ObservedObject private var settings = AMORSettingsManager.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showResetConfirmation = false
    @State private var showExportSheet = false
    @State private var newMoodLabel = ""
    @State private var newToolLabel = ""
    @State private var newDurationPreset = ""
    @State private var showingAddMood = false
    @State private var showingAddTool = false
    @State private var showingAddDuration = false

    var body: some View {
        AMORComponents.GradientBackground(gradient: settings.activeGradient) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // Integration Status Banner
                        integrationStatusSection

                        // Hermes Integration
                        settingsSection(
                            title: "Hermes Integration",
                            icon: "network",
                            content: hermesSection
                        )

                        // Obsidian / Second Brain
                        settingsSection(
                            title: "Second Brain",
                            icon: "brain.head.profile",
                            content: obsidianSection
                        )

                        // Dump Automation
                        settingsSection(
                            title: "Session Dump Automation",
                            icon: "doc.text.fill",
                            content: dumpAutomationSection
                        )

                        // Notifications
                        settingsSection(
                            title: "Notifications",
                            icon: "bell.fill",
                            content: notificationsSection
                        )

                        // Appearance
                        settingsSection(
                            title: "Appearance",
                            icon: "paintpalette.fill",
                            content: appearanceSection
                        )

                        // Session Logging Defaults
                        settingsSection(
                            title: "Session Logging Defaults",
                            icon: "list.clipboard.fill",
                            content: loggingDefaultsSection
                        )

                        // Data Management
                        settingsSection(
                            title: "Data & Storage",
                            icon: "internaldrive.fill",
                            content: dataManagementSection
                        )

                        // About
                        aboutSection
                    }
                    .padding()
                }
                .navigationTitle("Settings")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.large)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(.white)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .alert("Reset All Settings?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    settings.resetToDefaults()
                }
            } message: {
                Text("This will restore all settings to their defaults. Your logged sessions and streaks will not be affected.")
            }
        }
    }

    // MARK: - Integration Status Banner

    private var integrationStatusSection: some View {
        AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("System Status")
                    .font(AMORTypography.titleFont)
                    .foregroundStyle(.primary)

                HStack(spacing: 16) {
                    StatusIndicator(
                        label: "Hermes",
                        isAvailable: settings.isHermesAvailable,
                        icon: "server.rack"
                    )

                    Divider()
                        .frame(height: 40)

                    StatusIndicator(
                        label: "Obsidian",
                        isAvailable: settings.isObsidianAvailable,
                        icon: "book.fill"
                    )
                }
            }
        }
    }

    // MARK: - Hermes Section

    private var hermesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hermes Home Directory")
                    .font(.headline)
                Text(settings.hermesHomePath)
                    .font(AMORTypography.monospaceFont)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if settings.isHermesAvailable {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
            } else {
                Label("Not found — check path", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Obsidian Section

    private var obsidianSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Obsidian Vault Path")
                    .font(.headline)
                Text(settings.obsidianVaultPath)
                    .font(AMORTypography.monospaceFont)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if settings.isObsidianAvailable {
                Label("Vault accessible", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
            } else {
                Label("Vault not found", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Dump Automation Section

    private var dumpAutomationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: Binding(
                get: { settings.autoDumpEnabled },
                set: { settings.autoDumpEnabled = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-Generate Daily Dump")
                        .font(.headline)
                    Text("Creates a markdown summary on every app foreground")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(AMORColorPalette.sageGreen)

            Toggle(isOn: Binding(
                get: { settings.weeklyDumpEnabled },
                set: { settings.weeklyDumpEnabled = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-Generate Weekly Review")
                        .font(.headline)
                    Text("Produces a week-in-review markdown each week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(AMORColorPalette.sageGreen)

            HStack {
                Image(systemName: "doc.fill")
                    .foregroundStyle(.secondary)
                Text("Dump files generated:")
                    .font(.subheadline)
                Spacer()
                Text("\(settings.dumpFileCount)")
                    .font(.headline)
                    .foregroundStyle(AMORColorPalette.dawnOrange)
            }
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: Binding(
                get: { settings.notificationsEnabled },
                set: { settings.notificationsEnabled = $0 }
            )) {
                Text("Enable Notifications")
                    .font(.headline)
            }
            .tint(AMORColorPalette.sageGreen)

            if settings.notificationsEnabled {
                Divider()

                Text("Nudge Categories")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                // v3.7.0: Per-category toggles from the nudge engine
                ForEach(AMORNudgeCategory.allCases, id: \.rawValue) { category in
                    Toggle(isOn: Binding(
                        get: { AMORNudgeEngine.isCategoryEnabled(category) },
                        set: { newValue in
                            UserDefaults.standard.set(newValue, forKey: category.settingsKey)
                        }
                    )) {
                        HStack(spacing: 10) {
                            Image(systemName: category.icon)
                                .foregroundStyle(AMORColorPalette.deepIndigo)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.displayName)
                                    .font(.subheadline)
                                if category == .inactivity {
                                    Text("Gentle reminder after 48h of no sessions")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                    .tint(AMORColorPalette.sageGreen)
                }

                Divider()

                // Briefing time picker
                HStack {
                    Image(systemName: "sun.max")
                        .foregroundStyle(.secondary)
                    Text("Morning Briefing Time")
                        .font(.subheadline)
                    Spacer()
                    Text(settings.briefingReminderTime)
                        .font(.subheadline)
                        .foregroundStyle(AMORColorPalette.dawnOrange)
                }
            }
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Theme")
                .font(.headline)

            ForEach(AMORThemeOption.allCases) { theme in
                Button {
                    settings.selectedTheme = theme.rawValue
                } label: {
                    HStack {
                        // Theme preview
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: theme.previewColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(theme.displayName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(theme.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if settings.selectedTheme == theme.rawValue {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AMORColorPalette.sageGreen)
                                .font(.title3)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Logging Defaults Section

    private var loggingDefaultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Mood labels
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Mood Labels")
                        .font(.headline)
                    Spacer()
                    Button {
                        showingAddMood.toggle()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AMORColorPalette.dawnOrange)
                    }
                }

                FlowingChips(items: settings.defaultMoodLabels) { mood in
                    Text(mood.capitalized)
                }

                if showingAddMood {
                    HStack {
                        TextField("New mood label", text: $newMoodLabel)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            let trimmed = newMoodLabel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            if !trimmed.isEmpty && !settings.defaultMoodLabels.contains(trimmed) {
                                settings.defaultMoodLabels.append(trimmed)
                                newMoodLabel = ""
                                showingAddMood = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AMORColorPalette.sageGreen)
                    }
                }
            }

            Divider()

            // Tool labels
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tool Labels")
                        .font(.headline)
                    Spacer()
                    Button {
                        showingAddTool.toggle()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AMORColorPalette.dawnOrange)
                    }
                }

                FlowingChips(items: settings.defaultToolLabels) { tool in
                    Text(tool)
                }

                if showingAddTool {
                    HStack {
                        TextField("New tool label", text: $newToolLabel)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            let trimmed = newToolLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty && !settings.defaultToolLabels.contains(trimmed) {
                                settings.defaultToolLabels.append(trimmed)
                                newToolLabel = ""
                                showingAddTool = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AMORColorPalette.sageGreen)
                    }
                }
            }

            Divider()

            // Duration presets
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Duration Presets (minutes)")
                        .font(.headline)
                    Spacer()
                    Button {
                        showingAddDuration.toggle()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AMORColorPalette.dawnOrange)
                    }
                }

                FlowingChips(items: settings.sessionDurationPresets.map { String($0) }) { duration in
                    Text("\(duration)m")
                }

                if showingAddDuration {
                    HStack {
                        TextField("Minutes", text: $newDurationPreset)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                        Button("Add") {
                            if let minutes = Int(newDurationPreset), minutes > 0 {
                                if !settings.sessionDurationPresets.contains(minutes) {
                                    var presets = settings.sessionDurationPresets
                                    presets.append(minutes)
                                    presets.sort()
                                    settings.sessionDurationPresets = presets
                                }
                                newDurationPreset = ""
                                showingAddDuration = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AMORColorPalette.sageGreen)
                    }
                }
            }
        }
    }

    // MARK: - Data Management Section

    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "internaldrive")
                    .foregroundStyle(.secondary)
                Text("SwiftData Store Size:")
                    .font(.subheadline)
                Spacer()
                Text(settings.swiftDataStoreSize)
                    .font(.headline)
                    .foregroundStyle(AMORColorPalette.dawnOrange)
            }

            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                Text("Dump Files:")
                    .font(.subheadline)
                Spacer()
                Text("\(settings.dumpFileCount)")
                    .font(.headline)
                    .foregroundStyle(AMORColorPalette.dawnOrange)
            }

            Divider()

            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                Label("Reset All Settings to Defaults", systemImage: "arrow.counterclockwise.circle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        AMORComponents.ContemplativeCard {
            VStack(alignment: .center, spacing: 8) {
                Image(systemName: AMORIconSet.meditation)
                    .font(.largeTitle)
                    .foregroundStyle(AMORColorPalette.deepIndigo)

                Text("AMOR")
                    .font(AMORTypography.headingFont)

                Text("Automated Memory & Operating Rhythm")
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)

                Text("v5.0.0")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)

                Text("\"The heart of contemplation — where sessions are logged, practices honored, and the health of systems silently watched over.\"")
                    .font(AMORTypography.bodyFont)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .italic()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Reusable Section Card

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(AMORColorPalette.deepIndigo)
                    Text(title)
                        .font(AMORTypography.titleFont)
                }

                content()
            }
        }
    }
}

// MARK: - Status Indicator

private struct StatusIndicator: View {
    let label: String
    let isAvailable: Bool
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isAvailable ? .green : .secondary)

            Text(label)
                .font(.caption)
                .foregroundStyle(.primary)

            Text(isAvailable ? "Connected" : "Offline")
                .font(.caption2)
                .foregroundStyle(isAvailable ? .green : .secondary)
        }
        .frame(width: 80)
    }
}

// MARK: - Flowing Chips

/// Displays a list of items as wrapping chips. Used for mood/tool labels.
struct FlowingChips<Item: Hashable, ChipContent: View>: View {
    let items: [Item]
    @ViewBuilder let chipContent: (Item) -> ChipContent

    private let columns = [
        GridItem(.adaptive(minimum: 70), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                chipContent(item)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
            }
        }
    }
}

// MARK: - Compact Settings Access

/// A compact gear button that opens the full settings view as a sheet.
struct AMORSettingsButton: View {
    @State private var showSettings = false

    var body: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.title3)
                .foregroundStyle(.white)
        }
        .sheet(isPresented: $showSettings) {
            AMORSettingsView()
        }
    }
}

// MARK: - Notification.Name Extensions

extension Notification.Name {
    static let amorSettingsChanged = Notification.Name("amorSettingsChanged")
}
