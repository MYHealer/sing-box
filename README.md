# sing-box-tiny

Minimal [sing-box](https://github.com/SagerNet/sing-box) build optimized for **OpenWrt low-memory routers** (120MB RAM, mipsel_24kc).

## What this fork adds

- **Source-level protocol stripping**: ~40 unused packages removed, binary 33MB (vs 40MB+)
- **Memory optimization**: GOGC=20 + GOMEMLIMIT=40MiB, RSS ~13-16MB
- **Smart Chinese routing**: 100+ domain rules grouped by service, DNS pollution protection
- **Remote rule sets**: Auto-update from GitHub weekly
- **Health check**: Hourly proxy test with automatic node failover
- **Watchdog**: Auto-restart on crash

## Quick start

See [openwrt/README.md](openwrt/README.md) for deployment guide.

**Build:** Actions → Build OpenWrt mipsle → Run workflow → enter version

**Deploy:** Upload binary + config to router, set up cron

## Build tags

Only `with_quic` is used (TUIC + Hysteria + Hysteria2). All other protocols are stripped at source level.

## Upstream

Based on [SagerNet/sing-box](https://github.com/SagerNet/sing-box). Sync with upstream:

```bash
git remote add upstream https://github.com/SagerNet/sing-box.git
git fetch upstream
git merge upstream/stable --no-edit
```

## License

Same as upstream — GPLv3.
