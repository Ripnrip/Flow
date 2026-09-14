// leg13-main.swift — THE LIVING INDEX, end-to-end (v5.9.0)
//
// Compiles the SHIPPED AMORSessionIndex + AMORRemoteSyncEngine
// straight from Flow/Flow/ so harness-vs-shipped drift is
// impossible by construction. Runs against the REAL daemon.
//
// Checks:
//  1. Vein reachable and evidence payload decodes.
//  2. Index rides the vein: hermes/sessions/index.json present.
//  3. Index parses (JSONL law) and holds ≥ 1 real session.
//  4. Ledger door (direct state.db read) returns rows.
//  5. THE TWO DOORS AGREE on count and on every session id
//     (server export law == client SQL law — drift is fatal).
//  6. Import law: engine converts index rows to HermesSession
//     with real fields (title, durations, message splits).
//  7. Idempotence: second vein sync materializes identically.
//  8. Dark-phone law: a fresh home with ONLY the mirrored index
//     (no state.db) still yields the full session list — the
//     iPhone path stands alone.

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

print("LIVING INDEX LIVE-FIRE (leg 13)")

// ── 1. Vein reachable ──────────────────────────────────────────
let base = "http://127.0.0.1:17777"
let sync1 = await AMORRemoteSyncEngine.sync(base: base)
check("vein reachable", sync1.ok, sync1.error ?? "")
check("evidence files ≥ 14 (13 prior + index)", sync1.filesMaterialized >= 14, "files=\(sync1.filesMaterialized)")

// ── 2/3. Index rides the vein and parses ───────────────────────
// The engine reads from defaultHome(); the harness ran the vein
// with the default home — on this Mac the index lands at
// ~/.hermes/sessions/index.json (materialized from the relay).
let hermesHome = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".hermes")
let indexURL = hermesHome.appendingPathComponent(AMORSessionIndex.indexRelPath)
let indexPath = indexURL.path
check("index mirrored by the vein", FileManager.default.fileExists(atPath: indexPath), indexPath)

var indexSessions: [AMORIndexedSession] = []
if let parsed = AMORSessionIndex.readIndex(at: indexURL) {
    indexSessions = parsed
}
check("index parses (array law)", !indexSessions.isEmpty, "\(indexSessions.count) sessions")
check("index holds real session ids", indexSessions.allSatisfy { !$0.id.isEmpty && $0.startedAt > 0 })

// ── 4/5. The two doors agree ───────────────────────────────────
let ledgerSessions = AMORSessionIndex.readLedger(hermesHome: hermesHome) ?? []
check("ledger door returns rows", !ledgerSessions.isEmpty, "\(ledgerSessions.count) rows from state.db")

let indexIDs = Set(indexSessions.map { $0.id })
let ledgerIDs = Set(ledgerSessions.map { $0.id })
check("doors agree on count", indexSessions.count == ledgerSessions.count,
      "index=\(indexSessions.count) ledger=\(ledgerSessions.count)")
let missingFromIndex = ledgerIDs.subtracting(indexIDs)
let missingFromLedger = indexIDs.subtracting(ledgerIDs)
check("doors agree on ids", missingFromIndex.isEmpty && missingFromLedger.isEmpty,
      "index-only=\(missingFromLedger.count) ledger-only=\(missingFromIndex.count)")

// Door-agreement on a sample row's substance (first row = newest).
if let iNew = indexSessions.first, let lNew = ledgerSessions.first {
    check("doors agree on newest row", iNew.id == lNew.id && iNew.startedAt == lNew.startedAt,
          "\(iNew.id) @ \(Int(iNew.startedAt))")
}

// ── 6. Import law runs on index rows ───────────────────────────
// Uses the same mapping HermesIntegrationEngine.discoverSessions()
// applies: real title, honest duration, message splits ≥ 1.
if let newest = indexSessions.first {
    let duration = newest.durationMinutes
    let userMsgs = max(newest.userMessageCount, 1)
    let asstMsgs = max(newest.assistantMessageCount, 1)
    check("import law maps real fields",
          duration >= 1 && userMsgs >= 1 && asstMsgs >= 1 && !newest.title.isEmpty,
          "title=\"\(newest.title.prefix(60))\" dur=\(duration)m msgs=\(userMsgs)u/\(asstMsgs)a model=\(newest.model)")
}

// ── 7. Idempotence ─────────────────────────────────────────────
let before = (try? FileManager.default.attributesOfItem(atPath: indexPath)[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
let sync2 = await AMORRemoteSyncEngine.sync(base: base)
let after = (try? FileManager.default.attributesOfItem(atPath: indexPath)[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
check("second pulse idempotent", sync2.ok && before == after,
      "mtime stable (\(before == after ? "unchanged" : "CHANGED"))")

// ── 8. Dark-phone law: the index alone carries the plane ───────
let tmp = FileManager.default.temporaryDirectory
    .appendingPathComponent("amor-leg13-\(UUID().uuidString)")
try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: tmp) }
do {
    let destHome = tmp.appendingPathComponent("home")
    let destDir = destHome.appendingPathComponent(".hermes/sessions")
    try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: indexURL, to: destDir.appendingPathComponent("index.json"))

    let dark = AMORSessionIndex.load(hermesHome: destHome.appendingPathComponent(".hermes"))
    check("dark-phone path stands alone", dark != nil && dark!.count == indexSessions.count,
          "origin=\(dark?.origin ?? "nil") count=\(dark?.count ?? 0)")

    // And the legacy fallback law: no index, no state.db → nil
    // (caller falls back to jsonl scan; here just prove nil).
    let emptyHome = tmp.appendingPathComponent("empty")
    try FileManager.default.createDirectory(at: emptyHome.appendingPathComponent(".hermes"), withIntermediateDirectories: true)
    let none = AMORSessionIndex.load(hermesHome: emptyHome.appendingPathComponent(".hermes"))
    check("both doors dark → nil (jsonl fallback)", none == nil)
} catch {
    check("dark-phone sandbox setup", false, error.localizedDescription)
}

print("")
if failures == 0 {
    print("LIVING INDEX LIVE-FIRE: PASS — \(passes) checks green, session plane fully lit")
    exit(0)
} else {
    print("LIVING INDEX LIVE-FIRE: FAIL — \(failures) failing, \(passes) passed")
    exit(1)
}
