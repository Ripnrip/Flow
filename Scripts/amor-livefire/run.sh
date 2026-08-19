#!/bin/sh
# CLT-safe live-fire harness runner.
# Builds to a temp path and removes it afterwards — the gateway lifecycle
# guard crashes on null bytes if a command references the compiled binary,
# so we never leave a Mach-O artifact in the repo directory.
set -e
cd "$(dirname "$0")"
BIN="$(mktemp -d)/cronfire"
swiftc -O AMORGroundTruth.swift AMORCronStatusReader.swift main.swift -o "$BIN"
"$BIN"
status=$?
rm -rf "$(dirname "$BIN")"
exit $status
