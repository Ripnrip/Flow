#!/bin/sh
# ═══════════════════════════════════════════════════════════════════
# LEG 15 (v6.1.0) — THE HONEST LEDGER, end-to-end.
#
# The Measured Breath (v6.0.0) counted tokens per model; the Next
# thread named the rot: counted but not priced. The Honest Ledger
# adds a Foundation-only cost engine (AMORCostLedger) with three
# laws:
#   - LONGEST-FRAGMENT: model ids match by case-insensitive
#     containment, longest fragment wins ("glm-5" ⊂ "glm-5.2" must
#     NEVER cross-match).
#   - CENT-CONSERVATION: total == Σ per-model cents, exactly.
#   - UNPRICED-HONESTY: unknown models contribute zero dollars and
#     are named in the margin — never guessed, never silent.
#
# Compiles the SHIPPED engines straight from Flow/Flow/ (drift
# impossible) and fires against the REAL vein-mirrored index.
# ═══════════════════════════════════════════════════════════════════
set -e
cd "$(dirname "$0")"
ROOT="$(cd ../.. && pwd)"
SDK="$(xcrun --show-sdk-path)"
TMP="$(mktemp -d /tmp/amor-leg15.XXXX)"

cp leg15-main.swift "$TMP/main.swift"

swiftc -O -sdk "$SDK" \
  "$ROOT/Flow/Flow/AMORRemoteSyncEngine.swift" \
  "$ROOT/Flow/Flow/AMORSessionIndex.swift" \
  "$ROOT/Flow/Flow/AMORMirror.swift" \
  "$ROOT/Flow/Flow/AMORTokenBreathEngine.swift" \
  "$ROOT/Flow/Flow/AMORCostLedger.swift" \
  "$TMP/main.swift" \
  -lsqlite3 \
  -o "$TMP/leg15"

"$TMP/leg15"
status=$?

rm -rf "$TMP"
exit $status
