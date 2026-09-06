#!/bin/sh
# ═══════════════════════════════════════════════════════════════════
# AMOR leg 9 — WIDGET-EXTENSION SMOKE-COMPILE (v5.4.0)
#
# v5.3.0 gave the app target its first full compile, but the WIDGET
# EXTENSION target never saw a compiler: no Xcode.app on this box means
# the extension (12 widget files + 9 shared app files per the pbxproj
# membershipExceptions) shipped dark — Dynamic Island, Live Activity,
# Control Center controls, all five home-screen widgets.
#
# This leg macro-strips TEMP COPIES (repo untouched) and typechecks the
# extension's true membership together against the macosx SDK.
#
# Law: LEDGER — temp dir removed, no Mach-O left in the repo.
# ═══════════════════════════════════════════════════════════════════
set -e
cd "$(dirname "$0")"
ROOT="$(cd ../.. && pwd)"          # repo root (Scripts/amor-livefire/../..)
SDK="$(xcrun --show-sdk-path)"
TMP="$(mktemp -d /tmp/amor-leg9.XXXX)"

python3 leg9-prep.py "$ROOT" "$TMP"

cd "$TMP"
# The typecheck: EVERYTHING or nothing — the extension's full membership.
if swiftc -typecheck -sdk "$SDK" -target arm64-apple-macos15.0 *.swift 2>"$TMP/errs.txt"; then
  echo "WIDGET-EXTENSION SMOKE-COMPILE: PASS — all transformed files typecheck (0 errors)"
  rm -rf "$TMP"
  exit 0
else
  echo "WIDGET-EXTENSION SMOKE-COMPILE: FAIL — errors:"
  grep "error:" "$TMP/errs.txt" | head -40
  echo "(full errors preserved at $TMP/errs.txt)"
  exit 1
fi
