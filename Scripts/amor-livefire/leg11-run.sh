#!/bin/sh
# ═══════════════════════════════════════════════════════════════════
# LEG 11 (v5.7.0) — THE OPEN VEIN, end-to-end.
#
# AMOR's engines are filesystem-direct; a physical iPhone has no
# shared filesystem with the Mac, so the evidence plane was invisible
# there (honest zeros). The Open Vein fixes the physics:
#   FlowServer GET /api/v1/amor/evidence relays the ledgers, jobs.json,
#   EOD dumps and the daily note VERBATIM; the shipped client engine
#   materializes them under the sandbox home at the exact paths the
#   engines already read. Law stays client-side, one home, harness-
#   guarded. The write vein (POST /api/v1/amor/brain) appends to the
#   REAL vault daily note and restores it (LEDGER LAW).
#
# Compiles the SHIPPED client engine straight from Flow/Flow/ so
# harness-vs-shipped drift is impossible by construction.
# Fails if the daemon is down (leg 10 already gates aliveness).
# ═══════════════════════════════════════════════════════════════════
set -e
cd "$(dirname "$0")"
ROOT="$(cd ../.. && pwd)"
SDK="$(xcrun --show-sdk-path)"
TMP="$(mktemp -d /tmp/amor-leg11.XXXX)"

cp leg11-main.swift "$TMP/main.swift"

swiftc -O -sdk "$SDK" \
  "$ROOT/Flow/Flow/AMORRemoteSyncEngine.swift" \
  "$ROOT/Scripts/amor-livefire/AMORGroundTruth.swift" \
  "$ROOT/Scripts/amor-livefire/AMORCronStatusReader.swift" \
  "$ROOT/Scripts/amor-livefire/AMORExecutionTruth.swift" \
  "$ROOT/Scripts/amor-livefire/AMORStormSentinel.swift" \
  "$ROOT/Scripts/amor-livefire/AMORAlibiEngine.swift" \
  "$TMP/main.swift" \
  -lsqlite3 \
  -o "$TMP/leg11"

"$TMP/leg11"
status=$?

rm -rf "$TMP"
exit $status
