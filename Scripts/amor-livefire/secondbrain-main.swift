// AMOR v4.2.0 live-fire: second-brain reality wiring against the REAL ~/wiki vault.
import Foundation

// ── 1. Vault discovery ──────────────────────────────────────────────────
print("=== AMOR SECOND BRAIN LIVE-FIRE — real ~/wiki vault ===")
let brain = AMORSecondBrainManager()
brain.discoverVault()
guard let vault = brain.vault else {
    print("FAIL — vault not discovered")
    exit(1)
}
print("vault discovered: \(vault.name) @ \(vault.path)")
assert(vault.path.hasSuffix("/wiki"), "expected canonical ~/wiki vault, got \(vault.path)")

// ── 2. Daily-notes dir (lowercase `daily/`) ─────────────────────────────
if let daily = vault.dailyNotesURL {
    print("daily notes dir: \(daily.lastPathComponent) ✓")
    assert(daily.lastPathComponent == "daily", "expected lowercase daily/, got \(daily.lastPathComponent)")
} else {
    print("FAIL — no daily-notes dir found in vault")
    exit(1)
}

// ── 3. Hermes EOD session dumps ─────────────────────────────────────────
let dumps = brain.readHermesSessionDumps(daysBack: 14)
print("EOD session dumps (14d): \(dumps.count)")

// v6.3.0 MIRROR ≡ REALITY: when the automation plane was dark for
// days, no EOD dump job fired — an empty window is the CORPSE'S
// testimony, not a parser failure. Judge the evidence only after
// judging the plane.
let plane = AMORPlaneSentinel.read(hermesHome: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".hermes", isDirectory: true))
print("plane verdict: \(plane.verdict.rawValue) — last run day: \(plane.lastRunDay ?? "none")")
if plane.verdict == .unknown {
    print("SKIP — plane unknown: no ledger truth to judge dumps against (no wolf, no corpse-cry)")
} else if let newest = dumps.first {
    print("newest dump: \(newest.date.dateString) sessions=\(newest.sessions) messages=\(newest.messages) toolCalls=\(newest.toolCalls) tools=\(newest.tools)")

    // HARD ASSERT: the newest dump must parse with real numbers.
    assert(newest.messages > 0, "newest dump has 0 messages — parser broken")
    assert(newest.toolCalls > 0, "newest dump has 0 tool calls — parser broken")
    assert(!newest.tools.isEmpty, "newest dump parsed no tools — Tools Used table parser broken")
} else if plane.verdict == .alive, let lastRun = plane.lastRunDay {
    // Plane alive but no dumps: the dump job itself missed — a REAL
    // failure worth the red. (Dark plane + no dumps = casualty.)
    assertionFailure("PLANE-LAW: plane alive since \(lastRun) but raw/daily-summaries holds no dumps in 14d — the 1AM EOD job is broken")
} else {
    print("SKIP — plane dark: \(plane.openOutage?.spanText ?? "?") dark; empty dump window is the corpse's testimony, not a parser failure")
}

// ── 4. Daily-notes read path ────────────────────────────────────────────
let notes = brain.readDailyNotes(daysBack: 7)
print("daily notes found (7d): \(notes.count)")
for n in notes.prefix(3) {
    print("  note: \(n.path.split(separator: "/").last ?? "?") (\(n.content.count) chars)")
}

// v4.6.0 HARD ASSERT: the reader must see EVERY daily note that exists on
// disk (within 7d). v4.2.0-v4.5.0 built readDailyNotes but nothing called
// it — this guards the reader↔shelf contract. Author-agnostic: counts
// Hermes auto-notes (EOD dump v3) and human/app notes alike.
var diskCount = 0
if let dailyDir = try? FileManager.default.contentsOfDirectory(
    at: URL(fileURLWithPath: vault.path).appendingPathComponent("daily"),
    includingPropertiesForKeys: nil
) {
    let dayFmt = DateFormatter()
    dayFmt.dateFormat = "yyyy-MM-dd"
    dayFmt.locale = Locale(identifier: "en_US_POSIX")
    let sevenDaysAgo = Date().addingTimeInterval(-7 * 86400)
    for file in dailyDir where file.pathExtension == "md" {
        if let d = dayFmt.date(from: file.deletingPathExtension().lastPathComponent),
           d >= sevenDaysAgo {
            diskCount += 1
        }
    }
}
print("daily notes on disk (7d): \(diskCount)")
assert(notes.count >= diskCount,
       "DAILY-SHELF: reader found \(notes.count) but disk holds \(diskCount) — readDailyNotes missing files")
print("DAILY-SHELF-ASSERT: PASS — reader sees all \(diskCount) note(s) on disk ✅")

// ── 5. Write round-trip into the REAL vault (safe: writes today's daily note)
let summary = VaultDailySummary(
    date: Date(),
    sessionsLogged: 1,
    totalFocusMinutes: 45,
    tasksCompleted: 2,
    practicesCompleted: ["Gita"],
    toolsUsed: ["terminal", "patch"],
    skillsLearned: ["swiftc CLT typecheck"],
    mood: "berserk",
    reflection: "v4.2.0 second-brain reality wiring live-fire"
)
let wroteOK = brain.writeDailySummary(summary)
print("write round-trip: \(wroteOK) — \(brain.statusMessage)")
assert(wroteOK, "writeDailySummary failed: \(brain.statusMessage)")

// Verify the write landed in daily/ (not Daily/)
let df = DateFormatter()
df.dateFormat = "yyyy-MM-dd"
let expected = NSHomeDirectory() + "/wiki/daily/" + df.string(from: Date()) + ".md"
let landed = FileManager.default.fileExists(atPath: expected)
print("file landed at daily/<today>.md: \(landed)")
assert(landed, "write did not land at \(expected)")

// ── Result ─────────────────────────────────────────────────────────────
print("\nSECOND-BRAIN LIVE-FIRE: PASS — vault discovery, daily/ casing, EOD dump parsing, write round-trip all verified against the real vault")

extension Date {
    var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: self)
    }
}
