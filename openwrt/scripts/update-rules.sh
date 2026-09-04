#!/bin/sh
# sing-box rule set update (fallback for remote rule sets)
# Primary: sing-box auto-downloads remote rules every 168h (weekly)
# This script is for manual updates or if remote download fails

PROXY="http://127.0.0.1:7890"
BASE="https://github.com/QuixoticHeart/rule-set/raw/refs/heads/ruleset/singbox/version5"
DIR="/etc/sing-box/ruleset"
LOG="/tmp/ruleset-update.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M')] $1" >> "$LOG"; }

log "=== update start ==="

for name in cn cncidr; do
    curl -sL -x "$PROXY" -o "$DIR/${name}.srs.new" "$BASE/${name}.srs" 2>/dev/null
    # Validate: file must be > 1KB (not an error page)
    SIZE=$(wc -c < "$DIR/${name}.srs.new" 2>/dev/null)
    if [ "$SIZE" -gt 1024 ]; then
        mv "$DIR/${name}.srs.new" "$DIR/${name}.srs"
        log "$name.srs updated ($SIZE bytes)"
    else
        rm -f "$DIR/${name}.srs.new"
        log "$name.srs FAILED (got $SIZE bytes)"
    fi
done

/etc/init.d/sing-box-tiny restart
log "=== update end ==="
