/**
 * 🌉 HermesSyncCard — Dashboard Integration Widget
 *
 * "A window into the Hermes realm, showing the live pulse of automation
 * and the flow of sessions between the agent and the contemplative mind."
 *
 * v2.1.0 — Session-Dump Automation
 */

import SwiftUI
import SwiftData

struct HermesSyncCard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var engine = HermesIntegrationEngine()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(AMORColorPalette.deepIndigo)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Hermes Integration")
                        .font(AMORTypography.bodyFont.bold())
                    Text(engine.isHermesAvailable ? "Connected to local agent" : "Agent not detected")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Sync status badge
                Text(engine.syncStatus.rawValue)
                    .font(AMORTypography.captionFont)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(syncStatusColor.opacity(0.2))
                    .foregroundStyle(syncStatusColor)
                    .clipShape(Capsule())
            }

            // Stats row
            if engine.isHermesAvailable {
                HStack(spacing: 16) {
                    SyncStat(
                        icon: "doc.text.fill",
                        label: "Sessions",
                        value: "\(engine.totalSessionsDiscovered)"
                    )

                    Divider()
                        .frame(height: 30)

                    SyncStat(
                        icon: "arrow.down.circle.fill",
                        label: "Imported",
                        value: "\(engine.sessionsImportedThisCycle)"
                    )

                    Divider()
                        .frame(height: 30)

                    SyncStat(
                        icon: "gearshape.fill",
                        label: "Cron Jobs",
                        value: "\(engine.totalCronJobsDiscovered)"
                    )
                }
                .padding(.vertical, 4)

                // Recent imports preview
                if !engine.recentImports.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recently Synced")
                            .font(AMORTypography.captionFont.bold())
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)

                        ForEach(engine.recentImports.prefix(3)) { session in
                            HStack {
                                Image(systemName: "circle.fill")
                                    .foregroundStyle(AMORColorPalette.deepIndigo)
                                    .font(.system(size: 6))

                                Text(session.title)
                                    .font(AMORTypography.captionFont)
                                    .lineLimit(1)

                                Spacer()

                                Text(session.inferredDomain)
                                    .font(AMORTypography.captionFont)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.thinMaterial)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Last sync time
                if let lastSync = engine.lastSyncDate {
                    Text("Last sync: \(lastSync.formatted(.relative(presentation: .named)))")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }
            }

            // Sync button
            Button {
                engine.performFullSync(into: modelContext)
            } label: {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    .font(AMORTypography.bodyFont)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(AMORColorPalette.deepIndigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!engine.isHermesAvailable)
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            // Auto-sync on first appearance
            if engine.isHermesAvailable && engine.lastSyncDate == nil {
                engine.performFullSync(into: modelContext)
            }
        }
    }

    private var syncStatusColor: Color {
        switch engine.syncStatus {
        case .synced: return .green
        case .syncing: return .blue
        case .error: return .red
        case .unavailable: return .gray
        case .idle: return .secondary
        }
    }
}

// MARK: - Sync Stat Component

private struct SyncStat: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AMORColorPalette.deepIndigo)
            Text(value)
                .font(AMORTypography.bodyFont.bold())
            Text(label)
                .font(AMORTypography.captionFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Session Sync Detail View (for a full tab if needed)

struct HermesSessionSyncView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var engine = HermesIntegrationEngine()
    @State private var stats: SessionStats?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Connection status
                    connectionCard

                    // Weekly stats
                    if let stats = stats {
                        weeklyStatsCard(stats)
                    }

                    // Sync controls
                    syncControls

                    // Session browser
                    sessionBrowser
                }
                .padding()
            }
            .navigationTitle("Hermes Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear { refresh() }
        }
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: engine.isHermesAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(engine.isHermesAvailable ? .green : .red)
                    .font(.title2)

                Text(engine.isHermesAvailable ? "Hermes Agent Detected" : "Hermes Not Found")
                    .font(AMORTypography.bodyFont.bold())
            }

            if engine.isHermesAvailable {
                Text("Running on the same machine — direct filesystem access enabled.")
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)
            } else {
                Text("Ensure Hermes is installed at ~/.hermes or set HERMES_HOME")
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func weeklyStatsCard(_ stats: SessionStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(AMORTypography.bodyFont.bold())

            HStack {
                StatBlock(label: "Sessions", value: "\(stats.totalSessions)")
                StatBlock(label: "Focus Hours", value: String(format: "%.1f", stats.totalFocusHours))
                StatBlock(label: "Avg Min", value: "\(stats.averageSessionMinutes)")
            }

            if !stats.topDomains.isEmpty {
                Text("Top Domains")
                    .font(AMORTypography.captionFont.bold())
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                ForEach(stats.topDomains, id: \.domain) { domain in
                    HStack {
                        Text(domain.domain)
                            .font(AMORTypography.captionFont)
                        Spacer()
                        Text("\(domain.count) sessions")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var syncControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Sync")
                .font(AMORTypography.bodyFont.bold())

            Text("Import Hermes conversation sessions as AMOR work sessions. Deduplicated by session ID.")
                .font(AMORTypography.captionFont)
                .foregroundStyle(.secondary)

            Button {
                engine.syncSessions(into: modelContext)
            } label: {
                Label("Import Sessions (Last 7 Days)", systemImage: "tray.and.arrow.down.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AMORColorPalette.deepIndigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!engine.isHermesAvailable)
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var sessionBrowser: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Hermes Sessions")
                .font(AMORTypography.bodyFont.bold())

            let sessions = engine.recentImports

            if sessions.isEmpty {
                Text("No sessions imported yet. Tap sync above to import.")
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)
                    .padding(.vertical)
            } else {
                ForEach(sessions) { session in
                    SessionRow(session: session)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func refresh() {
        engine.syncSessions(into: modelContext)
        stats = engine.getSessionStats(daysBack: 7)
    }
}

private struct StatBlock: View {
    let label: String
    let value: String

    var body: some View {
        VStack {
            Text(value)
                .font(AMORTypography.titleFont.bold())
            Text(label)
                .font(AMORTypography.captionFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SessionRow: View {
    let session: HermesSession

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(AMORTypography.bodyFont)
                    .lineLimit(2)

                HStack {
                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text("\(session.estimatedDurationMinutes)m")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(session.inferredDomain)
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(AMORColorPalette.deepIndigo)
                }
            }

            Spacer()

            Text("\(session.messageCount)")
                .font(AMORTypography.captionFont.bold())
                .foregroundStyle(.white)
                .padding(8)
                .background(AMORColorPalette.deepIndigo)
                .clipShape(Circle())
        }
        .padding(.vertical, 4)
    }
}
