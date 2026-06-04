import Foundation

@MainActor
class PingDataAggregator {
    private let store: PingStore
    private let notificationManager: NotificationManager?
    
    private var rollingWindows: [String: [PingResult]] = [:]
    private var targetStates: [String: ConnectionState] = [:]
    
    private var activeRTOEvents: [String: Int64] = [:]
    private var rtoStartTimes: [String: Date] = [:]
    private var completedDowntime: TimeInterval = 0
    
    var onDataUpdated: (@Sendable ([String: [PingResult]], [String: ConnectionState], PingSessionData) -> Void)?
    private var sessionData: PingSessionData
    
    init(store: PingStore, notificationManager: NotificationManager?, sessionId: String) {
        self.store = store
        self.notificationManager = notificationManager
        self.sessionData = PingSessionData(sessionId: sessionId, startedAt: Date())
    }
    
    func processResult(_ result: PingResult) {
        try? store.insertPingResult(result)
        
        var window = rollingWindows[result.target] ?? []
        window.append(result)
        if window.count > Constants.PingGuard.rollingWindowSize {
            window.removeFirst(window.count - Constants.PingGuard.rollingWindowSize)
        }
        rollingWindows[result.target] = window
        
        let oldState = targetStates[result.target] ?? .stable
        let newState = computeState(for: window)
        targetStates[result.target] = newState
        
        handleStateTransition(target: result.target, oldState: oldState, newState: newState, timestamp: result.timestamp)
        
        sessionData.totalPings += 1
        
        var ongoingDowntime: TimeInterval = 0
        let now = Date()
        for startTime in rtoStartTimes.values {
            ongoingDowntime += now.timeIntervalSince(startTime)
        }
        sessionData.downtimeSeconds = completedDowntime + ongoingDowntime
        
        onDataUpdated?(rollingWindows, targetStates, sessionData)
    }
    
    func stop() {
        let now = Date()
        for target in rtoStartTimes.keys {
            if let eventId = activeRTOEvents[target], let startTime = rtoStartTimes[target] {
                let duration = now.timeIntervalSince(startTime)
                try? store.updateRTOEvent(id: eventId, endedAt: now, durationSeconds: duration)
                completedDowntime += duration
            }
        }
        activeRTOEvents.removeAll()
        rtoStartTimes.removeAll()
    }
    
    private func computeState(for window: [PingResult]) -> ConnectionState {
        if window.isEmpty { return .stable }
        
        var failures = 0
        var totalLatency: Double = 0
        var latencyCount = 0
        var consecutiveTimeouts = 0
        
        for result in window {
            if !result.isSuccess {
                failures += 1
                consecutiveTimeouts += 1
            } else {
                consecutiveTimeouts = 0
                if let lat = result.latencyMs {
                    totalLatency += lat
                    latencyCount += 1
                }
            }
        }
        
        let lossRate = Double(failures) / Double(window.count)
        let avgLatency = latencyCount > 0 ? (totalLatency / Double(latencyCount)) : 0
        
        if lossRate >= Constants.PingGuard.downLossThreshold || consecutiveTimeouts >= Constants.PingGuard.consecutiveTimeoutsForDown {
            return .down
        } else if lossRate > 0 || avgLatency >= Constants.PingGuard.unstableLatencyThresholdMs {
            return .unstable
        } else {
            return .stable
        }
    }
    
    private func handleStateTransition(target: String, oldState: ConnectionState, newState: ConnectionState, timestamp: Date) {
        if oldState != .down && newState == .down {
            sessionData.rtoCount += 1
            rtoStartTimes[target] = timestamp
            if let eventId = try? store.insertRTOEvent(sessionId: sessionData.sessionId, target: target, startedAt: timestamp) {
                activeRTOEvents[target] = eventId
            }
            notificationManager?.sendConnectionDropped(target: target)
        } else if oldState == .down && newState != .down {
            if let eventId = activeRTOEvents[target], let startTime = rtoStartTimes[target] {
                let duration = timestamp.timeIntervalSince(startTime)
                try? store.updateRTOEvent(id: eventId, endedAt: timestamp, durationSeconds: duration)
                completedDowntime += duration
                notificationManager?.sendConnectionRestored(target: target, downtime: duration)
            }
            activeRTOEvents.removeValue(forKey: target)
            rtoStartTimes.removeValue(forKey: target)
        }
    }
}
