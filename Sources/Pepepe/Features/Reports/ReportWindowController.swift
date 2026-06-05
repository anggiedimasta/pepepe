import AppKit
import SwiftUI

@MainActor
class ReportWindowController {
    static let shared = ReportWindowController()
    private var window: NSWindow?
    private var hostingView: NSHostingView<ReportView>?
    private var presentationID = UUID()
    
    func showWindow(store: PingStore) {
        presentationID = UUID()
        let contentView = ReportView(store: store, presentationID: presentationID)
        
        if window == nil {
            let hostingView = NSHostingView(rootView: contentView)
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            self.hostingView = hostingView
            
            let effectView = NSVisualEffectView()
            effectView.material = .hudWindow
            effectView.blendingMode = .behindWindow
            effectView.state = .active
            effectView.translatesAutoresizingMaskIntoConstraints = false
            effectView.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: effectView.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
                hostingView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            ])
            
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1000, height: 800),
                styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window?.title = "Pepepe Reports"
            window?.titlebarAppearsTransparent = true
            window?.titleVisibility = .visible
            window?.backgroundColor = .clear
            window?.isOpaque = false
            window?.center()
            window?.isReleasedWhenClosed = false
            window?.contentView = effectView
        } else {
            hostingView?.rootView = contentView
        }
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
