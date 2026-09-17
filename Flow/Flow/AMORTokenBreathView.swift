/**
 * 🧘 AMORTokenBreathView — The Measured Breath, made visible (v6.0.0)
 *
 * "The breath was always there — a hundred million tokens of thinking
 * a fortnight. Unmeasured is not the same as unmeasurable. Here is
 * the breath, counted."
 *
 * Renders the AMORBreathReport from AMORTokenBreathEngine: total
 * tokens, breath weight, the model constellation, and the 14-day
 * arc. Unmeasured sessions are named honestly, never guessed.
 */

import SwiftUI

struct AMORTokenBreathView: View {
    /// v6.2.0: takes session snapshots directly — the Daily Ledger
    /// needs per-model-per-day cells, not the aggregated report.
    /// The breath, the ledger, and the arc are computed here from
    /// ONE source of truth.
    let sessions: [AMORSessionSnapshot]
    var days: Int = 14

    private var report: AMORBreathReport {
        AMORTokenBreathEngine.compute(sessions: sessions, days: days)
    }

    private var maxDayTokens: Int {
        report.dailyArc.map { $0.totalTokens }.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text("The Measured Breath")
                    .font(AMORTypography.titleFont)
                    .foregroundStyle(AMORColorPalette.deepIndigo)
                Spacer()
                Text("\(report.windowDays)-day window")
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)
            }

            if report.isEmpty {
                Text("No measured sessions yet — connect the Living Index and the breath will be counted.")
                    .font(AMORTypography.captionFont)
                    .foregroundStyle(.secondary)
            } else {
                // Hero: the whole breath
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text(AMORTokenBreathEngine.formatTokens(report.totalTokens))
                        .font(AMORTypography.headingFont)
                        .foregroundStyle(AMORColorPalette.twilightPurple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("tokens breathed")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                        Text("\(AMORTokenBreathEngine.formatTokens(report.totalInputTokens)) in · \(AMORTokenBreathEngine.formatTokens(report.totalOutputTokens)) out")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(AMORTokenBreathEngine.formatWeight(report.breathWeight))
                            .font(AMORTypography.titleFont)
                            .foregroundStyle(AMORStringPalette.modelColor(report.dominantModel?.model ?? ""))
                        Text("breath weight")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                    }
                }

                // Daily arc — 14 bars, zero-filled, never lying by omission.
                VStack(alignment: .leading, spacing: 6) {
                    Text("Daily Arc")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(report.dailyArc) { day in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(day.totalTokens > 0
                                      ? AMORColorPalette.twilightPurple.opacity(0.55 + 0.45 * Double(day.totalTokens) / Double(maxDayTokens))
                                      : AMORColorPalette.warmSand)
                                .frame(height: barHeight(day.totalTokens))
                                .accessibilityLabel("\(day.sessions) sessions, \(AMORTokenBreathEngine.formatTokens(day.totalTokens)) tokens")
                        }
                    }
                    HStack {
                        Text("14 days ago")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("today")
                            .font(AMORTypography.captionFont)
                            .foregroundStyle(.secondary)
                    }
                }

                // Model constellation
                VStack(alignment: .leading, spacing: 8) {
                    Text("Model Constellation")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                    ForEach(report.modelBreakdown) { mb in
                        HStack {
                            Circle()
                                .fill(AMORStringPalette.modelColor(mb.model))
                                .frame(width: 8, height: 8)
                            Text(AMORTokenBreathEngine.shortModelName(mb.model))
                                .font(AMORTypography.captionFont)
                                .lineLimit(1)
                            Spacer()
                            Text("\(mb.sessions) sessions")
                                .font(AMORTypography.captionFont)
                                .foregroundStyle(.secondary)
                            Text(AMORTokenBreathEngine.formatTokens(mb.totalTokens))
                                .font(AMORTypography.monospaceFont)
                                .foregroundStyle(AMORColorPalette.deepIndigo)
                                .frame(width: 56, alignment: .trailing)
                        }
                    }
                }

                // v6.1.0 — The Honest Ledger: estimated dollars over
                // the same conserved splits, unpriced models named.
                let costReport = AMORCostLedger.estimate(from: report)

                VStack(alignment: .leading, spacing: 8) {
                    Text("The Honest Ledger")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        Text(AMORCostLedger.formatCents(costReport.estimatedTotalCents))
                            .font(AMORTypography.headingFont)
                            .foregroundStyle(AMORColorPalette.sageGreen)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("estimated spend · \(costReport.windowDays)-day window")
                                .font(AMORTypography.captionFont)
                                .foregroundStyle(.secondary)
                            Text("\(AMORCostLedger.formatCoverage(costReport.coverageShare)) of tokens priced · list prices, cache-inclusive input")
                                .font(AMORTypography.captionFont)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    // v6.2.0 — The Daily Ledger: the same conserved
                    // cents, apportioned per day (ARC ≡ LEDGER).
                    let arc = AMORCostLedger.dailyArc(sessions: sessions, days: days)
                    let arcPeak = arc.peakDay?.estimatedCents ?? 0
                    if !arc.days.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Daily Ledger")
                                    .font(AMORTypography.captionFont)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if let peak = arc.peakDay, peak.estimatedCents > 0 {
                                    Text("peak \(AMORCostLedger.formatCents(peak.estimatedCents)) on \(peak.day.formatted(.dateTime.month(.abbreviated).day()))")
                                        .font(AMORTypography.captionFont)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            HStack(alignment: .bottom, spacing: 4) {
                                ForEach(arc.days) { d in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(d.estimatedCents > 0
                                              ? AMORColorPalette.sageGreen.opacity(0.5 + 0.5 * Double(d.estimatedCents) / Double(max(1, arc.peakDay?.estimatedCents ?? 1)))
                                              : (d.sessions > 0
                                                 ? AMORColorPalette.sageGreen.opacity(0.25)
                                                 : AMORColorPalette.warmSand))
                                        .frame(height: costBarHeight(d.estimatedCents, peak: arcPeak))
                                        .accessibilityLabel("\(d.sessions) sessions, \(AMORCostLedger.formatCents(d.estimatedCents))")
                                }
                            }
                            HStack {
                                Text("Σ \(AMORCostLedger.formatCents(arc.days.reduce(Int64(0)) { $0 + $1.estimatedCents })) ≡ ledger")
                                    .font(AMORTypography.captionFont)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                Text("today")
                                    .font(AMORTypography.captionFont)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    ForEach(costReport.modelCosts) { mc in
                        HStack {
                            Circle()
                                .fill(AMORStringPalette.modelColor(mc.model))
                                .frame(width: 8, height: 8)
                            Text(AMORTokenBreathEngine.shortModelName(mc.model))
                                .font(AMORTypography.captionFont)
                                .lineLimit(1)
                            Spacer()
                            if mc.priced {
                                Text(AMORCostLedger.formatCents(mc.costCents ?? 0))
                                    .font(AMORTypography.monospaceFont)
                                    .foregroundStyle(AMORColorPalette.deepIndigo)
                                    .frame(width: 64, alignment: .trailing)
                            } else {
                                Text("unpriced")
                                    .font(AMORTypography.captionFont)
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 64, alignment: .trailing)
                            }
                        }
                    }

                    Text("Estimates from provider list prices — routing, caching, and discounts will differ from the bill.")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.tertiary)
                        .italic()
                }

                // Honest boundary
                if report.unmeasuredSessions > 0 {
                    Text("\(report.unmeasuredSessions) session\(report.unmeasuredSessions > 1 ? "s" : "") unmeasured — manual logs and legacy imports carry no token truth. Honest zeros, no guesses.")
                        .font(AMORTypography.captionFont)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
    }

    private func barHeight(_ tokens: Int) -> CGFloat {
        guard maxDayTokens > 0 else { return 3 }
        return max(3, CGFloat(tokens) / CGFloat(maxDayTokens) * 42)
    }

    /// v6.2.0: Daily Ledger bar height — same visual grammar as the
    /// token arc, scaled to the peak cost day of this render's arc.
    private func costBarHeight(_ cents: Int64, peak: Int64) -> CGFloat {
        let p = max(1, peak)
        return max(3, CGFloat(cents) / CGFloat(p) * 42)
    }
}

/// v6.0.0: stable display colors per model id, chosen from the
/// AMOR palette — the constellation stays legible across weeks.
enum AMORStringPalette {
    private static let hues: [Color] = [
        AMORColorPalette.twilightPurple,
        AMORColorPalette.dawnOrange,
        AMORColorPalette.sageGreen,
        AMORColorPalette.mutedGold,
        AMORColorPalette.deepIndigo,
        AMORColorPalette.softClay
    ]

    static func modelColor(_ model: String) -> Color {
        guard !model.isEmpty else { return AMORColorPalette.charcoal }
        var hasher = Hasher()
        hasher.combine(model)
        return hues[abs(hasher.finalize()) % hues.count]
    }
}
