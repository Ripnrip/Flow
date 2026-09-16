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
    let report: AMORBreathReport

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
