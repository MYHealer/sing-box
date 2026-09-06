#!/bin/sh
# sing-box proxy health check + auto failover
# Runs every hour via cron

PROXY="127.0.0.1:7890"
CONFIG="/etc/sing-box/config.json"
LOG_DIR="/tmp/sing-box-logs"
TODAY=$(date '+%Y-%m-%d')
LOG="$LOG_DIR/health-check-$TODAY.log"

# Node list: name|ip|port (priority order)
# Edit this list with your own nodes
NODES="
NODE1|1.2.3.4|12345
NODE2|5.6.7.8|12345
"

mkdir -p "$LOG_DIR"
# Delete logs older than 2 days
find "$LOG_DIR" -name "health-check-*.log" -mtime +2 -delete 2>/dev/null

log() {
    echo "$(date '+%H:%M:%S') $1" >> "$LOG"
}

get_current() {
    lua -e '
        local jsonc = require "luci.jsonc"
        local f = io.open("'"$CONFIG"'", "r")
        if not f then os.exit(1) end
        local cfg = jsonc.parse(f:read("*a"))
        f:close()
        if cfg and cfg.outbounds and cfg.outbounds[1] then
            io.write(cfg.outbounds[1].server or "")
        end
    '
}

test_proxy() {
    code=$(curl -sL -x http://$PROXY -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 https://www.gstatic.com/generate_204 2>/dev/null)
    if [ "$code" = "200" ] || [ "$code" = "204" ]; then
        sleep 2
        code2=$(curl -sL -x http://$PROXY -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 https://www.gstatic.com/generate_204 2>/dev/null)
        [ "$code2" = "200" ] || [ "$code2" = "204" ]
    else
        return 1
    fi
}

switch_node() {
    local ip="$1"
    local port="$2"
    local name="$3"
    lua /etc/sing-box/switch_node.lua "$ip" "$port"
    /etc/init.d/sing-box-tiny restart >/dev/null 2>&1
    sleep 15
    log "Switched to $name ($ip:$port)"
}

log "--- check start ---"
CURRENT_IP=$(get_current)
CURRENT_NAME=""
for node in $NODES; do
    ip=$(echo "$node" | cut -d'|' -f2)
    if [ "$ip" = "$CURRENT_IP" ]; then
        CURRENT_NAME=$(echo "$node" | cut -d'|' -f1)
        break
    fi
done
log "Current: ${CURRENT_NAME:-unknown} ($CURRENT_IP)"

if test_proxy; then
    log "OK - current node working"
    log "--- check end ---"
    exit 0
fi

log "FAILED - searching for working node..."

for node in $NODES; do
    name=$(echo "$node" | cut -d'|' -f1)
    ip=$(echo "$node" | cut -d'|' -f2)
    port=$(echo "$node" | cut -d'|' -f3)
    [ "$ip" = "$CURRENT_IP" ] && continue
    switch_node "$ip" "$port" "$name"
    if test_proxy; then
        log "OK - failover to $name ($ip:$port)"
        log "--- check end ---"
        exit 0
    else
        log "FAIL - $name ($ip:$port)"
    fi
done

log "ALL NODES FAILED"
log "--- check end ---"
