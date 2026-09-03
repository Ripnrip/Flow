//
//  AMORGroundTruthView.swift
//  Flow — AMOR v4.0.0
//
//  Ground Truth card for the Dashboard. Shows practice evidence read
//  directly from the Hermes files on this Mac — not manual taps.
//  Every number here traces to a file on disk:
//
//    Gita  ← ~/.hermes/logs/gita_progress.json
//    Gym   ← ~/.hermes/logs/gym_selfie_progress.json
//    Dumps ← ~/wiki/raw/daily-summaries/session-dump-*.md
//

import SwiftUI
import SwiftData

struct AMORGroundTruthCard: View {
    @State private var result: AMORGroundTruthSyncResult?
    @State private var lastSync: Date?
    @State private var isSyncing = false
    @State private var alibis: [String: AMORAlibi] = [:]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        AMORComponents.ContemplativeCard {
            VStack(alignment: .leading, spacing: 14) {
                // ── Header ──────────────────────────────────────────
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(AMORColorPalette.sageGreen)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ground Truth")
                            .font(AMORTypography.bodyFont.bold())
                        Text(subtitle)
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        runSync()
                    } label: {
                        if isSyncing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Sync ground truth now")
                }

                Divider()

                if let result {
                    // ── v5.1.0 The Alibi — pipe-break banner ──────────
                    // A ledger-proven pipeline break reframes the streak
                    // card's story before the evidence rows render.
                    if let gitaAlibi = alibis["Gita"] {
                        AlibiBanner(alibi: gitaAlibi)
                    }

                    // ── Gita evidence ────────────────────────────────
                    evidenceRow(
                        icon: "book.fill",
                        tint: AMORColorPalette.twilightPurple,
                        title: "Gita",
                        value: "\(result.gitaDaysCompleted) days",
                        detail: result.gitaCurrentPosition.isEmpty
                            ? "No progress file"
                            : "\(result.gitaCurrentPosition) · \(result.gitaLastCompletedDate ?? "—")"
                    )

                    // ── Gym evidence ─────────────────────────────────
                    evidenceRow(
                        icon: "dumbbell.fill",
                        tint: AMORColorPalette.dawnOrange,
                        title: "Gym",
                        value: gymValueLabel,
                        detail: gymDetailLabel
                    )

                    // ── Meditation evidence (v4.1.0) ─────────────────
                    evidenceRow(
                        icon: "figure.mind.and.body",
                        tint: AMORColorPalette.sageGreen,
                        title: "Meditation",
                        value: meditationValueLabel,
                        detail: meditationDetailLabel
                    )

                    // ── EOD dumps ────────────────────────────────────
                    evidenceRow(
                        icon: "doc.text.magnifyingglass",
                        tint: AMORColorPalette.deepIndigo,
                        title: "Session dumps",
                        value: "\(result.dumpDaysIngested) days",
                        detail: dumpDetailLabel
                    )

                    // ── Cron health from newest dump ─────────────────
                    if result.cronOkCount > 0 || result.cronErrorCount > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: result.cronErrorCount > 0 ? "exclamationmark.triangle.fill" : "gearshape.fill")
                                .font(.caption)
                                .foregroundStyle(result.cronErrorCount > 0 ? AMORColorPalette.dawnOrange : AMORColorPalette.sageGreen)
                            Text("\(result.cronOkCount) cron jobs ok")
                                .font(AMORTypography.captionFont)
                                .foregroundStyle(.secondary)
                            if result.cronErrorCount > 0 {
                                Text("· \(result.cronErrorCount) erroring")
                                    .font(AMORTypography.captionFont)
                                    .foregroundStyle(AMORColorPalette.dawnOrange)
                            }
                        }
                    }

                    // ── Source footnote ──────────────────────────────
                    Text("Sources: ~/.hermes/logs · ~/wiki/raw/daily-summaries — synced \(relativeSyncLabel)")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("No ground truth synced yet. Tap ⟳ to read the Hermes files on this Mac.")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            result = AMORGroundTruthSyncer.loadLastResult()
            lastSync = AMORGroundTruthSyncer.lastSyncDate()
        }
    }

    // MARK: - Sub-views

    private func evidenceRow(icon: String, tint: Color, title: String, value: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AMORTypography.bodyFont)
                Text(detail)
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(value)
                .font(AMORTypography.subtitleFont.bold())
                .foregroundStyle(tint)
        }
    }

    // MARK: - Derived labels

    private var subtitle: String {
        if lastSync == nil {
            return "Evidence read from this Mac"
        }
        return "Evidence synced from this Mac"
    }

    private var gymValueLabel: String {
        guard let result else { return "—" }
        let recent = result.gymEvidenceDates
        if recent.contains(AMORGroundTruthEngine.localDateString(Date())) {
            return "Today ✓"
        }
        return recent.isEmpty ? "none logged" : "\(recent.count) days"
    }

    private var gymDetailLabel: String {
        guard let result else { return "No selfie progress file" }
        if result.gymEvidenceDates.isEmpty {
            return "Reminder fires 5 PM — snap when you go"
        }
        return "Last: \(result.gymEvidenceDates.first ?? "—")"
    }

    private var meditationValueLabel: String {
        guard let result else { return "—" }
        let recent = result.meditationEvidenceDates
        if recent.contains(AMORGroundTruthEngine.localDateString(Date())) {
            return "Today ✓"
        }
        return recent.isEmpty ? "none logged" : "\(recent.count) days"
    }

    private var meditationDetailLabel: String {
        guard let result else { return "No meditation ledger" }
        if result.meditationEvidenceDates.isEmpty {
            return "Evening check-in — even 5 min counts"
        }
        return "Last: \(result.meditationEvidenceDates.first ?? "—")"
    }

    private var dumpDetailLabel: String {
        guard let result else { return "—" }
        var parts: [String] = []
        if result.dumpSessionsFound > 0 {
            parts.append("\(result.dumpSessionsFound) sessions")
        }
        if !result.dumpToolsDiscovered.isEmpty {
            parts.append("\(result.dumpToolsDiscovered.count) tools")
        }
        if !result.dumpSkillsDiscovered.isEmpty {
            parts.append("\(result.dumpSkillsDiscovered.count) skills")
        }
        return parts.isEmpty ? "Last 7 days ingested" : parts.joined(separator: " · ")
    }

    private var relativeSyncLabel: String {
        guard let lastSync else { return "never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }

    // MARK: - Actions

    private func runSync() {
        isSyncing = true
        // Syncer is MainActor + synchronous file I/O; hop out and back.
        Task { @MainActor in
            result = AMORGroundTruthSyncer.sync(into: modelContext)
            lastSync = AMORGroundTruthSyncer.lastSyncDate()
            // v5.1.0 — attribute any trailing break to its true cause
            // (one ledger read; nil-safe when the ledger is absent).
            alibis = AMORAlibiEngine.alibisFor(
                [("Gita", result?.gitaLastCompletedDate.flatMap(AMORGroundTruthEngine.parseLocalDayString)),
                 ("Gym", result?.gymEvidenceDates.first.flatMap(AMORGroundTruthEngine.parseLocalDayString)),
                 ("Meditation", result?.meditationEvidenceDates.first.flatMap(AMORGroundTruthEngine.parseLocalDayString))],
                hermesHome: AMORGroundTruthEngine.hermesHome()
            )
            isSyncing = false
        }
    }
}

// MARK: - Alibi Banner (v5.1.0)

/// The pipe-break banner: ledger-proven cause attribution for a
/// practice's trailing break. Orange (infrastructure), never red
/// (character) — the streak number below stays exactly what the
/// dates say.
private struct AlibiBanner: View {
    let alibi: AMORAlibi

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(alibi.headline)
                    .font(AMORTypography.captionFont.bold())
            } icon: {
                Image(systemName: "bolt.slash.fill")
                    .foregroundStyle(AMORColorPalette.dawnOrange)
            }

            Text(alibi.detail)
                .font(AMORTypography.captionFont)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(Array(alibi.excusedDays.prefix(7).enumerated()), id: \.offset) { _, day in
                    Text(day, format: .dateTime.month(.abbreviated).day())
                        .font(AMORTypography.captionFont)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.orange.opacity(0.12), in: Capsule())
                }
                if alibi.excusedDays.count > 7 {
                    Text("+\(alibi.excusedDays.count - 7) more")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
