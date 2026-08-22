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
guard let newest = dumps.first else {
    print("FAIL — no session dumps parsed from raw/daily-summaries")
    exit(1)
}
print("newest dump: \(newest.date.dateString) sessions=\(newest.sessions) messages=\(newest.messages) toolCalls=\(newest.toolCalls) tools=\(newest.tools)")

// HARD ASSERT: today's dump must parse with real numbers (dumper runs 1AM UTC)
assert(newest.messages > 0, "newest dump has 0 messages — parser broken")
assert(newest.toolCalls > 0, "newest dump has 0 tool calls — parser broken")
assert(!newest.tools.isEmpty, "newest dump parsed no tools — Tools Used table parser broken")

// ── 4. Daily-notes read path ────────────────────────────────────────────
let notes = brain.readDailyNotes(daysBack: 7)
print("daily notes found (7d): \(notes.count)")
for n in notes.prefix(3) {
    print("  note: \(n.path.split(separator: "/").last ?? "?") (\(n.content.count) chars)")
}

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
