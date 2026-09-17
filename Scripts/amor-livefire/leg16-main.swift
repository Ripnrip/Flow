// leg16-main.swift — THE DAILY LEDGER, end-to-end (v6.2.0)
//
// Compiles the SHIPPED AMORSessionIndex + AMORMirror +
// AMORTokenBreathEngine + AMORCostLedger straight from Flow/Flow/
// so harness-vs-shipped drift is impossible by construction.
// Re-pulses the vein so the leg stands alone, then fires the
// Daily Ledger's laws against the REAL 14-day window:
//
//   1. Vein + index parse (the standing precondition).
//   2. ARC ≡ LEDGER LAW: Σ per-day cents == the aggregated
//      Honest Ledger total, EXACTLY — two different code paths
//      (apportioned vs aggregated) must agree to the cent.
//   3. ZERO-TOKEN LAW: no day earns cents without priced tokens;
//      a day breathed only by an unpriced model stays at zero.
//   4. WINDOW LAW: the arc spans exactly `days` distinct,
//      chronological, zero-filled buckets ending today.
//   5. DETERMINISM: the tie-break (largest remainder, then
//      earlier day) is verified on a synthetic fractional split;
//      two invocations over the same history agree exactly.
//   6. UNPRICED-HONESTY: an unpriced model contributes zero cents
//      to every day, no matter how loud it breathes.
//   7. PEAK LAW: the peak day is priced, and no day exceeds the
//      ledger total.

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

print("DAILY LEDGER LIVE-FIRE (leg 16)")

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

func snap(_ row: AMORIndexedSession) -> AMORSessionSnapshot {
    AMORSessionSnapshot(
        id: UUID(), date: row.startDate, title: row.title, notes: "",
        durationMinutes: row.durationMinutes, toolsUsed: "hermes",
        skillsLearned: "", mood: "focused", completedTasks: 0,
        modelName: row.model, inputTokens: row.inputTokens,
        outputTokens: row.outputTokens, timestamp: row.startDate
    )
}
let realSnapshots: [AMORSessionSnapshot] = indexSessions.map(snap)

// ── 2. ARC ≡ LEDGER over real history ──────────────────────────
let breath = AMORTokenBreathEngine.compute(sessions: realSnapshots, days: 14)
let ledger = AMORCostLedger.estimate(from: breath)
let arc = AMORCostLedger.dailyArc(sessions: realSnapshots, days: 14)
let arcSum = arc.days.reduce(Int64(0)) { $0 + $1.estimatedCents }
check("arc computes over real history", arcSum > 0,
      "\(AMORCostLedger.formatCents(arcSum)) across \(arc.days.count) days")
check("ARC ≡ LEDGER exactly", arcSum == ledger.estimatedTotalCents,
      "arc=\(arcSum) ledger=\(ledger.estimatedTotalCents)")
check("arc carries its own conserved total",
      arc.estimatedTotalCents == ledger.estimatedTotalCents)

// ── 3. ZERO-TOKEN LAW ──────────────────────────────────────────
let phantomDays = arc.days.filter { $0.estimatedCents > 0 && !$0.hasPricedTokens }
check("no day earns cents without priced tokens", phantomDays.isEmpty,
      phantomDays.isEmpty ? "all \(arc.days.filter { $0.estimatedCents > 0 }.count) priced days flagged" : "\(phantomDays.count) phantom days")

// ── 4. WINDOW LAW ──────────────────────────────────────────────
let cal = Calendar.current
check("arc spans exactly the window", arc.days.count == 14, "\(arc.days.count) buckets")
check("arc ends today", cal.isDateInToday(arc.days.last?.day ?? Date.distantPast))
let chronologic = zip(arc.days, arc.days.dropFirst()).allSatisfy { $0.0.day < $0.1.day }
check("arc is chronological and distinct", chronologic)

// ── 5. DETERMINISM (synthetic fractional split + tie-break) ────
// glm-5 @ $1.00/M in, two days of 105,000 input tokens each:
// each day = 10.5¢ EXACTLY (binary-representable — a bitwise tie,
// not a float fantasy), window = 21¢, floors sum 20, r = 1.
// The tie must break to the EARLIER day: yesterday 11¢, today 10¢.
func synthetic(_ modelName: String, _ inTok: Int, _ outTok: Int, _ date: Date) -> AMORSessionSnapshot {
    AMORSessionSnapshot(
        id: UUID(), date: date, title: "synthetic", notes: "",
        durationMinutes: 0, toolsUsed: "", skillsLearned: "", mood: "",
        completedTasks: 0, modelName: modelName,
        inputTokens: inTok, outputTokens: outTok, timestamp: date
    )
}
let today = cal.startOfDay(for: Date())
let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
let fracSessions = [
    synthetic("glm-5", 105_000, 0, yesterday),
    synthetic("glm-5", 105_000, 0, today)
]
let fracArc = AMORCostLedger.dailyArc(sessions: fracSessions, days: 14)
let todayCost = fracArc.days.last!
let yesterdayCost = fracArc.days[fracArc.days.count - 2]
check("exact tie conserves to the cent",
      fracArc.estimatedTotalCents == 21,
      "total=\(fracArc.estimatedTotalCents)¢ (expect 21)")
check("tie-break favors the earlier day",
      yesterdayCost.estimatedCents == 11 && todayCost.estimatedCents == 10,
      "yesterday=\(yesterdayCost.estimatedCents)¢ today=\(todayCost.estimatedCents)¢ (expect 11/10)")

let arcAgain = AMORCostLedger.dailyArc(sessions: realSnapshots, days: 14)
check("two invocations agree exactly", arcAgain == arc)

// ── 6. UNPRICED-HONESTY ────────────────────────────────────────
// The unpriced model breathes ONLY yesterday, loudly; glm-5 is
// silent. Yesterday must stay at zero cents.
let unpricedOnly = [
    synthetic("totally-unknown-foss-model", 9_000_000, 9_000_000, yesterday)
]
let unpricedArc = AMORCostLedger.dailyArc(sessions: unpricedOnly, days: 14)
check("unpriced-only day earns zero cents",
      unpricedArc.estimatedTotalCents == 0
      && unpricedArc.days.allSatisfy { $0.estimatedCents == 0 },
      "loud unpriced breath, silent ledger — as it should be")

// ── 7. PEAK LAW ────────────────────────────────────────────────
if let peak = arc.peakDay {
    check("peak day is priced", peak.hasPricedTokens && peak.estimatedCents > 0,
          "peak \(AMORCostLedger.formatCents(peak.estimatedCents)) on \(peak.day.formatted(.dateTime.month(.abbreviated).day()))")
    check("no day exceeds the ledger total",
          arc.days.allSatisfy { $0.estimatedCents <= arc.estimatedTotalCents })
} else {
    check("peak day exists", false, "real history has priced days")
}

// ── Verdict ─────────────────────────────────────────────────────
print("")
if failures == 0 {
    print("DAILY LEDGER LIVE-FIRE: PASS — \(passes) checks green, the ledger breathes by the day")
    exit(0)
} else {
    print("DAILY LEDGER LIVE-FIRE: FAIL — \(failures) failing, \(passes) passed")
    exit(1)
}
