import SwiftUI

enum ConnectionState: Sendable {
    case stable
    case unstable
    case down
    
    var color: Color {
        switch self {
        case .stable: return .green
        case .unstable: return .yellow
        case .down: return .red
        }
    }
    
    var label: String {
        switch self {
        case .stable: return "Stable"
        case .unstable: return "Unstable"
        case .down: return "Down"
        }
    }
}
