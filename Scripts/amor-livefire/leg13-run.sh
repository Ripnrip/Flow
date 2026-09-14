#!/bin/sh
# ═══════════════════════════════════════════════════════════════════
# LEG 13 (v5.9.0) — THE LIVING INDEX, end-to-end.
#
# Since v2.1.0 the app's session plane read ~/.hermes/sessions/*.jsonl
# — a graveyard (one stale file, 596 API request-dumps). The REAL
# sessions live in ~/.hermes/state.db (1,893+ rows at forging), and
# state.db's own sessions.json mirror says it plainly: "This is NOT
# the session list." Every "sessions today" count, rhythm score, and
# EOD dump has been importing ghosts.
#
# The Living Index: FlowServer projects the trailing 14 days of the
# sessions table into ~100 KB of JSONL relayed over the Open Vein
# (state.db itself is 671 MB — far too fat for the vein). The shipped
# client engine AMORSessionIndex reads index-first, ledger-second
# (direct SQLite with the WAL-safe READWRITE + query_only law), and
# only falls back to the legacy jsonl scan when both doors are dark.
#
# Compiles the SHIPPED client engines straight from Flow/Flow/ so
# harness-vs-shipped drift is impossible by construction.
# Fails if the daemon is down (leg 10 already gates aliveness).
# ═══════════════════════════════════════════════════════════════════
set -e
cd "$(dirname "$0")"
ROOT="$(cd ../.. && pwd)"
SDK="$(xcrun --show-sdk-path)"
TMP="$(mktemp -d /tmp/amor-leg13.XXXX)"

cp leg13-main.swift "$TMP/main.swift"

swiftc -O -sdk "$SDK" \
  "$ROOT/Flow/Flow/AMORRemoteSyncEngine.swift" \
  "$ROOT/Flow/Flow/AMORSessionIndex.swift" \
  "$TMP/main.swift" \
  -lsqlite3 \
  -o "$TMP/leg13"

"$TMP/leg13"
status=$?

rm -rf "$TMP"
exit $status
