#!/bin/sh
# sing-box watchdog - restart if not running, port not listening, or proxy dead
# Runs every 2 min via cron

LOG_DIR="/tmp/sing-box-logs"
TODAY=$(date '+%Y-%m-%d')
LOG="$LOG_DIR/watchdog-$TODAY.log"

mkdir -p "$LOG_DIR"
# Delete logs older than 2 days
find "$LOG_DIR" -name "watchdog-*.log" -mtime +2 -delete 2>/dev/null

NEED_RESTART=0
REASON=""

if ! pgrep sing-box-tiny >/dev/null; then
    NEED_RESTART=1
    REASON="process not found"
elif ! netstat -tlnp 2>/dev/null | grep -q ':7890 '; then
    NEED_RESTART=1
    REASON="port 7890 not listening"
else
    CODE=$(curl -sL -x http://127.0.0.1:7890 -o /dev/null -w "%{http_code}" --connect-timeout 8 --max-time 12 https://www.gstatic.com/generate_204 2>/dev/null)
    if [ "$CODE" != "200" ] && [ "$CODE" != "204" ]; then
        CODE2=$(curl -sL -x http://127.0.0.1:7890 -o /dev/null -w "%{http_code}" --connect-timeout 8 --max-time 12 https://www.baidu.com 2>/dev/null)
        if [ "$CODE2" != "200" ]; then
            NEED_RESTART=1
            REASON="proxy dead (gstatic=$CODE baidu=$CODE2)"
        fi
    fi
fi

if [ "$NEED_RESTART" -eq 1 ]; then
    killall sing-box-tiny 2>/dev/null
    sleep 1
    killall -9 sing-box-tiny 2>/dev/null
    sleep 1
    export GOGC=10
    export GOMEMLIMIT=20MiB
    /usr/bin/sing-box-tiny run -c /etc/sing-box/config.json </dev/null >/dev/null 2>&1 &
    echo "$(date '+%H:%M:%S') watchdog: restarted ($REASON, pid $!)" >> "$LOG"
fi
