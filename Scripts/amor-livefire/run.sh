#!/bin/sh
# CLT-safe live-fire harness runner.
# Builds to a temp path and removes it afterwards — the gateway lifecycle
# guard crashes on null bytes if a command references the compiled binary,
# so we never leave a Mach-O artifact in the repo directory.
#
# Legs:
#   1. Cron health      (real ~/.hermes/cron/jobs.json + executions.db run truth, v4.8.0)
#   2. Gita streak      (real ~/.hermes/logs/gita_progress.json + gym/meditation ledgers)
#   3. Dump parser v2   (real ~/wiki/raw/daily-summaries/*.md)
#   4. Second brain     (real ~/wiki vault: discovery, daily/ casing, EOD dumps, write round-trip)
#   5. Streak intelligence (v5.0.0 — mortal streaks, snapshot-fed; was never harness-compilable before)
#   6. Alibi engine     (v5.1.0 — cause attribution; executions ledger proves the pipe broke)
#   7. Engines          (v5.2.0 — the full illumination: Rhythm, Briefing, Nudge, WeeklyReview,
#                        SessionDump, DumpGenerator, ProgressTracker — 4,200+ lines never
#                        harness-compilable before the mirrors)
#   8. View smoke-compile (v5.3.0 — the whole view layer macro-stripped and typechecked
#                        under CLT: 62 files, the first full-view compile in app history)
#   9. Widget smoke-compile (v5.4.0 — WidgetsExtension typechecked as one unit)
#  10. FlowServer daemon  (v5.6.0 — the Undying Flame: launchd KeepAlive + /health
#                        on :17777; a dead mortal server fails the leg)
#  11. The Open Vein     (v5.7.0 — end-to-end: daemon → /amor/evidence → shipped
#                        client mirror → engine law; brain write + LEDGER LAW restore)
set -e
cd "$(dirname "$0")"
SDK="$(xcrun --show-sdk-path)"
TMP="$(mktemp -d)"

# Legs 1-3 + 5-6 (single binary: cron health, gita streak, dump parser, streak intel, alibi)
BIN="$TMP/cronfire"
swiftc -O -sdk "$SDK" AMORGroundTruth.swift AMORCronStatusReader.swift AMORExecutionTruth.swift AMORStormSentinel.swift AMORStreakIntelligence.swift AMORPracticeSnapshot.swift AMORAlibiEngine.swift main.swift -lsqlite3 -o "$BIN"
"$BIN"

echo ""

# Leg 7 (v5.2.0): the full illumination — all seven engines, Foundation-only.
# (Top-level statements require a file literally named main.swift; the leg-1-6
# binary is already linked, so overwriting the temp main.swift is safe.)
BIN7="$TMP/enginesfire"
cp engines-main.swift "$TMP/main.swift"
swiftc -O -sdk "$SDK" AMORMirror.swift AMORPracticeSnapshot.swift AMORExecutionTruth.swift AMORStormSentinel.swift AMORAlibiEngine.swift AMORStreakIntelligence.swift AMORWeeklyReviewEngine.swift AMORRhythmEngine.swift AMORBriefingEngine.swift AMORNudgeEngine.swift AMORSessionDumpAutomation.swift AMORDumpGenerator.swift AMORProgressTracker.swift "$TMP/main.swift" -lsqlite3 -o "$BIN7"
"$BIN7"

echo ""

# Leg 4 (v4.2.0): second-brain reality wiring.
# Writes a round-trip note into the real vault daily/, then removes it —
# LEDGER LAW: no phantom evidence left behind.
# (Top-level Swift code requires a file literally named main.swift.)
# v4.6.0: the EOD dumper v3 now authors a REAL note at daily/<today>.md.
# Snapshot it first and restore after — the round-trip must never destroy
# real evidence; the LEDGER LAW only claims the harness's own phantom.
TODAY=$(date +%Y-%m-%d)
SNAP="$TMP/daily-note-snapshot.md"
HAD_NOTE=0
if [ -f "$HOME/wiki/daily/$TODAY.md" ]; then
  cp "$HOME/wiki/daily/$TODAY.md" "$SNAP"
  HAD_NOTE=1
fi
BIN4="$TMP/secondbrain"
cp secondbrain-main.swift "$TMP/main.swift"
swiftc -O -sdk "$SDK" AMORSecondBrainManager.swift "$TMP/main.swift" -o "$BIN4"
"$BIN4"
status=$?

if [ $HAD_NOTE -eq 1 ]; then
  cp "$SNAP" "$HOME/wiki/daily/$TODAY.md"
  echo "[harness] real daily note restored after round-trip (evidence preserved)"
elif [ -f "$HOME/wiki/daily/$TODAY.md" ]; then
  rm "$HOME/wiki/daily/$TODAY.md"
  echo "[harness] round-trip note daily/$TODAY.md removed (LEDGER LAW: no phantom evidence)"
fi

rm -rf "$TMP"

# Leg 8 (v5.3.0): view-layer smoke-compile — macro-stripped temp copies of the
# ENTIRE app target, typechecked against the real sources. The first compile
# the view layer has ever had on this box. Exits nonzero on any type error.
# (v5.4.0 fix: this block previously sat AFTER `exit $status` — dead code; the
# gate never gated. Legs 8 and 9 now run before the harness exits and their
# failures fail the run.)
sh leg8-run.sh
status8=$?

echo ""

# Leg 9 (v5.4.0): widget-extension smoke-compile — the WidgetsExtension target
# (12 widget files + shared app files per the pbxproj) typechecked as one unit
# for the first time. Dynamic Island, Live Activity, Control Center, all five
# home-screen widgets. Exits nonzero on any type error.
sh leg9-run.sh
status9=$?

echo ""

# Leg 10 (v5.6.0): FlowServer daemon gate — the Undying Flame. The server
# must be registered with launchd (KeepAlive + RunAtLoad) AND answering
# /health on :17777. A manually-booted mortal that died with its shell
# fails here. Negative-tested: uninstall → exit 1.
sh leg10-run.sh
status10=$?

echo ""

# Leg 11 (v5.7.0): THE OPEN VEIN — end-to-end. The daemon relays the
# evidence plane verbatim; the SHIPPED client engine mirrors it and the
# law runs on the mirror. The write vein round-trips the real vault
# daily note (restored — LEDGER LAW). Compiles Flow/Flow/ sources
# directly, so harness-vs-shipped drift is impossible.
sh leg11-run.sh
status11=$?

if [ $status -ne 0 ] || [ $status8 -ne 0 ] || [ $status9 -ne 0 ] || [ $status10 -ne 0 ] || [ $status11 -ne 0 ]; then
  exit 1
fi
exit 0
