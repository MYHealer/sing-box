#!/bin/sh
# sing-box watchdog - restart if not running
# Runs every 2 min via cron
if ! pgrep sing-box-tiny >/dev/null; then
    export GOGC=20
    export GOMEMLIMIT=40MiB
    /usr/bin/sing-box-tiny run -c /etc/sing-box/config.json </dev/null >/dev/null 2>&1 &
    echo "[$(date)] watchdog: restarted sing-box" >> /tmp/watchdog.log
fi
