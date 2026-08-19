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

- `AMORGroundTruth.swift`, `AMORCronStatusReader.swift` — verbatim copies of
  the app sources (re-copy after editing the app files; the copies exist only
  so the harness is self-contained).
- `cron-health-main.swift` — entry point (compiled as `main.swift`).

## Run

```sh
cd Scripts/amor-livefire
swiftc -O AMORGroundTruth.swift AMORCronStatusReader.swift main.swift -o cronfire
./cronfire
```

(`main.swift` is committed and already includes the v2 dump-parser
live-fire: cron health table + failing jobs + last-3-dumps tools assertion.
`cron-health-main.swift` is kept as the minimal cron-only variant.)

## Expected output (2026-08-17 reference)

- Cron table: all enabled jobs + failing list (post-fix: only the
  Monographs feeder Reminders-permission outage remains)
- Last 3 dumps: sessions/tools/skills per day — 2026-08-17 was the first
  day TOOLS parsed non-empty (11 tools) after the dumper v2 rewrite
  (state.db-backed; dumps before 2026-08-17 honestly show tools=[])

## Reading results

- `cronErr=1` every day = one persistently failing enabled cron (real, not a
  parser bug — cross-check the failing list at the bottom).
- `sessionsToday=0` on most days is expected: the EOD dump only counts
  user-facing work sessions, not cron runs.
