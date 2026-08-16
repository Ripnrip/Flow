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
cp cron-health-main.swift main.swift            # top-level code must live in main.swift
swiftc -O AMORGroundTruth.swift AMORCronStatusReader.swift main.swift -o cronfire
rm main.swift
./cronfire
```

## Expected output (2026-08-16 reference)

- Gita: days_completed, chapter/verse position, completedToday, streakDays
  (verified 2026-08-16: 75 days, Ch 6 V 1, completed today)
- Gym evidence dates (empty array is HONEST ZERO, not an error)
- Last 7 session dumps: sessions/cronOk/cronErr/skills per day
- Cron table: all enabled jobs + failing list (flagged the Monographs feeder
  Reminders-permission outage on 2026-08-16)

## Reading results

- `cronErr=1` every day = one persistently failing enabled cron (real, not a
  parser bug — cross-check the failing list at the bottom).
- `sessionsToday=0` on most days is expected: the EOD dump only counts
  user-facing work sessions, not cron runs.
