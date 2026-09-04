# sing-box-tiny

Minimal [sing-box](https://github.com/SagerNet/sing-box) build for **OpenWrt mipsel_24kc** low-memory routers (120MB RAM).

Fork with source-level protocol stripping, memory optimization, and smart routing rules.

## Specs

| Item | Value |
|------|-------|
| Target | linux/mipsle/softfloat, CGO disabled |
| Binary size | ~33MB |
| RSS | ~13-16MB |
| Available RAM | ~100MB after startup |
| Protocols | TUIC, Hysteria, Hysteria2, Direct, SOCKS5, HTTP, Mixed |

## What's included

- **QUIC protocols**: TUIC / Hysteria / Hysteria2 (via `with_quic` build tag)
- **Smart routing**: 100+ Chinese domain suffixes grouped by service category
- **DNS protection**: Per-category DNS routing to prevent DNS pollution
- **Remote rule sets**: Auto-update from GitHub every 168h (weekly)
- **Health check**: Hourly proxy test with automatic failover
- **Watchdog**: Auto-restart on crash (every 5 min via cron)
- **Memory optimization**: GOGC=20, GOMEMLIMIT=40MiB

## What's stripped

Source-level removal of unused protocols (~40 packages):

`shadowsocks` `vmess` `trojan` `vless` `snell` `tor` `ssh` `shadowtls` `anytls` `naive` `wireguard` `openconnect` `openvpn` `tailscale` `tun` `block` `bridge` `group` `fakeip` `mdns` `dhcp` `derp` `ccm` `ocm` `usbip` `acme` `resolved` `api` `ssmapi`

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

Replace `ROUTER_IP` with your router address (e.g. `192.168.1.1`).

### 1. Upload binary

```bash
ssh root@ROUTER_IP "/etc/init.d/sing-box-tiny stop 2>/dev/null; rm -f /usr/bin/sing-box-tiny"
scp sing-box-tiny root@ROUTER_IP:/usr/bin/sing-box-tiny
ssh root@ROUTER_IP "chmod +x /usr/bin/sing-box-tiny"
```

### 2. Upload config and scripts

```bash
# Edit config.json first: set YOUR_SERVER_IP, YOUR_UUID, YOUR_SNI
scp openwrt/configs/config.json root@ROUTER_IP:/etc/sing-box/config.json

# Scripts
scp openwrt/scripts/health-check.sh root@ROUTER_IP:/etc/sing-box/health-check.sh
scp openwrt/scripts/switch_node.lua root@ROUTER_IP:/etc/sing-box/switch_node.lua
scp openwrt/scripts/update-rules.sh root@ROUTER_IP:/etc/sing-box/update-rules.sh
scp openwrt/scripts/sing-box-tiny.init root@ROUTER_IP:/etc/init.d/sing-box-tiny

ssh root@ROUTER_IP "chmod +x /etc/sing-box/*.sh /etc/init.d/sing-box-tiny"
```

### 3. Start

```bash
ssh root@ROUTER_IP "/etc/init.d/sing-box-tiny enable"
ssh root@ROUTER_IP "/etc/init.d/sing-box-tiny start"
```

### 4. Set up cron

```bash
# Health check every hour (auto failover)
ssh root@ROUTER_IP "echo '0 * * * * /etc/sing-box/health-check.sh' >> /etc/crontabs/root"
# Rule-set update every Sunday 3AM (backup for remote auto-update)
ssh root@ROUTER_IP "echo '0 3 * * 0 /etc/sing-box/update-rules.sh' >> /etc/crontabs/root"
# Watchdog: restart if crashed
ssh root@ROUTER_IP "echo '*/5 * * * * pgrep sing-box-tiny || /etc/init.d/sing-box-tiny start' >> /etc/crontabs/root"
ssh root@ROUTER_IP "/etc/init.d/cron restart"
```

### 5. Verify

```bash
# Proxy test (via router)
curl -sL -x http://ROUTER_IP:7890 -o /dev/null -w "%{http_code}" https://www.google.com
# Expected: 200

# Direct test
curl -sL -o /dev/null -w "%{http_code}" https://music.163.com
# Expected: 200
```

---

## Routing algorithm

### Rule priority (top to bottom)

1. **DNS hijack** — intercept all DNS queries
2. **NetEase Cloud Music** — force direct (anti-proxy-detection)
3. **Video/Live** — Bilibili, iQiyi, Youku, Douyu, Huya, etc.
4. **Tencent** — QQ, WeChat, Tencent Cloud
5. **Alibaba** — Taobao, Tmall, Aliyun, Alipay
6. **Baidu** — Baidu, Baidu Cloud
7. **JD** — JD.com, JD Cloud
8. **ByteDance** — Douyin, Toutiao, Feishu
9. **Device vendors** — Xiaomi, Huawei, OPPO, vivo
10. **Social** — Weibo, Zhihu, Douban, Meituan, Pinduoduo
11. **Tools** — Ctrip, 58.com, Gitee, 12306
12. **CDN/Security** — 360, Qihoo
13. **`.cn` TLD** — all .cn domains
14. **cn rule set** — comprehensive Chinese domain list (auto-updates weekly)
15. **cncidr rule set** — Chinese IP ranges (auto-updates weekly)
16. **Private IP** — RFC1918 addresses
17. **Final** — everything else goes through proxy

### DNS routing

| DNS Server | Used For | Purpose |
|------------|----------|---------|
| 119.29.29.29 (Tencent) | NetEase, cn rule set | Prevent DNS pollution for sensitive apps |
| 223.5.5.5 (Alibaba) | Bilibili, Tencent, Alibaba, Baidu, JD, etc. | Fast local DNS for major services |
| 8.8.8.8 (Google) | Everything else | Via proxy, encrypted |
| 1.1.1.1 (Cloudflare) | Backup | Via proxy, encrypted |

### Rule set auto-update

Remote rule sets (`cn.srs`, `cncidr.srs`) auto-download from GitHub every **168 hours (weekly)** on sing-box startup. Manual update:

```bash
ssh root@ROUTER_IP "/etc/sing-box/update-rules.sh"
```

---

## Health check & failover

The `health-check.sh` script runs every hour via cron:

1. Test current proxy via `curl -x` to `gstatic.com/generate_204`
2. If failed, iterate through node list in priority order
3. Use `switch_node.lua` to safely modify config (only outbound, not DNS)
4. Restart sing-box and verify
5. Log to `/tmp/proxy-check.log`

Edit the `NODES` list in `health-check.sh` with your own nodes:
```sh
NODES="
US2|1.2.3.4|54070
US3|5.6.7.8|54070
SG1|9.10.11.12|54070
"
```

---

## Upstream sync

```bash
git remote add upstream https://github.com/SagerNet/sing-box.git
git fetch upstream
git merge upstream/stable --no-edit
git push origin testing
# Then trigger build workflow with new version tag
```

## License

Same as upstream sing-box — GPLv3.
