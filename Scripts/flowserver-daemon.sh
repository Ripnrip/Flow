#!/bin/sh
# AMOR FlowServer daemon control — v5.6.0 "The Undying Flame"
#
# FlowServer was a mortal: manually booted, died on crash, died on reboot,
# port 17777 went dark and the iOS app's sync path had nothing to talk to.
# This rig makes it undying:
#   - launchd KeepAlive    → resurrects on crash (ThrottleInterval 10s)
#   - RunAtLoad            → survives reboot
#   - this wrapper         → datestamped logs, keeps last 7, sane env
#
# Usage: flowserver-daemon.sh {install|uninstall|start|stop|status|run}
# The plist runs this script with "run"; launchd owns the lifecycle.

set -u

LABEL="com.amor.flowserver"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG_DIR="$HOME/.hermes/logs/flowserver"
BIN="/Users/admin/Developer/Flow/FlowServer/.build/release/FlowServer"

log() { printf '[flowserver-daemon] %s\n' "$*"; }

rotate_logs() {
  # Keep the newest 7 stdout/stderr pairs. LEDGER LAW: no unbounded growth.
  ls -1t "$LOG_DIR"/flowserver-*.log 2>/dev/null | tail -n +15 | xargs rm -f 2>/dev/null || true
}

cmd_install() {
  mkdir -p "$HOME/Library/LaunchAgents" "$LOG_DIR"
  cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>$HOME/Developer/Flow/Scripts/flowserver-daemon.sh</string>
        <string>run</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>10</integer>
    <key>ProcessType</key>
    <string>Background</string>
    <key>WorkingDirectory</key>
    <string>/Users/admin/Developer/Flow</string>
</dict>
</plist>
EOF
  log "plist written: $PLIST"
}

cmd_run() {
  # Invoked by launchd. Datestamp each boot's log; rotate old ones.
  mkdir -p "$LOG_DIR"
  STAMP="$(date +%Y%m%d-%H%M%S)"
  LOG="$LOG_DIR/flowserver-$STAMP.log"
  rotate_logs
  log "FlowServer daemon booting → $LOG"
  exec "$BIN" >> "$LOG" 2>&1
}

health() { curl -fsS -m 5 http://127.0.0.1:17777/health 2>/dev/null; }

cmd_status() {
  log "launchctl: $(launchctl list 2>/dev/null | grep "$LABEL" || echo 'NOT LOADED')"
  if [ "$(health)" = "🎉 FlowServer is alive" ]; then
    log "health: ✅ ALIVE on :17777 — $(health)"
    exit 0
  else
    log "health: ❌ DEAD on :17777"
    exit 1
  fi
}

case "${1:-}" in
  install)
    cmd_install
    launchctl unload "$PLIST" 2>/dev/null || true
    launchctl load "$PLIST" && log "loaded — undying flame lit"
    ;;
  uninstall)
    launchctl unload "$PLIST" 2>/dev/null && log "unloaded" || log "was not loaded"
    rm -f "$PLIST" && log "plist removed"
    ;;
  start)
    launchctl load "$PLIST" 2>/dev/null || launchctl start "$LABEL"
    log "start issued"
    ;;
  stop)
    launchctl unload "$PLIST" 2>/dev/null
    log "stop issued"
    ;;
  run)     cmd_run ;;
  status)  cmd_status ;;
  *) echo "usage: $0 {install|uninstall|start|stop|status|run}" >&2; exit 2 ;;
esac
