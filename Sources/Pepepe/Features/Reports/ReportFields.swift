import Foundation

struct ReportRow: Identifiable {
    let id: UUID
    let ping: PingResult
    let wifi: WiFiSnapshot?
    
    init(ping: PingResult, wifi: WiFiSnapshot?) {
        self.id = ping.id
        self.ping = ping
        self.wifi = wifi
    }
}

enum ReportFields {
    static let maxTableRows = 100
    static let maxChartPoints = 500
    static let csvColumns: [(key: String, label: String)] = [
        ("timestamp", "Timestamp"),
        ("target", "Target"),
        ("success", "Success"),
        ("pingError", "PingError"),
        ("latency", "Latency(ms)"),
        ("ssid", "SSID"),
        ("ipv4", "IPv4"),
        ("gateway", "Gateway"),
        ("bssid", "BSSID"),
        ("rssi", "RSSI"),
        ("noise", "Noise"),
        ("snr", "SNR(dB)"),
        ("channel", "Channel"),
        ("band", "Band"),
        ("txRate", "TxRate(Mbps)"),
        ("phy", "PHY"),
        ("interface", "Interface"),
        ("ipv6", "IPv6"),
        ("dns", "DNS"),
    ]
    
    static let windowOnlyColumns: [(key: String, label: String)] = [
        ("clientMac", "Client MAC"),
        ("security", "Security"),
    ]
    
    static func csvHeader() -> String {
        csvColumns.map(\.label).joined(separator: ",") + "\n"
    }
    
    static func csvRow(for row: ReportRow) -> String {
        let values = csvColumns.map { column in
            csvField(csvRawValue(for: column.key, row: row))
        }
        return values.joined(separator: ",")
    }
    
    static let networkInfoColumns: [(key: String, label: String)] = [
        ("ssid", "SSID"),
        ("ipv4", "IPv4"),
        ("gateway", "Gateway"),
        ("bssid", "BSSID"),
        ("rssi", "RSSI"),
        ("noise", "Noise"),
        ("snr", "SNR(dB)"),
        ("channel", "Channel"),
        ("band", "Band"),
        ("txRate", "TxRate(Mbps)"),
        ("phy", "PHY"),
        ("interface", "Interface"),
        ("ipv6", "IPv6"),
        ("dns", "DNS"),
    ]
    
    static func networkInfoItems(for wifi: WiFiSnapshot?) -> [(label: String, value: String)] {
        var items = networkInfoColumns.map { (label: $0.label, value: value(for: $0.key, wifi: wifi, ping: nil)) }
        for col in windowOnlyColumns {
            items.append((label: col.label, value: value(for: col.key, wifi: wifi, ping: nil)))
        }
        return items
    }
    
    static func tableValue(for key: String, row: ReportRow) -> String {
        rawValue(for: key, row: row)
    }
    
    private static func rawValue(for key: String, row: ReportRow) -> String {
        switch key {
        case "timestamp":
            return TimeFormatter.formatDisplayDateTime(row.ping.timestamp)
        default:
            return value(for: key, row: row)
        }
    }
    
    private static func csvRawValue(for key: String, row: ReportRow) -> String {
        switch key {
        case "timestamp":
            return csvTimestampFormatter.string(from: row.ping.timestamp)
        default:
            return value(for: key, row: row)
        }
    }
    
    private static func value(for key: String, row: ReportRow) -> String {
        value(for: key, wifi: row.wifi, ping: row.ping)
    }
    
    private static func value(for key: String, wifi: WiFiSnapshot?, ping: PingResult?) -> String {
        switch key {
        case "target":
            return ping?.target ?? "—"
        case "success":
            guard let ping else { return "—" }
            return ping.isSuccess ? "true" : "false"
        case "pingError":
            guard let ping else { return "—" }
            if ping.isSuccess { return "" }
            return ping.errorType == .none ? PingErrorType.unknown.rawValue : ping.errorType.rawValue
        case "latency":
            guard let ping, let lat = ping.latencyMs else { return "" }
            return String(format: "%.2f", lat)
        case "ssid":
            return wifi?.ssid ?? ""
        case "ipv4":
            return wifi?.ipv4 ?? ""
        case "gateway":
            return wifi?.gateway ?? ""
        case "bssid":
            return wifi?.bssid ?? ""
        case "rssi":
            guard let wifi else { return "" }
            return String(wifi.rssi)
        case "noise":
            guard let wifi else { return "" }
            return String(wifi.noise)
        case "snr":
            guard let wifi else { return "" }
            return String(wifi.snr)
        case "channel":
            guard let wifi else { return "" }
            return String(wifi.channel)
        case "band":
            return wifi?.band ?? ""
        case "txRate":
            guard let wifi else { return "" }
            return String(format: "%.1f", wifi.txRate)
        case "phy":
            return wifi?.phyMode ?? ""
        case "interface":
            return wifi?.interfaceName ?? ""
        case "ipv6":
            return wifi?.ipv6 ?? ""
        case "dns":
            return wifi?.dnsServers ?? ""
        case "clientMac":
            return wifi?.clientMac ?? ""
        case "security":
            return wifi?.securityType ?? ""
        default:
            return ""
        }
    }
    
    static func buildRows(pings: [PingResult], wifiSnapshots: [WiFiSnapshot]) -> [ReportRow] {
        guard !pings.isEmpty else { return [] }
        
        var rows: [ReportRow] = []
        rows.reserveCapacity(pings.count)
        var wifiIndex = 0
        var nearest: WiFiSnapshot?
        
        for ping in pings {
            while wifiIndex < wifiSnapshots.count && wifiSnapshots[wifiIndex].timestamp <= ping.timestamp {
                nearest = wifiSnapshots[wifiIndex]
                wifiIndex += 1
            }
            rows.append(ReportRow(ping: ping, wifi: nearest))
        }
        return rows
    }
    
    static func sampledChartPings(from pings: [PingResult]) -> [PingResult] {
        guard pings.count > maxChartPoints else { return pings }
        let step = max(1, pings.count / maxChartPoints)
        return stride(from: 0, to: pings.count, by: step).map { pings[$0] }
    }
    
    private static let csvTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        return formatter
    }()
    
    private static func csvField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
