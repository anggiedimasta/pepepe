import Foundation
import CoreWLAN

final class WiFiMonitorService: @unchecked Sendable {
    private var client = CWWiFiClient.shared()
    private var interface: CWInterface?
    private var timerQueue = DispatchQueue(label: "com.anggiedimasta.pepepe.wifitimer")
    private var timer: DispatchSourceTimer?
    private var isRunning = false
    
    var onSnapshot: (@MainActor @Sendable (WiFiSnapshot) -> Void)?
    var onNetworkChange: (@MainActor @Sendable (String?, String?) -> Void)?
    
    private var lastSSID: String?
    
    init() {
        interface = client.interface()
    }
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        
        timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer?.schedule(deadline: .now(), repeating: Constants.WiFiTracker.pollIntervalSeconds)
        timer?.setEventHandler { [weak self] in
            self?.pollWiFi()
        }
        timer?.resume()
    }
    
    func stop() {
        isRunning = false
        timer?.cancel()
        timer = nil
    }
    
    private func pollWiFi() {
        guard let interface = interface else { return }
        
        let ssid = interface.ssid()
        let bssid = interface.bssid()
        let rssi = interface.rssiValue()
        let noise = interface.noiseMeasurement()
        let txRate = interface.transmitRate()
        let channelObj = interface.wlanChannel()
        let channel = channelObj?.channelNumber ?? 0
        let bandInt = channelObj?.channelBand.rawValue ?? 0
        let interfaceName = interface.interfaceName ?? "en0"
        let phyMode = phyModeString(interface.activePHYMode())
        let securityType = securityString(interface.security())
        let clientMac = interface.hardwareAddress()
        
        var bandStr = "Unknown"
        if bandInt == 1 { bandStr = "2.4 GHz" }
        else if bandInt == 2 { bandStr = "5 GHz" }
        else if bandInt == 3 { bandStr = "6 GHz" }
        
        let networkInfo = NetworkInfoReader.read(for: interfaceName)
        
        let snapshot = WiFiSnapshot(
            timestamp: Date(),
            ssid: ssid,
            bssid: bssid,
            rssi: rssi,
            noise: noise,
            channel: channel,
            band: bandStr,
            txRate: txRate,
            interfaceName: interfaceName,
            phyMode: phyMode,
            ipv4: networkInfo.ipv4,
            ipv6: networkInfo.ipv6,
            gateway: networkInfo.gateway,
            dnsServers: networkInfo.dns,
            clientMac: clientMac,
            securityType: securityType
        )
        
        let previousSSID = self.lastSSID
        if previousSSID != ssid {
            self.lastSSID = ssid
        }
        
        let onSnapshotClosure = self.onSnapshot
        let onNetworkChangeClosure = self.onNetworkChange
        
        DispatchQueue.main.async {
            onSnapshotClosure?(snapshot)
            if previousSSID != ssid {
                onNetworkChangeClosure?(previousSSID, ssid)
            }
        }
    }
    
    private func phyModeString(_ mode: CWPHYMode) -> String {
        switch mode {
        case .modeNone: return "None"
        case .mode11a: return "802.11a"
        case .mode11b: return "802.11b"
        case .mode11g: return "802.11g"
        case .mode11n: return "802.11n"
        case .mode11ac: return "802.11ac"
        case .mode11ax: return "802.11ax"
        @unknown default: return "Unknown"
        }
    }
    
    private func securityString(_ security: CWSecurity) -> String {
        switch security {
        case .none: return "None"
        case .WEP: return "WEP"
        case .wpaPersonal: return "WPA Personal"
        case .wpaPersonalMixed: return "WPA Personal Mixed"
        case .wpa2Personal: return "WPA2 Personal"
        case .personal: return "Personal"
        case .dynamicWEP: return "Dynamic WEP"
        case .wpaEnterprise: return "WPA Enterprise"
        case .wpaEnterpriseMixed: return "WPA Enterprise Mixed"
        case .wpa2Enterprise: return "WPA2 Enterprise"
        case .enterprise: return "Enterprise"
        case .wpa3Personal: return "WPA3 Personal"
        case .wpa3Enterprise: return "WPA3 Enterprise"
        case .wpa3Transition: return "WPA3 Transition"
        case .OWE: return "OWE"
        case .oweTransition: return "OWE Transition"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }
}
