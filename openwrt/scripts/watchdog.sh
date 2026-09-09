#!/bin/sh
# sing-box watchdog - restart if not running or port not listening
# Runs every 2 min via cron

LOG_DIR="/tmp/sing-box-logs"
TODAY=$(date '+%Y-%m-%d')
LOG="$LOG_DIR/watchdog-$TODAY.log"

mkdir -p "$LOG_DIR"
# Delete logs older than 2 days
find "$LOG_DIR" -name "watchdog-*.log" -mtime +2 -delete 2>/dev/null

NEED_RESTART=0

if ! pgrep sing-box-tiny >/dev/null; then
    NEED_RESTART=1
    REASON="process not found"
elif ! netstat -tlnp 2>/dev/null | grep -q ':7890 '; then
    NEED_RESTART=1
    REASON="port 7890 not listening"
fi

if [ "$NEED_RESTART" -eq 1 ]; then
    killall sing-box-tiny 2>/dev/null
    sleep 1
    export GOGC=10
    export GOMEMLIMIT=20MiB
    /usr/bin/sing-box-tiny run -c /etc/sing-box/config.json </dev/null >/dev/null 2>&1 &
    echo "$(date '+%H:%M:%S') watchdog: restarted ($REASON, pid $!)" >> "$LOG"
fi
