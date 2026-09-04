#!/bin/sh
# Update rule-set files via proxy
PROXY="http://127.0.0.1:7890"
BASE="https://github.com/QuixoticHeart/rule-set/raw/refs/heads/ruleset/singbox/version5"
DIR="/etc/sing-box/ruleset"

for name in cn cncidr; do
    curl -sL -x "$PROXY" -o "$DIR/${name}.srs.new" "$BASE/${name}.srs" && \
        mv "$DIR/${name}.srs.new" "$DIR/${name}.srs" && \
        echo "$name.srs updated" || \
        echo "$name.srs update FAILED"
done

/etc/init.d/sing-box-tiny restart
