#!/bin/sh
# sing-box rule set update (fallback for remote rule sets)
# Primary: sing-box auto-downloads remote rules every 168h (weekly)

RULESET_DIR="/etc/sing-box/ruleset"
LOG_DIR="/tmp/sing-box-logs"
TODAY=$(date '+%Y-%m-%d')
LOG="$LOG_DIR/ruleset-$TODAY.log"

mkdir -p "$LOG_DIR"
# Delete logs older than 2 days
find "$LOG_DIR" -name "ruleset-*.log" -mtime +2 -delete 2>/dev/null

log() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"; }

log "=== update start ==="

for name in cn cncidr; do
    URL="https://github.com/QuixoticHeart/rule-set/raw/refs/heads/ruleset/singbox/version5/${name}.srs"
    curl -sL -x http://127.0.0.1:7890 -o "$RULESET_DIR/${name}.srs.new" "$URL" 2>/dev/null
    SIZE=$(wc -c < "$RULESET_DIR/${name}.srs.new" 2>/dev/null)
    if [ "$SIZE" -gt 10240 ]; then
        mv "$RULESET_DIR/${name}.srs.new" "$RULESET_DIR/${name}.srs"
        log "OK $name.srs ($SIZE bytes)"
    else
        rm -f "$RULESET_DIR/${name}.srs.new"
        log "FAIL $name.srs (got $SIZE bytes)"
    fi
done

/etc/init.d/sing-box-tiny restart
log "=== update end ==="
