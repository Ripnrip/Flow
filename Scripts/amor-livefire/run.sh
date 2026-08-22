#!/bin/sh
# CLT-safe live-fire harness runner.
# Builds to a temp path and removes it afterwards — the gateway lifecycle
# guard crashes on null bytes if a command references the compiled binary,
# so we never leave a Mach-O artifact in the repo directory.
#
# Legs:
#   1. Cron health      (real ~/.hermes/cron/jobs.json)
#   2. Gita streak      (real ~/.hermes/logs/gita_progress.json + gym/meditation ledgers)
#   3. Dump parser v2   (real ~/wiki/raw/daily-summaries/*.md)
#   4. Second brain     (real ~/wiki vault: discovery, daily/ casing, EOD dumps, write round-trip)
set -e
cd "$(dirname "$0")"
SDK="$(xcrun --show-sdk-path)"
TMP="$(mktemp -d)"

# Legs 1-3
BIN="$TMP/cronfire"
swiftc -O -sdk "$SDK" AMORGroundTruth.swift AMORCronStatusReader.swift main.swift -o "$BIN"
"$BIN"

echo ""

# Leg 4 (v4.2.0): second-brain reality wiring.
# Writes a round-trip note into the real vault daily/, then removes it —
# LEDGER LAW: no phantom evidence left behind.
# (Top-level Swift code requires a file literally named main.swift.)
BIN4="$TMP/secondbrain"
cp secondbrain-main.swift "$TMP/main.swift"
swiftc -O -sdk "$SDK" AMORSecondBrainManager.swift "$TMP/main.swift" -o "$BIN4"
"$BIN4"
status=$?

TODAY=$(date +%Y-%m-%d)
if [ -f "$HOME/wiki/daily/$TODAY.md" ]; then
  rm "$HOME/wiki/daily/$TODAY.md"
  echo "[harness] round-trip note daily/$TODAY.md removed (LEDGER LAW: no phantom evidence)"
fi

rm -rf "$TMP"
exit $status
