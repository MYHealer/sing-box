#!/bin/sh
# sing-box watchdog - restart if not running
# Runs every 2 min via cron

LOG_DIR="/tmp/sing-box-logs"
TODAY=$(date '+%Y-%m-%d')
LOG="$LOG_DIR/watchdog-$TODAY.log"

mkdir -p "$LOG_DIR"
# Delete logs older than 2 days
find "$LOG_DIR" -name "watchdog-*.log" -mtime +2 -delete 2>/dev/null

if ! pgrep sing-box-tiny >/dev/null; then
    export GOGC=20
    export GOMEMLIMIT=40MiB
    /usr/bin/sing-box-tiny run -c /etc/sing-box/config.json </dev/null >/dev/null 2>&1 &
    echo "$(date '+%H:%M:%S') watchdog: restarted sing-box (pid $!)" >> "$LOG"
fi
