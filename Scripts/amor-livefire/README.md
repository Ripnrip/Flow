# AMOR Live-Fire Harness (CLT-safe)

Verification harness for the AMOR data layer on machines without full Xcode
(SwiftData macro plugins ship only with Xcode.app; Command Line Tools cannot
expand `@Model` macros). The Foundation-only engines still type-check and run
with plain `swiftc`.

## Why

The v4.0.0 Ground Truth Sync engine reads real Hermes artifacts
(`~/.hermes/logs/*.json`, `~/wiki/raw/daily-summaries/session-dump-*.md`,
`~/.hermes/cron/jobs.json`). Parsers drift when artifact formats change — the
only honest verification is to run the compiled engine against TODAY's real
files and compare with reality. That's what this harness does.

## Files

- `AMORGroundTruth.swift`, `AMORCronStatusReader.swift`,
  `AMORSecondBrainManager.swift` — verbatim copies of the app sources
  (re-copy after editing the app files; the copies exist only so the
  harness is self-contained).
- `cron-health-main.swift` — entry point (compiled as `main.swift`).
- `engines-main.swift` — v5.2.0 leg-7 entry point: all seven engines.
- `AMORMirror.swift` + the five engine copies (`AMORBriefingEngine.swift`,
  `AMORRhythmEngine.swift`, `AMORNudgeEngine.swift`,
  `AMORWeeklyReviewEngine.swift`, `AMORSessionDumpAutomation.swift`,
  `AMORDumpGenerator.swift`, `AMORProgressTracker.swift`) — verbatim
  copies of the app sources (re-copy after editing the app files).
- `secondbrain-main.swift` — v4.2.0 second-brain leg (compiled as
  `main.swift`; writes a round-trip daily note then the runner removes it —
  LEDGER LAW: no phantom evidence).

## Run

```sh
cd Scripts/amor-livefire
./run.sh          # all four legs, temp-dir build, LEDGER-LAW cleanup
```

(`main.swift` is committed and already includes the v2 dump-parser
live-fire: cron health table + failing jobs + last-3-dumps tools assertion.
`cron-health-main.swift` is kept as the minimal cron-only variant.)

## Legs

1. **Cron health** — real `~/.hermes/cron/jobs.json`, enabled/failing table.
2. **Gita streak** — real `gita_progress.json` + gym/meditation ledgers.
3. **Dump parser v2** — last 3 real `~/wiki/raw/daily-summaries` dumps,
   asserts tools parse non-empty.
4. **Second brain (v4.2.0)** — discovers the real `~/wiki` vault, asserts
   lowercase `daily/` casing, parses EOD dumps (sessions/messages/tools),
   and completes a write round-trip into `daily/<today>.md` (removed after).
5. **Streak intelligence (v5.0.0)** — mortal streaks: derived chains, honest
   zeros, started-only denominators, all-dormant invitation.
6. **Alibi engine (v5.1.0)** — cause attribution: ledger-proven pipe breaks
   excuse blame, never resurrect the number.
7. **Engines (v5.2.0 — the full illumination)** — Rhythm, Briefing, Nudge,
   WeeklyReview, SessionDump, DumpGenerator, ProgressTracker: 21 asserts
   over 4,200+ lines that were NEVER harness-compilable before the
   Foundation-only mirrors (`AMORMirror.swift`). Includes the anti-wolf
   nudge-cadence law (both edges) and the evidence-safe dump cleanup.

## Expected output (2026-08-22 reference)

- Cron table: all enabled jobs + failing list (post-fix: only the
  Monographs feeder Reminders-permission outage remains)
- Last 3 dumps: sessions/tools/skills per day — 2026-08-17 was the first
  day TOOLS parsed non-empty (11 tools) after the dumper v2 rewrite
  (state.db-backed; dumps before 2026-08-17 honestly show tools=[])
- Second brain: `vault discovered: wiki @ /Users/admin/wiki`, 14 dumps
  parsed, round-trip write true

## Reading results

- `cronErr=1` every day = one persistently failing enabled cron (real, not a
  parser bug — cross-check the failing list at the bottom).
- `sessionsToday=0` on most days is expected: the EOD dump only counts
  user-facing work sessions, not cron runs.

## Leg 8 — View smoke-compile (v5.3.0)
`leg8-prep.py` + `leg8-run.sh`. Macro-strips temp copies of the whole app
target (`@Model`, `@Query`, `#Predicate`, `parameterSummary`, `#Preview`;
swaps `import SwiftData`/`ActivityKit`/`BackgroundTasks` for in-module
signature shims) and typechecks all 62 files with the CLT macosx SDK.
Catches wrong field names, bad argument labels, redeclarations, phantom
inits — everything the engine harness cannot see. Repo untouched; temp
dir removed. Exits nonzero on any error.

## Leg 9 — Widget-extension smoke-compile (v5.4.0)
`leg9-prep.py` + `leg9-run.sh`. The WidgetsExtension TARGET never saw a
compiler on this box: 12 widget files (~3.6k lines — Dynamic Island Live
Activity, five home-screen widgets, Control Center toggle, widget intents)
plus the shared app files the pbxproj compiles into the extension
(AMORWidgetShared, SharedTaskStore, TaskService, Item, SharedModels,
CommonViews, FlowLogger, TaskLingeringActor, TodoistService, FlowServerService,
CommandTile, DailyFocusSummary). Same law as leg 8: macro-strip temp copies,
signature-shim the iOS-only surface (ActivityKit, DynamicIsland,
ControlWidget, Liquid Glass), typecheck as ONE unit against the macosx SDK.
WidgetsControl.swift (pure iOS-18 Control-Center surface) is #if os(iOS)
wrapped in temp copies. Repo untouched; temp dir removed. Exits nonzero on
any error.

NOTE (v5.4.0): leg 8 previously sat AFTER `exit $status` in run.sh — dead
code, the gate never gated. Both legs now run before the harness exits and
fail the run on any error.
