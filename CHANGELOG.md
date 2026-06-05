# Changelog

## 1.0.8 — 2026-06-04

- reports chart: pinch to zoom, drag to pan, double-click or reset button to fit

## 1.0.7 — 2026-06-04

- reports: reset filter + reload on every window open (fixes stale range on reopen)

## 1.0.6 — 2026-06-05

- popover: remove checkmark on auto-start at login row
- popover: show read-only version above quit
- popover chart x-axis labels use minute:second (`m:ss`)

## 1.0.5 — 2026-06-05

- report ui timestamps show local date/time (db unchanged)
- popover chart axis uses local `HH:mm:ss`
- readme: separate update section under install

## 1.0.4 — 2026-06-05

- homebrew cask: add `uninstall quit` for cleaner upgrades
- readme: document force reinstall when app missing from `/Applications`

## 1.0.3 — 2026-06-05

- report filter applies on refresh only (date picker no longer live-updates chart/stats)
- report window opens with today 00:00 → now range
- export re-fetches from db with current filter (fixes stale csv data)
- csv timestamps use local timezone offset instead of utc `Z`

## 1.0.2 — 2026-06-04

- reports window redesign: glass HUD, stat cards, full network info + all csv columns
- chart fixes: no overflow, clearer time axis (`HH:mm` instead of bare hours)
- sticky ping data table header
- error breakdown by ping failure type
- auto-clear data older than 30 days
- clear all data button in reports (with confirmation)

## 1.0.1 — 2026-06-04

- homebrew cask install (`brew tap anggiedimasta/pepepe` then `brew install --cask pepepe`)
- new app icon (same waveform as menu bar)
- ad-hoc codesign in build script
- readme badges + screenshots

## 1.0.0 — 2026-06-04

first public release

### what it does
- menu bar app that pings 1.1.1.1 + 8.8.8.8 every 2s
- live sparkline in the menu bar
- popover with ping chart + wifi info (ssid, rssi)
- notifications when connection drops or wifi gets weak
- sqlite log at `~/Library/Application Support/Pepepe/pepepe.sqlite`
- reports window: chart, network info, last 100 pings
- csv export with ping + wifi context (ssid, ipv4, gateway, bssid, rssi, dns, etc)
- auto-start at login toggle
- daily digest notification

### notes
- needs location permission to read wifi ssid (macos thing, not optional)
- csv export has full history; report table caps at 100 rows for sanity
