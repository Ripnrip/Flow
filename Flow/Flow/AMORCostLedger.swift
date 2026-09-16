/**
 * 🧘 AMORCostLedger — The Honest Ledger (v6.1.0)
 *
 * "Tokens are the breath; the ledger asks what the breath cost.
 * A model with no price is not a model with a zero price — it is
 * a model counted in tokens and named honestly in the margin."
 *
 * Foundation-only by law: no SwiftUI, no SwiftData, no @Model.
 * Estimates dollars from the conserved per-model splits of an
 * AMORBreathReport using a curated price book of provider list
 * prices. Three laws govern it:
 *
 * LONGEST-FRAGMENT LAW — model ids are messy ("z-ai/glm-5.2-0414",
 * "nvidia/nemotron-3-ultra-550b-a55b", "kimi-k2-0711-preview").
 * Matching is case-insensitive containment, and the LONGEST matching
 * fragment wins — because "glm-5" is contained in "glm-5.2", and a
 * naive match would silently misprice the entire constellation.
 *
 * CENT-CONSERVATION LAW — the total IS the sum of the per-model
 * cents. It is never recomputed from the raw tokens, so the ledger
 * cannot disagree with itself by more than nothing.
 *
 * UNPRICED-HONESTY LAW — models absent from the book are counted in
 * tokens and sessions, contribute exactly zero dollars, and surface
 * in unpricedModels. Never guessed, never zero-filled silently.
 *
 * Prices are provider LIST prices (the book cites each source);
 * actual bills vary with routing, caching, and discounts. The
 * ledger labels itself an estimate everywhere it renders.
 */

import Foundation

// MARK: - Price Book Entry

/// One row of the price book: USD per 1M input / output tokens.
/// `fragment` is the substring a model id must contain (case-
/// insensitive) to match this price.
struct AMORModelPrice: Equatable {
    let fragment: String
    let inputPerMillion: Double
    let outputPerMillion: Double
    /// Provenance — where this list price was verified.
    let source: String
}

// MARK: - Per-Model Cost

/// One model's estimated cost over the window. `costCents` is nil
/// when the model is not in the price book — the honest boundary.
struct AMORModelCost: Identifiable, Equatable {
    var id: String { model }
    let model: String
    /// The price-book fragment that matched ("" when unpriced).
    let matchedFragment: String
    let sessions: Int
    let inputTokens: Int
    let outputTokens: Int
    /// Estimated cost in whole US cents; nil = unpriced.
    let costCents: Int64?

    var priced: Bool { costCents != nil }
    var totalTokens: Int { inputTokens + outputTokens }
}

// MARK: - Report

/// The whole honest ledger over a breath window.
struct AMORCostReport: Equatable {
    let windowDays: Int
    /// Priced models first (cost desc), then unpriced (tokens desc).
    let modelCosts: [AMORModelCost]
    /// Sum of per-model cents — cent-conserved by construction.
    let estimatedTotalCents: Int64
    let pricedSessions: Int
    let unpricedSessions: Int
    let pricedTokens: Int
    let unpricedTokens: Int

    /// Share (0...1) of tokens that carry a price.
    var coverageShare: Double {
        let all = pricedTokens + unpricedTokens
        guard all > 0 else { return 0 }
        return Double(pricedTokens) / Double(all)
    }

    var unpricedModels: [AMORModelCost] {
        modelCosts.filter { !$0.priced }
    }

    var isEmpty: Bool { modelCosts.isEmpty }

    /// Average estimated cost per measured session, in cents.
    /// Zero when nothing is priced — never a guess.
    var averageSessionCents: Int64 {
        let sessions = pricedSessions + unpricedSessions
        guard sessions > 0, estimatedTotalCents > 0 else { return 0 }
        return estimatedTotalCents / Int64(sessions)
    }
}

// MARK: - Engine

enum AMORCostLedger {

    /// The price book — provider list prices, USD per 1M tokens.
    /// Sources verified 2026-09-16. Cached-input tiers exist for
    /// most of these; the vein's token counts are cache-inclusive
    /// on input, so list input pricing is the conservative estimate.
    static let priceBook: [AMORModelPrice] = [
        // Z.AI official pricing (docs.z.ai/guides/overview/pricing)
        AMORModelPrice(fragment: "glm-5.3-flash", inputPerMillion: 0.15, outputPerMillion: 0.50, source: "Z.AI list"),
        AMORModelPrice(fragment: "glm-5.3", inputPerMillion: 1.40, outputPerMillion: 4.40, source: "Z.AI list"),
        AMORModelPrice(fragment: "glm-5.2", inputPerMillion: 1.40, outputPerMillion: 4.40, source: "Z.AI list"),
        AMORModelPrice(fragment: "glm-5.1", inputPerMillion: 1.40, outputPerMillion: 4.40, source: "Z.AI list"),
        AMORModelPrice(fragment: "glm-5", inputPerMillion: 1.00, outputPerMillion: 3.20, source: "Z.AI list"),
        // OpenAI list pricing
        AMORModelPrice(fragment: "o3-mini", inputPerMillion: 1.10, outputPerMillion: 4.40, source: "OpenAI list"),
        // Moonshot list pricing (original K2)
        AMORModelPrice(fragment: "kimi-k2", inputPerMillion: 0.60, outputPerMillion: 2.50, source: "Moonshot list"),
        // Nemotron 3 Ultra — DeepInfra primary via OpenRouter
        AMORModelPrice(fragment: "nemotron-3-ultra", inputPerMillion: 0.50, outputPerMillion: 2.20, source: "DeepInfra list"),
    ]

    /// LONGEST-FRAGMENT LAW: case-insensitive containment, longest
    /// match wins. Returns nil when no fragment matches.
    static func price(for model: String) -> AMORModelPrice? {
        let lowered = model.lowercased()
        return priceBook
            .filter { lowered.contains($0.fragment.lowercased()) }
            .max { $0.fragment.count < $1.fragment.count }
    }

    /// Estimate the honest ledger from a conserved breath report.
    /// Each model's cost is rounded to whole cents once; the total
    /// is the sum of those cents (CENT-CONSERVATION LAW).
    static func estimate(from report: AMORBreathReport) -> AMORCostReport {
        var rows: [AMORModelCost] = []
        var totalCents: Int64 = 0
        var pricedSessions = 0, unpricedSessions = 0
        var pricedTokens = 0, unpricedTokens = 0

        for mb in report.modelBreakdown {
            if let p = price(for: mb.model) {
                let dollars = (Double(mb.inputTokens) * p.inputPerMillion
                               + Double(mb.outputTokens) * p.outputPerMillion) / 1_000_000.0
                let cents = Int64((dollars * 100.0) + 0.5)
                totalCents += cents
                pricedSessions += mb.sessions
                pricedTokens += mb.totalTokens
                rows.append(AMORModelCost(
                    model: mb.model,
                    matchedFragment: p.fragment,
                    sessions: mb.sessions,
                    inputTokens: mb.inputTokens,
                    outputTokens: mb.outputTokens,
                    costCents: cents
                ))
            } else {
                unpricedSessions += mb.sessions
                unpricedTokens += mb.totalTokens
                rows.append(AMORModelCost(
                    model: mb.model,
                    matchedFragment: "",
                    sessions: mb.sessions,
                    inputTokens: mb.inputTokens,
                    outputTokens: mb.outputTokens,
                    costCents: nil
                ))
            }
        }

        // Priced rows by cost desc; unpriced trail by tokens desc.
        let priced = rows.filter { $0.priced }.sorted {
            ($0.costCents ?? 0) > ($1.costCents ?? 0)
        }
        let unpriced = rows.filter { !$0.priced }.sorted {
            $0.totalTokens > $1.totalTokens
        }

        return AMORCostReport(
            windowDays: report.windowDays,
            modelCosts: priced + unpriced,
            estimatedTotalCents: totalCents,
            pricedSessions: pricedSessions,
            unpricedSessions: unpricedSessions,
            pricedTokens: pricedTokens,
            unpricedTokens: unpricedTokens
        )
    }

    /// Whole cents → "$12.34" / "$0.98" / "$0.00".
    /// Manual string building keeps it locale-stable and
    /// deterministic for the live-fire leg.
    static func formatCents(_ cents: Int64) -> String {
        let negative = cents < 0
        let magnitude = negative ? -cents : cents
        let dollars = magnitude / 100
        let remainder = magnitude % 100
        let string = "$\(dollars).\(String(format: "%02d", Int(remainder)))"
        return negative ? "−\(string)" : string
    }

    /// Coverage share → "100%" / "96%" (never claims precision it
    /// does not have).
    static func formatCoverage(_ share: Double) -> String {
        "\(Int((share * 100).rounded()))%"
    }
}
