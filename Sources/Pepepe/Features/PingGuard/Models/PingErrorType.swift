import Foundation

enum PingErrorType: String, Sendable {
    case none = ""
    case timeout = "timeout"
    case hostUnreachable = "host_unreachable"
    case networkUnreachable = "network_unreachable"
    case sendFailed = "send_failed"
    case unknown = "unknown"
    
    static func parse(from output: String, exitCode: Int32) -> PingErrorType {
        guard exitCode != 0 else { return .none }
        
        if output.contains("Request timeout") || output.contains("timed out") {
            return .timeout
        }
        if output.contains("No route to host") {
            return .hostUnreachable
        }
        if output.contains("Network is unreachable") {
            return .networkUnreachable
        }
        if output.contains("sendto") || output.contains("sendmsg") {
            return .sendFailed
        }
        return .unknown
    }
}
