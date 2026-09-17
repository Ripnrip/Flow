#!/bin/sh
# Leg 10 (v5.6.0): FlowServer daemon gate — "The Undying Flame".
# FlowServer must not merely exist; it must be ALIVE under launchd:
#   1. launchd knows the job (com.amor.flowserver loaded)
#   2. /health on :17777 answers "🎉 FlowServer is alive"
# A manually-booted mortal that died with its shell FAILS this leg —
# exactly the failure mode that hid in plain sight since v5.5.0.
# Exits nonzero if the flame is out (and says how to relight it).

set -u
LABEL="com.amor.flowserver"
HEALTH_URL="http://127.0.0.1:17777/health"
DAEMON="$HOME/Developer/Flow/Scripts/flowserver-daemon.sh"

fail() {
  echo "FLOWSERVER-DAEMON: FAIL — $1"
  echo "  relight with: $DAEMON install"
  exit 1
}

# Check 1: launchd registration
ENTRY="$(launchctl list 2>/dev/null | grep "$LABEL" || true)"
[ -n "$ENTRY" ] || fail "launchd does not know $LABEL (daemon not installed/loaded)"

# Check 2: the flame itself — THE PATIENT VEIN (v6.2.0): one knock
# is not a verdict. The harness's own compile load (legs 8/9 run
# seconds before) can starve a 4GB box into moments of silence;
# the client engine retries (v6.2.0), so the gate must too. Dark
# only after three knocks with a breath between.
BODY=""
for attempt in 1 2 3; do
  BODY="$(curl -fsS -m 5 "$HEALTH_URL" 2>/dev/null || true)"
  case "$BODY" in
    *"FlowServer is alive"*) break ;;
    *) [ "$attempt" -lt 3 ] && sleep 4 ;;
  esac
done
case "$BODY" in
  *"FlowServer is alive"*)
    echo "FLOWSERVER-DAEMON: PASS — launchd entry [$ENTRY], health on :17777 green"
    exit 0
    ;;
  *)
    fail "port 17777 answered: '${BODY:-<silence>}' after 3 knocks (KeepAlive should have revived it — check $HOME/.hermes/logs/flowserver/)"
    ;;
esac
