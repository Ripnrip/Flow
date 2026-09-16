// leg15-main.swift — THE HONEST LEDGER, end-to-end (v6.1.0)
//
// Compiles the SHIPPED AMORSessionIndex + AMORMirror +
// AMORTokenBreathEngine + AMORCostLedger straight from Flow/Flow/
// so harness-vs-shipped drift is impossible by construction.
// Re-pulses the vein so the leg stands alone, then fires the
// ledger's three laws against the REAL 14-day window:
//
//   1. Vein + index parse (the standing precondition).
//   2. Ledger computes over real history: total > $0.
//   3. CENT-CONSERVATION: Σ per-model cents == total, exactly.
//   4. LONGEST-FRAGMENT LAW: "glm-5.2" must NOT match "glm-5";
//      provider-prefixed ids resolve to the same price as bare ids;
//      an unknown model is nil (never guessed).
//   5. UNPRICED-HONESTY: unpriced models contribute zero cents,
//      are named, and never appear as $0.00 priced rows.
//   6. REAL CONSTELLATION PRICED: every model in today's real
//      breakdown carries a price (verified live).
//   7. Independent recomputation: the leg re-derives each model's
//      cents from raw tokens × book prices and asserts exact
//      agreement with the engine (Int64, whole cents).
//   8. Formatter law: cents → "$12.34" / "$0.98" / "$0.00" / "−$0.05";
//      coverage renders whole percents.

import Foundation

var failures = 0
var passes = 0

func check(_ name: String, _ ok: Bool, _ detail: String = "") {
    if ok {
        passes += 1
        print("  ✅ \(name): PASS\(detail.isEmpty ? "" : " — \(detail)")")
    } else {
        failures += 1
        print("  ❌ \(name): FAIL\(detail.isEmpty ? "" : " — \(detail)")")
    }
}

print("HONEST LEDGER LIVE-FIRE (leg 15)")

// ── 1. Vein + index ────────────────────────────────────────────
let base = "http://127.0.0.1:17777"
let sync = await AMORRemoteSyncEngine.sync(base: base)
check("vein reachable", sync.ok, sync.error ?? "")

let hermesHome = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".hermes")
let indexURL = hermesHome.appendingPathComponent(AMORSessionIndex.indexRelPath)
guard let indexSessions = AMORSessionIndex.readIndex(at: indexURL), !indexSessions.isEmpty else {
    print("  ❌ index unreadable at \(indexURL.path) — leg 13 owns that failure")
    exit(1)
}
check("index parses", !indexSessions.isEmpty, "\(indexSessions.count) sessions")

// ── 2. Ledger computes over real history ───────────────────────
let snapshots: [AMORSessionSnapshot] = indexSessions.map { row in
    AMORSessionSnapshot(
        id: UUID(), date: row.startDate, title: row.title, notes: "",
        durationMinutes: row.durationMinutes, toolsUsed: "hermes",
        skillsLearned: "", mood: "focused", completedTasks: 0,
        modelName: row.model, inputTokens: row.inputTokens,
        outputTokens: row.outputTokens, timestamp: row.startDate
    )
}
let breath = AMORTokenBreathEngine.compute(sessions: snapshots, days: 14)
let ledger = AMORCostLedger.estimate(from: breath)
check("ledger computes", !ledger.isEmpty && ledger.estimatedTotalCents > 0,
      "\(AMORCostLedger.formatCents(ledger.estimatedTotalCents)) over \(breath.measuredSessions) sessions")

// ── 3. Cent-conservation ───────────────────────────────────────
let sumCents = ledger.modelCosts.reduce(Int64(0)) { $0 + ($1.costCents ?? 0) }
check("cents conserve exactly", sumCents == ledger.estimatedTotalCents,
      "rows=\(sumCents) total=\(ledger.estimatedTotalCents)")

// ── 4. Longest-fragment law ────────────────────────────────────
let glm52 = AMORCostLedger.price(for: "glm-5.2")
check("glm-5.2 does not cross-match glm-5",
      glm52?.fragment == "glm-5.2" && glm52?.inputPerMillion == 1.40,
      "matched \(glm52?.fragment ?? "nil") @ $\(glm52?.inputPerMillion ?? 0)/M in")
let glm5 = AMORCostLedger.price(for: "glm-5")
check("glm-5 exact id matches its own price",
      glm5?.fragment == "glm-5" && glm5?.inputPerMillion == 1.00,
      "matched \(glm5?.fragment ?? "nil") @ $\(glm5?.inputPerMillion ?? 0)/M in")
check("provider prefix resolves same as bare",
      AMORCostLedger.price(for: "z-ai/glm-5.2-0414")?.fragment == "glm-5.2")
check("case-insensitive match", AMORCostLedger.price(for: "GLM-5.2")?.fragment == "glm-5.2")
check("unknown model is nil", AMORCostLedger.price(for: "mystery-model-x") == nil)
check("flash tier outranks base", AMORCostLedger.price(for: "glm-5.3-flash")?.fragment == "glm-5.3-flash")

// ── 5. Unpriced honesty ────────────────────────────────────────
// Synthesize a report with one unpriced model mixed in.
var mixed = breath.modelBreakdown
mixed.append(AMORModelBreath(
    model: "totally-unknown-foss-model", sessions: 3,
    inputTokens: 1_000_000, outputTokens: 500_000
))
let mixedReport = AMORBreathReport(
    windowDays: breath.windowDays,
    measuredSessions: breath.measuredSessions + 3,
    unmeasuredSessions: breath.unmeasuredSessions,
    totalInputTokens: breath.totalInputTokens + 1_000_000,
    totalOutputTokens: breath.totalOutputTokens + 500_000,
    modelBreakdown: mixed,
    dailyArc: breath.dailyArc
)
let mixedLedger = AMORCostLedger.estimate(from: mixedReport)
let unpricedRow = mixedLedger.unpricedModels.first { $0.model == "totally-unknown-foss-model" }
check("unpriced model named with nil cents",
      unpricedRow != nil && unpricedRow?.costCents == nil,
      "unpriced count = \(mixedLedger.unpricedModels.count)")
check("unpriced adds zero cents",
      mixedLedger.estimatedTotalCents == ledger.estimatedTotalCents,
      "mixed=\(mixedLedger.estimatedTotalCents) pure=\(ledger.estimatedTotalCents)")
check("coverage counts honestly",
      mixedLedger.pricedTokens + mixedLedger.unpricedTokens
          == breath.totalTokens + 1_500_000,
      "\(AMORCostLedger.formatCoverage(mixedLedger.coverageShare)) covered")

// ── 6. Real constellation priced ────────────────────────────────
let unpricedReal = breath.modelBreakdown.filter { AMORCostLedger.price(for: $0.model) == nil }
check("every real constellation model priced",
      unpricedReal.isEmpty,
      unpricedReal.isEmpty
          ? "\(breath.modelBreakdown.count) models all priced"
          : "unpriced: \(unpricedReal.map { $0.model }.joined(separator: ", "))")

// ── 7. Independent recomputation (exact Int64 agreement) ────────
var independentCents: Int64 = 0
var exactMatch = true
for mb in breath.modelBreakdown {
    guard let p = AMORCostLedger.price(for: mb.model) else { continue }
    let dollars = (Double(mb.inputTokens) * p.inputPerMillion
                   + Double(mb.outputTokens) * p.outputPerMillion) / 1_000_000.0
    let cents = Int64((dollars * 100.0) + 0.5)
    independentCents += cents
    if let row = ledger.modelCosts.first(where: { $0.model == mb.model }),
       row.costCents != cents {
        exactMatch = false
    }
}
check("independent recompute agrees exactly",
      exactMatch && independentCents == ledger.estimatedTotalCents,
      "independent=\(independentCents) engine=\(ledger.estimatedTotalCents)")

// ── 8. Formatter law ────────────────────────────────────────────
check("formatCents dollars", AMORCostLedger.formatCents(1234) == "$12.34",
      AMORCostLedger.formatCents(1234))
check("formatCents sub-dollar", AMORCostLedger.formatCents(98) == "$0.98",
      AMORCostLedger.formatCents(98))
check("formatCents zero", AMORCostLedger.formatCents(0) == "$0.00",
      AMORCostLedger.formatCents(0))
check("formatCents negative", AMORCostLedger.formatCents(-5) == "−$0.05",
      AMORCostLedger.formatCents(-5))
check("formatCoverage whole percent", AMORCostLedger.formatCoverage(0.9649) == "96%",
      AMORCostLedger.formatCoverage(0.9649))

// ── Verdict ─────────────────────────────────────────────────────
print("")
if failures == 0 {
    print("HONEST LEDGER LIVE-FIRE: PASS — \(passes) checks green, the breath is priced")
    exit(0)
} else {
    print("HONEST LEDGER LIVE-FIRE: FAIL — \(failures) failing, \(passes) passed")
    exit(1)
}
