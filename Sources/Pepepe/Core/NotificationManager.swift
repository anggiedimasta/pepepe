import Foundation
import UserNotifications

@MainActor
class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private var lastNotificationTimes: [String: Date] = [:]
    private let cooldown: TimeInterval = 30
    
    override init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
            }
        }
    }
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    private func shouldSend(for key: String) -> Bool {
        let now = Date()
        if let last = lastNotificationTimes[key], now.timeIntervalSince(last) < cooldown {
            return false
        }
        lastNotificationTimes[key] = now
        return true
    }
    
    private func send(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendConnectionDropped(target: String) {
        let key = "dropped-\(target)"
        guard shouldSend(for: key) else { return }
        send(id: UUID().uuidString, title: "🔴 Connection Down", body: "Target \(target) is unreachable.")
    }
    
    func sendConnectionRestored(target: String, downtime: TimeInterval) {
        let key = "restored-\(target)"
        guard shouldSend(for: key) else { return }
        send(id: UUID().uuidString, title: "🟢 Connection Restored", body: "Back online after \(TimeFormatter.formatDuration(downtime)) downtime.")
    }
    
    func sendWiFiChanged(ssid: String, rssi: Int) {
        let key = "wifi-changed"
        guard shouldSend(for: key) else { return }
        send(id: UUID().uuidString, title: "📶 WiFi Changed", body: "Connected to \(ssid) (\(rssi) dBm)")
    }
    
    func sendWiFiWeak(ssid: String, rssi: Int) {
        let key = "wifi-weak"
        guard shouldSend(for: key) else { return }
        send(id: UUID().uuidString, title: "📶 Weak Signal", body: "\(ssid) signal is poor (\(rssi) dBm)")
    }
    
    func sendDailyDigest(summary: String) {
        send(id: "daily-digest", title: "📋 Pepepe Daily Digest", body: summary)
    }
}
