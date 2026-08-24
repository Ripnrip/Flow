/**
 * 📡 AMORCronHealthDashboard — Live Cron Health from Real Data
 *
 * "Where the invisible machinery of automation becomes visible, and
 * the health of every scheduled heartbeat is felt, not assumed."
 *
 * Replaces the static CronHealthView with live data from
 * ~/.hermes/cron/jobs.json — the actual source of truth.
 */

import SwiftUI

struct AMORCronHealthDashboard: View {
    @State private var reader = AMORCronStatusReader()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Overall health
                    healthOverviewCard

                    // Jobs needing attention
                    if !reader.jobsNeedingAttention.isEmpty {
                        attentionCard
                    }

                    // All active jobs
                    jobsListCard

                    // Paused jobs
                    if reader.totalPaused > 0 {
                        pausedJobsCard
                    }
                }
                .padding()
            }
            .navigationTitle("System Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        reader.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                reader.refresh()
            }
            .refreshable {
                reader.refresh()
            }
        }
    }

    // MARK: - Health Overview

    private var healthOverviewCard: some View {
        AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Automation Health")
                        .font(AMORTypography.titleFont)
                        .foregroundStyle(AMORColorPalette.deepIndigo)
                    Spacer()
                    Text(reader.isHermesCronAvailable ? "Live" : "Offline")
                        .font(AMORTypography.captionFont)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background((reader.isHermesCronAvailable ? Color.green : Color.gray).opacity(0.2))
                        .foregroundStyle(reader.isHermesCronAvailable ? .green : .gray)
                        .clipShape(Capsule())
                }

                // Health percentage bar
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(Int(reader.healthPercentage))%")
                            .font(.system(.title, design: .rounded, weight: .bold))
                        Spacer()
                        Text("\(reader.totalHealthy)/\(reader.totalActive) healthy")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: reader.healthPercentage, total: 100)
                        .tint(healthBarColor)
                }

                // Stats row
                HStack(spacing: 16) {
                    cronStat(icon: "checkmark.circle.fill", count: reader.totalHealthy, label: "Healthy", color: .green)
                    Divider().frame(height: 30)
                    cronStat(icon: "exclamationmark.triangle.fill", count: reader.totalFailing, label: "Failing", color: .red)
                    Divider().frame(height: 30)
                    cronStat(icon: "pause.circle.fill", count: reader.totalPaused, label: "Paused", color: .gray)
                }

                if let lastRefresh = reader.lastRefresh {
                    Text("Last refresh: \(lastRefresh.formatted(.relative(presentation: .named)))")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var healthBarColor: Color {
        switch reader.healthPercentage {
        case 90...: return .green
        case 70..<90: return .yellow
        case 50..<70: return .orange
        default: return .red
        }
    }

    // MARK: - Attention Card

    private var attentionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("Needs Attention")
                    .font(AMORTypography.titleFont)
                    .foregroundStyle(.red)
            }

            ForEach(reader.jobsNeedingAttention) { job in
                cronJobRow(job, showAttention: true)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.red.opacity(0.08)))
    }

    // MARK: - Jobs List

    private var jobsListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Jobs (\(reader.totalActive))")
                .font(AMORTypography.titleFont)
                .foregroundStyle(AMORColorPalette.deepIndigo)

            ForEach(reader.activeJobs) { job in
                cronJobRow(job, showAttention: false)
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Paused Jobs

    private var pausedJobsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paused Jobs (\(reader.totalPaused))")
                .font(AMORTypography.titleFont)
                .foregroundStyle(.secondary)

            ForEach(reader.jobs.filter { !$0.enabled }) { job in
                cronJobRow(job, showAttention: false)
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Components

    private func cronJobRow(_ job: AMORCronJob, showAttention: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(job.statusEmoji)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(job.name)
                        .font(AMORTypography.bodyFont.bold())
                    Text(job.scheduleDisplay)
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(job.healthStatus.uppercased())
                    .font(AMORTypography.captionFont.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(healthColor(for: job.healthStatus).opacity(0.2))
                    .foregroundStyle(healthColor(for: job.healthStatus))
                    .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                if let _ = job.lastRunAt {
                    Label(job.relativeLastRun, systemImage: "clock.arrow.circlepath")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }

                if let _ = job.nextRunAt, job.enabled {
                    Label(job.relativeNextRun, systemImage: "calendar")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }

                if job.completedRuns > 0 {
                    Label("\(job.completedRuns) runs", systemImage: "checkmark.circle")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = job.lastError, !error.isEmpty {
                Text("⚠️ \(error)")
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private func cronStat(icon: String, count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text("\(count)")
                .font(AMORTypography.bodyFont.bold())
            Text(label)
                .font(AMORTypography.captionFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func healthColor(for status: String) -> Color {
        switch status {
        case "healthy": return .green
        case "failing", "stale": return .red
        case "missed": return .orange
        case "pending", "never_run", "unknown": return .yellow
        case "paused": return .gray
        default: return .blue
        }
    }
}
