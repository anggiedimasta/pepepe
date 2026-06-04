import Foundation

struct PingResult: Sendable {
    let id: UUID
    let sessionId: String
    let target: String
    let timestamp: Date
    let latencyMs: Double?
    let isSuccess: Bool
    let errorType: PingErrorType
}
