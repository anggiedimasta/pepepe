import Foundation

final class DataRetentionScheduler {
    private let store: PingStore
    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.anggiedimasta.pepepe.retention")
    
    init(store: PingStore) {
        self.store = store
        purgeExpiredData()
        scheduleDailyPurge()
    }
    
    deinit {
        timer?.cancel()
    }
    
    private func scheduleDailyPurge() {
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now() + 3600, repeating: 86_400)
        timer.setEventHandler { [weak self] in
            self?.purgeExpiredData()
        }
        timer.resume()
        self.timer = timer
    }
    
    private func purgeExpiredData() {
        let days = Constants.DataRetention.retentionDays
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return }
        store.purgeData(olderThan: cutoff)
    }
}
