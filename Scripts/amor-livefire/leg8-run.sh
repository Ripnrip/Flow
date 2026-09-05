#!/bin/sh
# ═══════════════════════════════════════════════════════════════════
# AMOR leg 8 — VIEW-LAYER SMOKE-COMPILE (v5.3.0)
#
# The v5.2.0 illumination freed the ENGINES into the harness, but the
# VIEW layer (61 files, ~22k lines, 68 rewired snapshot call sites)
# had never been compiled by anything: no Xcode.app on this box means
# @Model / @Query / #Predicate / Summary macros never expand under CLT.
#
# This leg macro-strips TEMP COPIES (repo untouched) and typechecks the
# entire app target against the real engine sources with the macosx SDK.
# It has already caught real bugs the harness could never see:
#   - AMORActivityHeatmap:142  \(x, specifier:) inside a plain String
#     argument — illegal Swift, would not compile in Xcode either.
# Law: LEDGER — temp dir removed, no Mach-O left in the repo.
# ═══════════════════════════════════════════════════════════════════
set -e
cd "$(dirname "$0")"
ROOT="$(cd ../.. && pwd)"          # repo root (Scripts/amor-livefire/../..)
SDK="$(xcrun --show-sdk-path)"
TMP="$(mktemp -d /tmp/amor-leg8.XXXX)"

python3 leg8-prep.py "$ROOT/Flow/Flow" "$TMP"

# AppIntents probe governs the strip: the Summary/ParameterSummary macro
# is plugin-welded on CLT — record verdicts for the changelog.
swiftc -typecheck -sdk "$SDK" -target arm64-apple-macos15.0 /tmp/probe-ai.swift 2>/tmp/probe-ai.err \
  && echo "APPINTENTS: expands under CLT" \
  || echo "APPINTENTS: plugin-welded (Summary macro) — stripping parameterSummary blocks"

cd "$TMP"
# The typecheck: EVERYTHING or nothing.
if swiftc -typecheck -sdk "$SDK" -target arm64-apple-macos15.0 *.swift 2>"$TMP/errs.txt"; then
  echo "VIEW-LAYER SMOKE-COMPILE: PASS — all transformed files typecheck (0 errors)"
  rm -rf "$TMP"
  exit 0
else
  echo "VIEW-LAYER SMOKE-COMPILE: FAIL — errors:"
  grep "error:" "$TMP/errs.txt" | head -40
  echo "(full errors preserved at $TMP/errs.txt)"
  exit 1
fi
