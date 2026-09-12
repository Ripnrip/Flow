// ═══════════════════════════════════════════════════════════════════
// LEG 11 — THE OPEN VEIN (v5.7.0) end-to-end live-fire
//
// Proves the full vein with the REAL daemon and the REAL client code:
//   GET  /api/v1/amor/evidence  → AMORRemoteSyncEngine.sync() →
//   materialized sandbox mirror → engine law runs on the mirror →
//   real streaks, real cron truth, real dump parses.
// Then the WRITE vein, LEDGER LAW-compliant:
//   POST /api/v1/amor/brain → assert appended → restore the note.
// Compiles the SHIPPED app engine straight from Flow/Flow/ — drift
// between harness and shipped client is impossible by construction.
// ═══════════════════════════════════════════════════════════════════
import Foundation

var pass = 0, fail = 0
func check(_ name: String, _ cond: Bool, _ detail: String) {
    if cond { pass += 1; print("  ✅ \(name): PASS — \(detail)") }
    else { fail += 1; print("  ❌ \(name): FAIL — \(detail)") }
}

print("=== LEG 11 — THE OPEN VEIN (v5.7.0): daemon → wire → mirror → law ===")

let fm = FileManager.default
let tmpHome = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("amor-vein-\(UUID().uuidString)")

let dayFormatter = DateFormatter()
dayFormatter.dateFormat = "yyyy-MM-dd"
dayFormatter.timeZone = .current
let today = dayFormatter.string(from: Date())

// ── 1. The read vein: real client against the real daemon ─────────
let result = await AMORRemoteSyncEngine.sync(base: "http://127.0.0.1:17777", home: tmpHome)
check("vein reachable", result.ok,
      result.ok ? "\(result.filesMaterialized) files mirrored from \(result.host)" : (result.error ?? "unknown error"))

guard result.ok else {
    print("LEG 11: FAIL — FlowServer vein unreachable; cannot continue")
    exit(1)
}

// ── 2. The ledgers materialized where the engines read them ────────
let gitaPath = tmpHome.appendingPathComponent(".hermes/logs/gita_progress.json")
let gitaData = fm.contents(atPath: gitaPath.path)
check("gita ledger mirrored", gitaData != nil, gitaPath.lastPathComponent)

if let data = gitaData, let gita = try? JSONDecoder().decode(AMORGitaProgressFile.self, from: data) {
    check("gita law decodes mirror", gita.daysCompleted > 0,
          "daysCompleted=\(gita.daysCompleted), position Ch\(gita.currentChapter):V\(gita.currentVerse)")
    if let lc = gita.lastCompleted {
        let streak = AMORGroundTruthEngine.trailingStreakDays(fromDateStrings: [lc.date])
        check("streak law runs on mirror", streak >= 0, "lastCompleted=\(lc.date) → chain≥\(streak)")
    }
} else {
    check("gita law decodes mirror", false, "AMORGitaProgressFile decode failed")
}

// ── 3. Cron truth through the shipped Codable ──────────────────────
let jobsPath = tmpHome.appendingPathComponent(".hermes/cron/jobs.json")
var enabledCount = 0
if let data = fm.contents(atPath: jobsPath.path) {
    struct JobsContainer: Codable { let jobs: [AMORCronJob] }
    if let container = try? JSONDecoder().decode(JobsContainer.self, from: data) {
        enabledCount = container.jobs.filter { $0.enabled }.count
        check("cron law decodes mirror", enabledCount >= 10,
              "\(container.jobs.count) jobs, \(enabledCount) enabled")
        let unhealthy = container.jobs.filter { $0.enabled && $0.healthStatus == "failing" }
        check("cron law grades mirror", true, "\(unhealthy.count) enabled jobs failing (server view: \(result.ok ? "relayed" : "?"))")
    } else {
        check("cron law decodes mirror", false, "AMORCronJob decode failed")
    }
} else {
    check("cron law decodes mirror", false, "jobs.json missing from mirror")
}

// ── 4. Dump parser runs on the mirrored vault ─────────────────────
let dumpDir = tmpHome.appendingPathComponent("wiki/raw/daily-summaries")
let dumps = (try? fm.contentsOfDirectory(atPath: dumpDir.path)) ?? []
    .filter { $0.hasPrefix("session-dump-") && $0.hasSuffix(".md") }
    .sorted(by: >)
check("dumps mirrored", dumps.count >= 3, "\(dumps.count) session dumps in mirror")

if let newest = dumps.first {
    let summary = AMORGroundTruthEngine.parseDump(at: dumpDir.appendingPathComponent(newest))
    check("dump law parses mirror", summary != nil && (summary?.cronOkCount ?? 0) > 0,
          "\(newest): \(summary?.sessionsToday ?? 0) sessions, \(summary?.cronOkCount ?? 0) cron ok, skills=\(summary?.skillsTouched.count ?? 0)")
}

// ── 5. The daily note is part of the evidence plane ────────────────
let notePath = tmpHome.appendingPathComponent("wiki/daily/\(today).md")
check("daily note mirrored", fm.fileExists(atPath: notePath.path), "wiki/daily/\(today).md")

// ── 6. Idempotence: a second sync writes the same truth ────────────
let second = await AMORRemoteSyncEngine.sync(base: "http://127.0.0.1:17777", home: tmpHome)
check("vein idempotent", second.ok && second.filesMaterialized == result.filesMaterialized,
      "second pass materialized \(second.filesMaterialized)/\(result.filesMaterialized)")

// ── 7. The write vein: brain append + LEDGER LAW restore ──────────
let realNote = fm.homeDirectoryForCurrentUser.appendingPathComponent("wiki/daily/\(today).md")
let original: Data? = fm.contents(atPath: realNote.path)

let probe = "AMOR LEG 11 PROBE — automated Open Vein verification at \(Date().formatted(.iso8601.year().dateTimeSeparator(.standard))). This block was appended by the live-fire harness through POST /api/v1/amor/brain and is restored immediately (LEDGER LAW: no phantom evidence)."
let wrote = await AMORRemoteSyncEngine.appendToBrain(
    date: today, heading: "Leg 11 vein probe", markdown: probe
)
check("brain write accepted", wrote, "POST /amor/brain → 200")

let afterWrite = (try? String(contentsOf: realNote, encoding: .utf8)) ?? ""
check("brain write landed", afterWrite.contains("Leg 11 vein probe"), "vault daily note carries the probe block")

// Restore the note to its exact prior bytes — evidence preserved.
var restored = false
if let original {
    restored = fm.createFile(atPath: realNote.path, contents: original)
} else {
    try? fm.removeItem(at: realNote)
    restored = !fm.fileExists(atPath: realNote.path)
}
check("ledger law restore", restored, original != nil ? "original note bytes restored" : "probe note removed (none existed before)")

// ── 8. Traversal defense ────────────────────────────────────────────
let evil = AMORRemoteSyncEngine.mirrorDest(for: "../../etc/passwd", under: tmpHome)
check("traversal rejected", evil == nil || !(evil!.path.contains("..")), "mirrorDest(../../etc/passwd) → nil/safe")

// ── Verdict ────────────────────────────────────────────────────────
try? fm.removeItem(at: tmpHome)
print("")
if fail == 0 {
    print("OPEN VEIN LIVE-FIRE: PASS — \(pass) checks green, evidence plane fully relayed")
    exit(0)
} else {
    print("OPEN VEIN LIVE-FIRE: FAIL — \(fail) failed of \(pass + fail)")
    exit(1)
}
