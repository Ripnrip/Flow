#!/bin/sh
# ═══════════════════════════════════════════════════════════════════
# LEG 17 (v6.3.0) — THE DEAD PLANE DETECTOR, end-to-end.
#
# Twelve "missed" jobs is what a per-job view shows when the
# scheduler itself is a corpse. The sentinel reads the executions
# day-histogram and names the plane's own verdict:
#   - QUIET-DAY LAW: one quiet day is weather, never an outage.
#   - OPEN ≡ DARK: a ≥2-day quiet stretch reaching today is the
#     corpse signature; per-job "missed" chips are casualties.
#   - NO-EVIDENCE ≡ UNKNOWN: silence about silence.
#   - PRE-HISTORY LAW: days before the ledger's first row are the
#     ledger's adolescence, not outages.
#   - RESTART SCARS: reaped clusters name the supervisor kills.
#
# Compiles the SHIPPED engine straight from Flow/Flow/ (drift
# impossible). Fires against the REAL ledger (where the September
# outage scar must be named) plus synthetic corpse/living/anti-wolf/
# pre-history/empty/missing fixtures.
# ═══════════════════════════════════════════════════════════════════
set -e
cd "$(dirname "$0")"
ROOT="$(cd ../.. && pwd)"
SDK="$(xcrun --show-sdk-path)"
TMP="$(mktemp -d /tmp/amor-leg17.XXXX)"

cp leg17-main.swift "$TMP/main.swift"

swiftc -O -sdk "$SDK" \
  "$ROOT/Flow/Flow/AMORPlaneSentinel.swift" \
  "$TMP/main.swift" \
  -lsqlite3 \
  -o "$TMP/leg17"

"$TMP/leg17"
status=$?

rm -rf "$TMP"
exit $status
