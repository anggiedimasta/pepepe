import Foundation

struct WiFiSnapshot: Sendable {
    let timestamp: Date
    let ssid: String?
    let bssid: String?
    let rssi: Int
    let noise: Int
    let channel: Int
    let band: String
    let txRate: Double
    let interfaceName: String
    let phyMode: String
    let ipv4: String?
    let ipv6: String?
    let gateway: String?
    let dnsServers: String?
    let clientMac: String?
    let securityType: String?
    
    var snr: Int { rssi - noise }
}
