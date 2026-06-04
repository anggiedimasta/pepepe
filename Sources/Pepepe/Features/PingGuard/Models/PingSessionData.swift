import Foundation

struct PingSessionData: Sendable {
    var sessionId: String
    var startedAt: Date
    var totalPings: Int = 0
    var rtoCount: Int = 0
    var downtimeSeconds: TimeInterval = 0
}
