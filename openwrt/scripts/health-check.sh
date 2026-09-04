#!/bin/sh
# sing-box proxy health check + auto failover
# Runs every hour via cron
# Priority: US2 → US3 → SG1 → SG2 → SG3 → SG4 → KR1 → KR2 → US1 → DE1 → DE2

PROXY="127.0.0.1:7890"
CONFIG="/etc/sing-box/config.json"
LOG="/tmp/proxy-check.log"

NODES="
US2|168.222.0.35|19811
US3|168.222.0.79|10511
SG1|140.245.48.46|54070
SG2|140.245.60.234|20965
SG3|140.245.56.153|39852
SG4|140.245.60.3|14767
KR1|140.238.23.27|13040
KR2|132.226.170.239|60019
US1|150.136.229.230|32337
DE1|78.31.249.129|15762
DE2|78.31.249.206|37216
"

log() {
    echo "$(date '+%H:%M:%S') $1" >> "$LOG"
}

get_current() {
    sed -n 's/.*"server": *"\([0-9.]*\)".*/\1/p' "$CONFIG" | head -1
}

test_proxy() {
    code=$(curl -sL -x http://$PROXY -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 https://www.gstatic.com/generate_204 2>/dev/null)
    [ "$code" = "200" ] || [ "$code" = "204" ]
}

switch_node() {
    local ip="$1"
    local port="$2"
    local name="$3"
    lua /etc/sing-box/switch_node.lua "$ip" "$port"
    /etc/init.d/sing-box-tiny restart >/dev/null 2>&1
    sleep 5
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
    log "Current node OK"
    log "--- check end ---"
    exit 0
fi

log "Current node FAILED, searching..."

for node in $NODES; do
    name=$(echo "$node" | cut -d'|' -f1)
    ip=$(echo "$node" | cut -d'|' -f2)
    port=$(echo "$node" | cut -d'|' -f3)
    [ "$ip" = "$CURRENT_IP" ] && continue
    switch_node "$ip" "$port" "$name"
    if test_proxy; then
        log "Failover OK to $name ($ip:$port)"
        log "--- check end ---"
        exit 0
    else
        log "$name ($ip:$port) also FAILED"
    fi
done

log "ALL NODES FAILED"
log "--- check end ---"
