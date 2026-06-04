# Changelog

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
