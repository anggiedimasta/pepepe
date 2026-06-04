---
layout: default
title: Pepepe
---

# Pepepe

**macOS menu bar app.** Pings Cloudflare + Google DNS, tracks Wi‑Fi, tells you when the internet is acting up.

Made because it's too easy to blame Wi‑Fi when it's actually the ISP. Now you have receipts.

[Download latest release](https://github.com/anggiedimasta/pepepe/releases/latest){: .btn} &nbsp; [View on GitHub](https://github.com/anggiedimasta/pepepe)

## Screenshots

| Menu bar popover | Reports |
|---|---|
| ![Popover](screenshots/popover.png) | ![Reports](screenshots/reports.png) |

## Features

- Sparkline in the menu bar (green / orange / red by latency)
- Live ping chart, SSID, and signal strength in the popover
- Pings `1.1.1.1` and `8.8.8.8` every 2 seconds while running
- SQLite logging — survives restarts
- Reports window with date range, stat cards, chart, full network info, CSV export
- CSV rows include Wi‑Fi context: SSID, IP, gateway, BSSID, RSSI, DNS
- Notifications on connection drop or weak signal
- Optional auto-start at login

## Install

**Recommended — Homebrew:**

```bash
brew tap anggiedimasta/pepepe https://github.com/anggiedimasta/pepepe
brew install --cask pepepe
```

**Manual:** download the zip from [Releases](https://github.com/anggiedimasta/pepepe/releases), unzip, drag to Applications. If macOS says "damaged", run `xattr -cr /Applications/Pepepe.app` or right-click → Open.

**From source:**

```bash
git clone https://github.com/anggiedimasta/pepepe.git
cd pepepe
chmod +x build_app.sh
./build_app.sh
```

## Requirements

- macOS 14+ (Sonoma or later)
- Location permission — macOS requires this to read Wi‑Fi SSID

## Data

SQLite database: `~/Library/Application Support/Pepepe/pepepe.sqlite`

Export CSV from the reports window for a full dump. Data older than 30 days is auto-cleared; use **Clear All** in reports to wipe everything.

## License

[MIT](https://github.com/anggiedimasta/pepepe/blob/main/LICENSE)
