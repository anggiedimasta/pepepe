import Foundation

enum Constants {
    enum PingGuard {
        static let pingIntervalSeconds: TimeInterval = 2.0
        static let pingTimeoutSeconds: Int = 2
        static let rollingWindowSize = 10
        static let unstableLatencyThresholdMs: Double = 100.0
        static let downLossThreshold: Double = 0.5
        static let consecutiveTimeoutsForDown = 3
    }
    
    enum WiFiTracker {
        static let pollIntervalSeconds: TimeInterval = 5.0
    }
    
    enum App {
        static let databaseName = "pepepe.sqlite"
        static let appSupportDirectoryName = "Pepepe"
        
        static var version: String {
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        }
    }
    
    enum DataRetention {
        static let retentionDays = 30
    }
}
