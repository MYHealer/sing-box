# sing-box OpenWrt Deployment

Minimal sing-box build for **OpenWrt mipsel_24kc** low-memory routers (120MB RAM).

## What's included

- TUIC / Hysteria / Hysteria2 outbound (via `with_quic` tag)
- Mixed inbound (HTTP + SOCKS5)
- DNS (UDP direct + proxy)
- Route rules (rule-set binary format)

## What's stripped

No build tags set for: gvisor, wireguard, tailscale, clash_api, ech, acme, dhcp, naive, cloudflared, usbip, ccm, ocm

---

## Build

**GitHub Actions:** Go to Actions → **Build OpenWrt mipsle** → Run workflow, enter version (e.g. `v1.14.0`).

**Local build:**
```bash
GOOS=linux GOARCH=mipsle GOMIPS=softfloat CGO_ENABLED=0 \
  go build -trimpath \
  -ldflags="-s -w -X runtime.godebugDefault=multipathtcp=0,tlssha1=1 -checklinkname=0" \
  -tags "with_quic" \
  -o sing-box-tiny \
  ./cmd/sing-box
```

---

## Deploy

### 1. Upload binary

```bash
ssh root@192.168.1.1 "/etc/init.d/sing-box-tiny stop 2>/dev/null; rm -f /usr/bin/sing-box-tiny"
ssh root@192.168.1.1 "rm -rf /tmp/*"
scp sing-box-tiny root@192.168.1.1:/usr/bin/sing-box-tiny
ssh root@192.168.1.1 "chmod +x /usr/bin/sing-box-tiny"
```

### 2. Upload config and scripts

```bash
# Config
scp openwrt/configs/config.json root@192.168.1.1:/etc/sing-box/config.json

# Scripts
scp openwrt/scripts/health-check.sh root@192.168.1.1:/etc/sing-box/health-check.sh
scp openwrt/scripts/switch_node.lua root@192.168.1.1:/etc/sing-box/switch_node.lua
scp openwrt/scripts/update-rules.sh root@192.168.1.1:/etc/sing-box/update-rules.sh
scp openwrt/scripts/sing-box-tiny.init root@192.168.1.1:/etc/init.d/sing-box-tiny

ssh root@192.168.1.1 "chmod +x /etc/sing-box/*.sh /etc/init.d/sing-box-tiny"
```

### 3. Download rule-set files

```bash
ssh root@192.168.1.1 "mkdir -p /etc/sing-box/ruleset"
# Download from PC then scp, or use router proxy:
ssh root@192.168.1.1 "curl -sL -x http://127.0.0.1:7890 -o /etc/sing-box/ruleset/cn.srs 'https://github.com/QuixoticHeart/rule-set/raw/refs/heads/ruleset/singbox/version5/cn.srs'"
ssh root@192.168.1.1 "curl -sL -x http://127.0.0.1:7890 -o /etc/sing-box/ruleset/cncidr.srs 'https://github.com/QuixoticHeart/rule-set/raw/refs/heads/ruleset/singbox/version5/cncidr.srs'"
```

### 4. Start

```bash
ssh root@192.168.1.1 "/etc/init.d/sing-box-tiny enable"
ssh root@192.168.1.1 "/etc/init.d/sing-box-tiny start"
```

### 5. Set up cron

```bash
# Health check every hour
ssh root@192.168.1.1 "echo '0 * * * * /etc/sing-box/health-check.sh' >> /etc/crontabs/root"
# Rule-set update every Sunday 3AM
ssh root@192.168.1.1 "echo '0 3 * * 0 /etc/sing-box/update-rules.sh' >> /etc/crontabs/root"
ssh root@192.168.1.1 "/etc/init.d/cron restart"
```

### 6. Verify

```bash
# Proxy test
curl -sL -x http://192.168.1.1:7890 -o /dev/null -w "%{http_code}" https://www.youtube.com
# Expected: 200

# Direct test
curl -sL -o /dev/null -w "%{http_code}" http://www.baidu.com
# Expected: 200
```

---

## Memory optimization

The init script sets `GOGC=20` and `GOMEMLIMIT=40MiB` for aggressive garbage collection. Expected RSS: ~15-18MB (vs ~20MB without).

| Item | Value |
|------|-------|
| Binary size | ~35MB |
| RSS (GOGC=20) | ~15-18MB |
| Total RAM | 120MB |

## Upstream sync

```bash
git remote add upstream https://github.com/SagerNet/sing-box.git
git fetch upstream
git merge upstream/main --no-edit
git push origin main
# Then trigger build workflow with new version tag
```

## Node switching

Edit `config.json` outbound section, or use the health check script which auto-failovers:
- Priority: US2 → US3 → SG1 → SG2 → ... → DE2
- Checks every hour via cron
- Logs to `/tmp/proxy-check.log`
