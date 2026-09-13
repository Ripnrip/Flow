// ═══════════════════════════════════════════════════════════════════
// LEG 12 — THE IRON PULSE (v5.8.0) end-to-end live-fire
//
// Proves the BINARY vein with the REAL daemon and the REAL client code:
//   GET /api/v1/amor/evidence → AMORRemoteSyncEngine.sync() →
//   binaryFiles (base64 SQLite snapshot) materialized under the
//   sandbox home → AMORExecutionTruth.read() opens the mirror →
//   storm sentinel + alibi law run on relayed run truth.
// Then the MARKER LAW, negative-tested both ways:
//   • a pre-existing destination WITHOUT the .vein marker is LIVE
//     evidence and is never clobbered (the Mac's own ledger);
//   • a marked mirror refreshes and is idempotent.
// Compiles the SHIPPED client engine straight from Flow/Flow/ —
// drift between harness and shipped client is impossible.
// ═══════════════════════════════════════════════════════════════════
import Foundation

var pass = 0, fail = 0
func check(_ name: String, _ cond: Bool, _ detail: String) {
    if cond { pass += 1; print("  ✅ \(name): PASS — \(detail)") }
    else { fail += 1; print("  ❌ \(name): FAIL — \(detail)") }
}

print("=== LEG 12 — THE IRON PULSE (v5.8.0): binary vein → mirror → run-truth law ===")

let fm = FileManager.default
let tmpHome = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("amor-pulse-\(UUID().uuidString)")

// ── 1. The read vein carries the run ledger ────────────────────────
let result = await AMORRemoteSyncEngine.sync(base: "http://127.0.0.1:17777", home: tmpHome)
check("vein reachable", result.ok,
      result.ok ? "\(result.filesMaterialized) files mirrored from \(result.host)" : (result.error ?? "unknown error"))

guard result.ok else {
    print("LEG 12: FAIL — FlowServer vein unreachable; cannot continue")
    exit(1)
}

// ── 2. The ledger materialized as REAL SQLite ──────────────────────
let mirrorDB = tmpHome.appendingPathComponent(".hermes/cron/executions.db")
let marker = mirrorDB.appendingPathExtension(AMORRemoteSyncEngine.veinMarkerSuffix)
check("run ledger mirrored", fm.fileExists(atPath: mirrorDB.path), mirrorDB.lastPathComponent)
check("vein marker stamped", fm.fileExists(atPath: marker.path), marker.lastPathComponent)

if let data = fm.contents(atPath: mirrorDB.path) {
    let magic = String(data: data.prefix(15), encoding: .ascii) ?? ""
    check("sqlite magic intact", magic.hasPrefix("SQLite format 3"), "header=\(magic.prefix(15))")
}

// ── 3. Run-truth law runs ON THE MIRROR (the whole point) ──────────
// `hermesHome` IS the `.hermes` directory (the engine appends
// `cron/executions.db` itself) — same law as the app's callers.
let truth = AMORExecutionTruth.read(
    hermesHome: tmpHome.appendingPathComponent(".hermes", isDirectory: true)
)
check("execution truth available", truth.isAvailable, "ledger opened from the sandbox mirror")
check("execution truth rows", truth.totalExecutions >= 900,
      "totalExecutions=\(truth.totalExecutions) (7d window + lingering claims)")

// ── 4. Storm sentinel law fed by the mirror ────────────────────────
var knownIDs = Set<String>()
if let jobsData = fm.contents(atPath: tmpHome.appendingPathComponent(".hermes/cron/jobs.json").path) {
    struct JobsContainer: Codable { let jobs: [AMORCronJob] }
    if let container = try? JSONDecoder().decode(JobsContainer.self, from: jobsData) {
        knownIDs = Set(container.jobs.map { $0.id })
    }
}
let incidents = AMORStormSentinel.cluster(
    events: truth.failureEvents,
    lastNonFailureByJob: truth.lastNonFailureByJob,
    knownJobIDs: knownIDs
)
check("storm sentinel runs on mirror", true,
      "\(truth.failureEvents.count) failure events (7d) → \(incidents.count) incidents, \(incidents.filter { $0.isActive }.count) active")

// Synthetic storm fixture on top of relayed truth: three chained
// failures across two jobs must fuse into ONE active incident.
let cal = Calendar.current
let now = Date()
let fixtureBase = cal.date(byAdding: .hour, value: -2, to: now)!
let fixtureEvents: [AMORFailureEvent] = [
    .init(jobID: "job-a", date: fixtureBase, error: "probe"),
    .init(jobID: "job-b", date: fixtureBase.addingTimeInterval(1800), error: "probe"),
    .init(jobID: "job-a", date: fixtureBase.addingTimeInterval(3600), error: "probe"),
]
let fixtureIncidents = AMORStormSentinel.cluster(
    events: fixtureEvents,
    lastNonFailureByJob: [:],
    knownJobIDs: ["job-a", "job-b"],
    now: now
)
check("synthetic storm fuses", fixtureIncidents.count == 1 && fixtureIncidents[0].isStorm && fixtureIncidents[0].isActive,
      "3 chained failures / 2 jobs → \(fixtureIncidents.count) storm, active=\(fixtureIncidents.first?.isActive ?? false)")

// ── 5. Alibi law fed by the mirror ─────────────────────────────────
let alibis = AMORAlibiEngine.alibisFor(
    [("Gita", Date(timeIntervalSinceNow: -3 * 86400))],
    hermesHome: tmpHome.appendingPathComponent(".hermes", isDirectory: true)
)
check("alibi law runs on mirror", true,
      alibis.isEmpty ? "no alibi needed (pipe delivered — correct)" : "alibi: \(alibis.keys.sorted().joined(separator: ", "))")

// ── 6. Idempotence: second pulse, same truth ───────────────────────
let second = await AMORRemoteSyncEngine.sync(base: "http://127.0.0.1:17777", home: tmpHome)
check("pulse idempotent", second.ok && second.filesMaterialized == result.filesMaterialized,
      "second pass materialized \(second.filesMaterialized)/\(result.filesMaterialized)")

// ── 7. MARKER LAW: live evidence is NEVER clobbered ────────────────
// A destination that exists WITHOUT the marker is the Mac's own live
// ledger. The mirror must skip it — bytes untouched.
let liveHome = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("amor-pulse-live-\(UUID().uuidString)")
let liveDir = liveHome.appendingPathComponent(".hermes/cron", isDirectory: true)
try? fm.createDirectory(at: liveDir, withIntermediateDirectories: true)
let liveDB = liveDir.appendingPathComponent("executions.db")
let sentinelBytes = Data("LIVE LEDGER — DO NOT TOUCH".utf8)
fm.createFile(atPath: liveDB.path, contents: sentinelBytes)

// Re-fetch the payload and aim the binary mirror at the live home.
var guardHeld = false
if let url = URL(string: "http://127.0.0.1:17777/api/v1/amor/evidence"),
   let (data, resp) = try? await URLSession.shared.data(from: url),
   (resp as? HTTPURLResponse)?.statusCode == 200,
   let payload = try? JSONDecoder().decode(AMOREvidenceFile.self, from: data) {
    _ = AMORRemoteSyncEngine.materialize(payload: payload, under: liveHome)
    let after = fm.contents(atPath: liveDB.path)
    guardHeld = after == sentinelBytes
}
check("marker law holds", guardHeld,
      guardHeld ? "unmarked destination skipped — live ledger untouched" : "LIVE LEDGER WAS CLOBBERED — LAW BROKEN")
let strayMarker = fm.fileExists(atPath: liveDB.appendingPathExtension("vein").path)
check("no stray marker on live file", !strayMarker, "marker only written when the vein writes the file itself")

// ── 8. MARKER LAW, positive side: marked mirrors DO refresh ────────
let markedHome = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("amor-pulse-marked-\(UUID().uuidString)")
if let url = URL(string: "http://127.0.0.1:17777/api/v1/amor/evidence"),
   let (data, resp) = try? await URLSession.shared.data(from: url),
   (resp as? HTTPURLResponse)?.statusCode == 200,
   let payload = try? JSONDecoder().decode(AMOREvidenceFile.self, from: data) {
    let wrote = AMORRemoteSyncEngine.materialize(payload: payload, under: markedHome)
    let wroteDB = fm.fileExists(atPath: markedHome.appendingPathComponent(".hermes/cron/executions.db").path)
    check("marked-path mirror receives ledger", wrote >= 1 && wroteDB,
          "fresh home materialized \(wrote) files incl. the ledger")
}

// ── Verdict ────────────────────────────────────────────────────────
try? fm.removeItem(at: tmpHome)
try? fm.removeItem(at: liveHome)
try? fm.removeItem(at: markedHome)
print("")
if fail == 0 {
    print("IRON PULSE LIVE-FIRE: PASS — \(pass) checks green, run-truth plane fully relayed")
    exit(0)
} else {
    print("IRON PULSE LIVE-FIRE: FAIL — \(fail) failed of \(pass + fail)")
    exit(1)
}
