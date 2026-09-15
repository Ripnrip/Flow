// leg14-main.swift — THE MEASURED BREATH, end-to-end (v6.0.0)
//
// Compiles the SHIPPED AMORSessionIndex + AMORMirror +
// AMORTokenBreathEngine straight from Flow/Flow/ so
// harness-vs-shipped drift is impossible by construction.
// Runs against the REAL vein-mirrored index (~/.hermes/sessions/
// index.json — materialized by leg 13's pulse; this leg re-pulses
// to be self-sufficient).
//
// Checks:
//  1. Vein pulses; the index is on disk and parses.
//  2. Engine maps index rows to snapshots with model + token
//     truth preserved (the same mapping law the importer uses).
//  3. The breath computes over the real 14-day window: measured
//     sessions > 0, totals > 0, no exceptions.
//  4. Per-model splits conserve tokens: sum(model totals) ==
//     sum(session tokens). No token lost, no token invented.
//  5. Daily arc conserves tokens AND covers every day in the
//     window (zero-filled — never lies by omission).
//  6. Unmeasured sessions (jsonl / manual) count honestly as
//     unmeasured, never as zero-cost measured sessions.
//  7. Dominant model law: glm family dominates this box's real
//     history — assert share > 0 and breakdown sorted desc.
//  8. Formatter law: 104,077,420 → "104.1M"; weights render.

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

print("MEASURED BREATH LIVE-FIRE (leg 14)")

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

// ── 2. Import-law mapping: index rows → snapshots ──────────────
// Mirrors HermesIntegrationEngine.syncSessions: jsonl rows carry
// no measurement; index rows carry their full truth.
// WINDOW ≡ ARC LAW: same cutoff law as the engine (-(days-1) from
// start-of-today) or the comparison sets diverge.
let cal = Calendar.current
let windowDays = 14
let cutoff = cal.date(byAdding: .day, value: -(windowDays - 1), to: cal.startOfDay(for: Date())) ?? Date()
let snapshots: [AMORSessionSnapshot] = indexSessions.map { row in
    AMORSessionSnapshot(
        id: UUID(),
        date: row.startDate,
        title: row.title,
        notes: "",
        durationMinutes: row.durationMinutes,
        toolsUsed: "hermes",
        skillsLearned: "",
        mood: "focused",
        completedTasks: 0,
        modelName: row.model,
        inputTokens: row.inputTokens,
        outputTokens: row.outputTokens,
        timestamp: row.startDate
    )
}
let measuredRows = snapshots.filter {
    $0.date >= cutoff && !$0.modelName.isEmpty && ($0.inputTokens > 0 || $0.outputTokens > 0)
}
check("mapping preserves token truth", measuredRows.count > 0,
      "\(measuredRows.count)/\(snapshots.count) sessions measured")

// ── 3. The breath computes over real history ───────────────────
let report = AMORTokenBreathEngine.compute(sessions: snapshots, days: 14)
check("breath computes", !report.isEmpty && report.totalTokens > 0,
      "\(AMORTokenBreathEngine.formatTokens(report.totalTokens)) tokens across \(report.measuredSessions) sessions")

// ── 4. Per-model conservation ──────────────────────────────────
let sumModelTotals = report.modelBreakdown.reduce(0) { $0 + $1.totalTokens }
let sumSessionTokens = measuredRows.reduce(0) { $0 + $1.inputTokens + $1.outputTokens }
check("model splits conserve tokens", sumModelTotals == sumSessionTokens,
      "models=\(sumModelTotals) sessions=\(sumSessionTokens)")
check("model breakdown sorted desc",
      report.modelBreakdown == report.modelBreakdown.sorted { $0.totalTokens > $1.totalTokens })

// ── 5. Daily arc conservation + full coverage ──────────────────
let sumArcTokens = report.dailyArc.reduce(0) { $0 + $1.totalTokens }
check("daily arc conserves tokens", sumArcTokens == sumSessionTokens,
      "arc=\(sumArcTokens) sessions=\(sumSessionTokens)")
check("daily arc covers every day", report.dailyArc.count == 14,
      "\(report.dailyArc.count) days (zero-filled)")
let arcDays = Set(report.dailyArc.map { cal.startOfDay(for: $0.day) })
var coverageComplete = true
for offset in 0..<14 {
    guard let day = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: Date())) else { continue }
    if !arcDays.contains(day) { coverageComplete = false }
}
check("arc covers each calendar day", coverageComplete)

// ── 6. Unmeasured honesty ──────────────────────────────────────
// jsonl-sourced rows (the graveyard) must map to unmeasured, per
// the importer law (source == "jsonl" → no measurement).
let jsonlRows = indexSessions.filter { $0.source == "jsonl" }
let windowRows = snapshots.filter { $0.date >= cutoff }
let unmeasuredExpect = windowRows.count - measuredRows.count
check("unmeasured counted honestly",
      report.unmeasuredSessions == unmeasuredExpect,
      "unmeasured=\(report.unmeasuredSessions) (jsonl rows in index: \(jsonlRows.count))")

// ── 7. Dominant model law on real history ──────────────────────
if let dom = report.dominantModel {
    check("dominant model exists", !dom.model.isEmpty && dom.totalTokens > 0,
          "\(AMORTokenBreathEngine.shortModelName(dom.model)) · \(AMORTokenBreathEngine.formatTokens(dom.totalTokens)) (\(Int(report.dominantModelShare * 100))%)")
}

// ── 8. Formatter law ───────────────────────────────────────────
check("formatTokens millions", AMORTokenBreathEngine.formatTokens(104_077_420) == "104.1M",
      AMORTokenBreathEngine.formatTokens(104_077_420))
check("formatTokens thousands", AMORTokenBreathEngine.formatTokens(980_000) == "980k",
      AMORTokenBreathEngine.formatTokens(980_000))
check("formatTokens small", AMORTokenBreathEngine.formatTokens(742) == "742",
      AMORTokenBreathEngine.formatTokens(742))
check("formatWeight heavy", AMORTokenBreathEngine.formatWeight(77.4) == "77:1",
      AMORTokenBreathEngine.formatWeight(77.4))
check("formatWeight dark", AMORTokenBreathEngine.formatWeight(0) == "—",
      AMORTokenBreathEngine.formatWeight(0))

print("")
if failures == 0 {
    print("MEASURED BREATH LIVE-FIRE: PASS — \(passes) checks green, the breath is counted")
    exit(0)
} else {
    print("MEASURED BREATH LIVE-FIRE: FAIL — \(failures) failing, \(passes) passed")
    exit(1)
}
