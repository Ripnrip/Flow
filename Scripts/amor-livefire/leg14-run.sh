#!/bin/sh
# ═══════════════════════════════════════════════════════════════════
# LEG 14 (v6.0.0) — THE MEASURED BREATH, end-to-end.
#
# The Living Index (v5.9.0) carried model + token truth into
# SwiftData — buried in prose notes. The Measured Breath promotes
# it to structured fields (DailySession.modelName/inputTokens/
# outputTokens → AMORSessionSnapshot), gives it a Foundation-only
# engine (AMORTokenBreathEngine: totals, per-model splits, breath
# weight, zero-filled daily arc), and a window in Insights.
#
# This leg compiles the SHIPPED engines straight from Flow/Flow/
# so harness-vs-shipped drift is impossible by construction, and
# fires the law against the REAL vein-mirrored index (re-pulses
# the vein first so the leg stands alone):
#   - mapping preserves token truth (importer law)
#   - per-model splits CONSERVE tokens (nothing lost/invented)
#   - daily arc conserves tokens AND covers every calendar day
#   - unmeasured sessions counted honestly, never guessed
#   - formatter law (104.1M / 980k / 77:1)
# ═══════════════════════════════════════════════════════════════════
set -e
cd "$(dirname "$0")"
ROOT="$(cd ../.. && pwd)"
SDK="$(xcrun --show-sdk-path)"
TMP="$(mktemp -d /tmp/amor-leg14.XXXX)"

cp leg14-main.swift "$TMP/main.swift"

swiftc -O -sdk "$SDK" \
  "$ROOT/Flow/Flow/AMORRemoteSyncEngine.swift" \
  "$ROOT/Flow/Flow/AMORSessionIndex.swift" \
  "$ROOT/Flow/Flow/AMORMirror.swift" \
  "$ROOT/Flow/Flow/AMORTokenBreathEngine.swift" \
  "$TMP/main.swift" \
  -lsqlite3 \
  -o "$TMP/leg14"

"$TMP/leg14"
status=$?

rm -rf "$TMP"
exit $status
