import Foundation

@MainActor
class DailyDigestScheduler {
    private let store: PingStore
    private let notificationManager: NotificationManager
    private let modules: [FeatureModule]
    
    private var timerQueue = DispatchQueue(label: "com.anggiedimasta.pepepe.digest")
    private var timer: DispatchSourceTimer?
    
    init(store: PingStore, notificationManager: NotificationManager, modules: [FeatureModule]) {
        self.store = store
        self.notificationManager = notificationManager
        self.modules = modules
        
        scheduleDigest()
    }
    
    private func scheduleDigest() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
        components.hour = 17
        components.minute = 0
        components.second = 0
        
        var targetDate = calendar.date(from: components)!
        if targetDate <= Date() {
            targetDate = calendar.date(byAdding: .day, value: 1, to: targetDate)!
        }
        
        let interval = targetDate.timeIntervalSinceNow
        
        timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer?.schedule(deadline: .now() + interval, repeating: 86400.0)
        timer?.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.sendDigest()
            }
        }
        timer?.resume()
    }
    
    private func sendDigest() {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let rtos = (try? store.getRTOEvents(from: startOfDay, to: Date())) ?? []
        let totalDowntime = rtos.reduce(0) { $0 + $1.duration }
        
        var summary = "Today's Downtime: \(TimeFormatter.formatDuration(totalDowntime))\n"
        for module in modules {
            if let mSummary = module.dailyDigestSummary() {
                summary += mSummary + "\n"
            }
        }
        
        notificationManager.sendDailyDigest(summary: summary)
    }
}
