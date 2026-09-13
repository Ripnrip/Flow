#!/bin/sh
# ═══════════════════════════════════════════════════════════════════
# LEG 12 (v5.8.0) — THE IRON PULSE, end-to-end.
#
# v5.7.0's Open Vein shipped TEXT evidence only — but the run-truth
# engine (AMORExecutionTruth) reads SQLite, not text. On the iPhone
# the run ledger was dark: isExecutionTruthAvailable=false, storm
# sentinel starved, alibi engine blind. The Iron Pulse extends the
# vein with binaryFiles: a consistent snapshot of the executions
# ledger (Online Backup API — .backup — because -readonly on a WAL
# db is flaky and VACUUM INTO is refused), base64 on the wire,
# materialized as REAL SQLite under the sandbox home. Zero engine-law
# changes; the whole run-truth food chain lights up on-device.
#
# MARKER LAW (negative-tested): a binary destination without the
# .vein sidecar is LIVE evidence — the Mac's own ledger — and is
# never clobbered by the mirror.
#
# Compiles the SHIPPED client engine straight from Flow/Flow/ so
# harness-vs-shipped drift is impossible by construction.
# Fails if the daemon is down (leg 10 already gates aliveness).
# ═══════════════════════════════════════════════════════════════════
set -e
cd "$(dirname "$0")"
ROOT="$(cd ../.. && pwd)"
SDK="$(xcrun --show-sdk-path)"
TMP="$(mktemp -d /tmp/amor-leg12.XXXX)"

cp leg12-main.swift "$TMP/main.swift"

swiftc -O -sdk "$SDK" \
  "$ROOT/Flow/Flow/AMORRemoteSyncEngine.swift" \
  "$ROOT/Scripts/amor-livefire/AMORGroundTruth.swift" \
  "$ROOT/Scripts/amor-livefire/AMORCronStatusReader.swift" \
  "$ROOT/Scripts/amor-livefire/AMORExecutionTruth.swift" \
  "$ROOT/Scripts/amor-livefire/AMORStormSentinel.swift" \
  "$ROOT/Scripts/amor-livefire/AMORAlibiEngine.swift" \
  "$TMP/main.swift" \
  -lsqlite3 \
  -o "$TMP/leg12"

"$TMP/leg12"
status=$?

rm -rf "$TMP"
exit $status
