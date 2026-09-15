/**
 * 🧘 AMORTokenBreathEngine — The Measured Breath (v6.0.0)
 *
 * "Every session breathes tokens. The whole breath — in and out —
 * is the shape of a day's thinking. This engine does not judge the
 * size of the breath; it only refuses to let it go unmeasured."
 *
 * Foundation-only by law: no SwiftUI, no SwiftData, no @Model.
 * Reasons over AMORSessionSnapshot arrays — the same mirrors the
 * live-fire harness compiles — so every law here is harness-true
 * before it is ever app-true.
 *
 * Born of the Living Index (v5.9.0): model + token truth reached
 * SwiftData buried in prose notes. The Measured Breath promotes
 * it to structured fields and gives it an engine: totals, per-model
 * splits, breath-weight (in:out ratio), daily arcs, and the honest
 * boundary between measured and unmeasured sessions.
 */

import Foundation

// MARK: - Model Split

/// Token truth for one model over a window.
struct AMORModelBreath: Identifiable, Equatable {
    var id: String { model }
    let model: String
    let sessions: Int
    let inputTokens: Int
    let outputTokens: Int

    var totalTokens: Int { inputTokens + outputTokens }

    /// Breath weight — how much reading vs writing this model did.
    /// > 1 means context-heavy (long reads, short replies).
    var breathWeight: Double {
        guard outputTokens > 0 else { return 0 }
        return Double(inputTokens) / Double(outputTokens)
    }

    /// Average total tokens per session, rounded — the model's
    /// typical breath size.
    var averageSessionTokens: Int {
        guard sessions > 0 else { return 0 }
        return totalTokens / sessions
    }
}

/// One day in the breath arc.
struct AMORDayBreath: Identifiable, Equatable {
    var id: Date { day }
    let day: Date
    let sessions: Int
    let inputTokens: Int
    let outputTokens: Int
    var totalTokens: Int { inputTokens + outputTokens }
}

/// The whole measured breath over a window.
struct AMORBreathReport: Equatable {
    let windowDays: Int
    let measuredSessions: Int
    let unmeasuredSessions: Int
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let modelBreakdown: [AMORModelBreath]
    let dailyArc: [AMORDayBreath]

    var totalTokens: Int { totalInputTokens + totalOutputTokens }

    var totalTokensMillions: Double { Double(totalTokens) / 1_000_000 }

    /// Overall breath weight across all models.
    var breathWeight: Double {
        guard totalOutputTokens > 0 else { return 0 }
        return Double(totalInputTokens) / Double(totalOutputTokens)
    }

    /// The model carrying the most total tokens this window.
    var dominantModel: AMORModelBreath? {
        modelBreakdown.max { $0.totalTokens < $1.totalTokens }
    }

    /// Share (0...1) of the dominant model's tokens.
    var dominantModelShare: Double {
        guard let dom = dominantModel, totalTokens > 0 else { return 0 }
        return Double(dom.totalTokens) / Double(totalTokens)
    }

    /// Busiest day in the arc by total tokens.
    var peakDay: AMORDayBreath? {
        dailyArc.max { $0.totalTokens < $1.totalTokens }
    }

    var isEmpty: Bool { measuredSessions == 0 }
}

// MARK: - Engine

enum AMORTokenBreathEngine {

    /// Compute the measured breath over the trailing `days` window.
    /// Unmeasured sessions (empty model / zero tokens — manual logs,
    /// legacy jsonl imports) are counted honestly, never guessed.
    ///
    /// WINDOW ≡ ARC LAW (caught by leg 14's first fire): the filter
    /// cutoff and the daily-arc buckets must span the exact same
    /// calendar days, or tokens fall in the gap between them and
    /// conservation breaks. Cutoff at -(days-1) from start-of-today
    /// makes the window exactly the arc's `days` buckets.
    static func compute(sessions: [AMORSessionSnapshot], days: Int = 14) -> AMORBreathReport {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: Date())) ?? Date()
        let window = sessions.filter { $0.date >= cutoff }

        let measured = window.filter { !$0.modelName.isEmpty && ($0.inputTokens > 0 || $0.outputTokens > 0) }
        let unmeasured = window.count - measured.count

        // Per-model splits — measured sessions only, by law.
        var byModel: [String: (inTok: Int, outTok: Int, count: Int)] = [:]
        for s in measured {
            var slot = byModel[s.modelName] ?? (0, 0, 0)
            slot.inTok += s.inputTokens
            slot.outTok += s.outputTokens
            slot.count += 1
            byModel[s.modelName] = slot
        }
        let breakdown = byModel
            .map { AMORModelBreath(model: $0.key, sessions: $0.value.count, inputTokens: $0.value.inTok, outputTokens: $0.value.outTok) }
            .sorted { $0.totalTokens > $1.totalTokens }

        // Daily arc — every day in the window, zero-filled so the
        // arc never lies by omission.
        var arc: [AMORDayBreath] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: Date())) else { continue }
            let daySessions = measured.filter { cal.isDate($0.date, inSameDayAs: day) }
            arc.append(AMORDayBreath(
                day: day,
                sessions: daySessions.count,
                inputTokens: daySessions.reduce(0) { $0 + $1.inputTokens },
                outputTokens: daySessions.reduce(0) { $0 + $1.outputTokens }
            ))
        }

        return AMORBreathReport(
            windowDays: days,
            measuredSessions: measured.count,
            unmeasuredSessions: unmeasured,
            totalInputTokens: measured.reduce(0) { $0 + $1.inputTokens },
            totalOutputTokens: measured.reduce(0) { $0 + $1.outputTokens },
            modelBreakdown: breakdown,
            dailyArc: arc
        )
    }

    /// Compact human form: 1.2M, 104.1M, 980k …
    static func formatTokens(_ tokens: Int) -> String {
        let t = Double(tokens)
        if t >= 1_000_000 { return String(format: "%.1fM", t / 1_000_000) }
        if t >= 1_000 { return String(format: "%.0fk", t / 1_000) }
        return "\(tokens)"
    }

    /// Compact human form for token ratios: "77:1".
    static func formatWeight(_ weight: Double) -> String {
        guard weight > 0 else { return "—" }
        if weight >= 10 { return String(format: "%.0f:1", weight) }
        return String(format: "%.1f:1", weight)
    }

    /// Short display name for a model id — keeps the long
    /// provider-prefixed ids from wrecking layouts. The full id
    /// stays in the data; this is display mercy only.
    static func shortModelName(_ model: String) -> String {
        let candidate = model.split(separator: "/").last.map(String.init) ?? model
        return String(candidate.prefix(24))
    }
}
