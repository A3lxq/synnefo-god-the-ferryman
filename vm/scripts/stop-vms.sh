#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for NAME in portal waystation vault; do
  PIDFILE="$NAME/disks/vm.pid"
  if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
      kill "$PID"
      for i in $(seq 1 20); do
        kill -0 "$PID" 2>/dev/null || break
        sleep 0.5
      done
    fi
    rm -f "$PIDFILE" "$NAME/disks/monitor.sock"
  fi
  echo "$NAME stopped."
done
