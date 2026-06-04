import AppKit
import SwiftUI
import CoreLocation

class AppDelegate: NSObject, NSApplicationDelegate, CLLocationManagerDelegate {
    var statusBarManager: StatusBarManager!
    var notificationManager: NotificationManager!
    var loginItemManager: LoginItemManager!
    var dailyDigestScheduler: DailyDigestScheduler!
    var pingStore: PingStore!
    var pingGuardModule: PingGuardModule!
    var locationManager: CLLocationManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        if #available(macOS 10.15, *) {
            locationManager?.requestAlwaysAuthorization()
        }
        
        notificationManager = NotificationManager()
        loginItemManager = LoginItemManager()
        
        do {
            pingStore = try PingStore()
        } catch {
            print("Failed to initialize PingStore: \(error)")
            fatalError("Database initialization failed")
        }
        
        pingGuardModule = PingGuardModule(store: pingStore, notificationManager: notificationManager)
        
        var weakManager: StatusBarManager?
        let contentView = ControlCenterView(
            pingGuard: pingGuardModule,
            loginItemManager: loginItemManager,
            store: pingStore,
            onClose: {
                weakManager?.closePanel()
            }
        )
        
        statusBarManager = StatusBarManager(
            pingGuard: pingGuardModule,
            contentView: contentView
        )
        weakManager = statusBarManager
        
        dailyDigestScheduler = DailyDigestScheduler(
            store: pingStore,
            notificationManager: notificationManager,
            modules: [pingGuardModule]
        )
    }
}
