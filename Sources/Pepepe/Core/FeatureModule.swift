import Foundation

@MainActor
protocol FeatureModule: AnyObject {
    var name: String { get }
    var isRunning: Bool { get }
    
    func start()
    func stop()
    func currentStatus() -> FeatureStatus
    func dailyDigestSummary() -> String?
}

enum FeatureStatus: Comparable {
    case inactive
    case ok
    case warning
    case critical
}
