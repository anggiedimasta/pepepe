import Foundation
import Combine

@MainActor
class PingGuardModule: FeatureModule, ObservableObject {
    var name: String = "PingGuard"
    @Published var isRunning: Bool = false
    
    @Published var rollingWindows: [String: [PingResult]] = [:]
    @Published var targetStates: [String: ConnectionState] = [:]
    @Published var sessionData: PingSessionData?
    
    @Published var latestWiFiSnapshot: WiFiSnapshot?
    
    private let store: PingStore
    private let notificationManager: NotificationManager
    
    private var pingService: PingService?
    private var aggregator: PingDataAggregator?
    private var wifiService: WiFiMonitorService?
    
    init(store: PingStore, notificationManager: NotificationManager) {
        self.store = store
        self.notificationManager = notificationManager
    }
    
    func start() {
        guard !isRunning else { return }
        let sessionId = try? store.createSession(target: "Multi")
        guard let sId = sessionId else { return }
        
        let service = PingService()
        service.setTargets([
            PingTarget(id: UUID(), host: "1.1.1.1", label: "Cloudflare", isEnabled: true),
            PingTarget(id: UUID(), host: "8.8.8.8", label: "Google", isEnabled: true)
        ])
        
        let agg = PingDataAggregator(store: store, notificationManager: notificationManager, sessionId: sId)
        agg.onDataUpdated = { [weak self] windows, states, data in
            DispatchQueue.main.async {
                self?.rollingWindows = windows
                self?.targetStates = states
                self?.sessionData = data
            }
        }
        
        service.onResult = { result in
            agg.processResult(result)
        }
        
        service.start(sessionId: sId)
        self.pingService = service
        self.aggregator = agg
        
        let wSvc = WiFiMonitorService()
        wSvc.onSnapshot = { [weak self] snapshot in
            DispatchQueue.main.async {
                self?.latestWiFiSnapshot = snapshot
            }
            try? self?.store.insertWiFiSnapshot(snapshot)
            if snapshot.rssi < -70 {
                self?.notificationManager.sendWiFiWeak(ssid: snapshot.ssid ?? "Wi-Fi", rssi: snapshot.rssi)
            }
        }
        wSvc.onNetworkChange = { [weak self] old, new in
            if let n = new {
                self?.notificationManager.sendWiFiChanged(ssid: n, rssi: self?.latestWiFiSnapshot?.rssi ?? 0)
            }
        }
        wSvc.start()
        self.wifiService = wSvc
        
        self.isRunning = true
    }
    
    func stop() {
        guard isRunning else { return }
        pingService?.stop()
        aggregator?.stop()
        wifiService?.stop()
        
        if let sId = sessionData?.sessionId {
            try? store.endSession(id: sId)
        }
        
        pingService = nil
        aggregator = nil
        wifiService = nil
        
        self.isRunning = false
        self.rollingWindows.removeAll()
        self.targetStates.removeAll()
        self.sessionData = nil
        self.latestWiFiSnapshot = nil
    }
    
    func currentStatus() -> FeatureStatus {
        guard isRunning else { return .inactive }
        
        if targetStates.values.contains(.down) { return .critical }
        if targetStates.values.contains(.unstable) { return .warning }
        
        if let snap = latestWiFiSnapshot {
            if snap.rssi < -70 { return .critical }
            if snap.rssi < -60 { return .warning }
        }
        
        return .ok
    }
    
    func dailyDigestSummary() -> String? {
        return nil
    }
}
