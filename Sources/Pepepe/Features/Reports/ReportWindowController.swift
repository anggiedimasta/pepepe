import AppKit
import SwiftUI

@MainActor
class ReportWindowController {
    static let shared = ReportWindowController()
    private var window: NSWindow?
    
    func showWindow(store: PingStore) {
        if window == nil {
            let contentView = ReportView(store: store)
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 960, height: 780),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window?.title = "Pepepe Reports"
            window?.center()
            window?.isReleasedWhenClosed = false
            window?.contentView = NSHostingView(rootView: contentView)
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
