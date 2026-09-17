#!/bin/sh
# ═══════════════════════════════════════════════════════════════════
# LEG 16 (v6.2.0) — THE DAILY LEDGER, end-to-end.
#
# The Honest Ledger (v6.1.0) priced the window but showed one
# number for a fortnight. The Daily Ledger decomposes those SAME
# conserved cents per day, under two new laws:
#   - ARC ≡ LEDGER: Σ per-day cents == the aggregated ledger
#     total, exactly. Each priced model's window cents are
#     computed once (identical arithmetic to estimate(from:)),
#     then apportioned by largest remainder — never recomputed
#     per day, where 14 independent roundings would drift.
#   - ZERO-TOKEN LAW: only days that breathed carry fractional
#     claims — a day with no priced tokens can never earn
#     remainder cents.
#
# Compiles the SHIPPED engines straight from Flow/Flow/ (drift
# impossible) and fires against the REAL vein-mirrored index.
# ═══════════════════════════════════════════════════════════════════
set -e
cd "$(dirname "$0")"
ROOT="$(cd ../.. && pwd)"
SDK="$(xcrun --show-sdk-path)"
TMP="$(mktemp -d /tmp/amor-leg16.XXXX)"

cp leg16-main.swift "$TMP/main.swift"

swiftc -O -sdk "$SDK" \
  "$ROOT/Flow/Flow/AMORRemoteSyncEngine.swift" \
  "$ROOT/Flow/Flow/AMORSessionIndex.swift" \
  "$ROOT/Flow/Flow/AMORMirror.swift" \
  "$ROOT/Flow/Flow/AMORTokenBreathEngine.swift" \
  "$ROOT/Flow/Flow/AMORCostLedger.swift" \
  "$TMP/main.swift" \
  -lsqlite3 \
  -o "$TMP/leg16"

"$TMP/leg16"
status=$?

rm -rf "$TMP"
exit $status
