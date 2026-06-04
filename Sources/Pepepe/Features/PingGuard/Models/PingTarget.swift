import Foundation

struct PingTarget: Identifiable, Codable, Sendable {
    let id: UUID
    var host: String
    var label: String
    var isEnabled: Bool
}
