import AppKit
import SwiftUI
import Combine

@MainActor
class StatusBarManager: NSObject {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var globalEventMonitor: Any?

    private let pingGuard: PingGuardModule
    private var cancellables = Set<AnyCancellable>()

    init(pingGuard: PingGuardModule, contentView: ControlCenterView) {
        self.pingGuard = pingGuard
        super.init()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 300),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.level = .popUpMenu
        panel.isOpaque = false
        
        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 16
        effectView.layer?.masksToBounds = true
        
        let hostingView = NSHostingController(rootView: contentView).view
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: effectView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor)
        ])
        
        panel.contentView = effectView

        updateButtonIcon()

        pingGuard.$isRunning.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateButtonIcon() }
        }.store(in: &cancellables)

        pingGuard.$rollingWindows.sink { [weak self] windows in
            DispatchQueue.main.async { self?.updateButtonIcon() }
        }.store(in: &cancellables)
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if panel.isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }
    
    private func showPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        
        panel.layoutIfNeeded()
        
        let buttonFrameInScreen = buttonWindow.convertToScreen(button.frame)
        let panelSize = panel.contentView?.fittingSize ?? NSSize(width: 280, height: 300)
        
        var panelFrame = panel.frame
        panelFrame.size = panelSize
        
        let buttonMidX = buttonFrameInScreen.midX
        panelFrame.origin.x = buttonMidX - (panelSize.width / 2)
        panelFrame.origin.y = buttonFrameInScreen.minY - panelSize.height - 8
        
        panel.setFrame(panelFrame, display: true)
        panel.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let self = self, self.panel.isVisible {
                self.closePanel()
            }
        }
    }
    
    func closePanel() {
        panel.orderOut(nil)
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
    }

    private func updateButtonIcon() {
        guard let button = statusItem.button else { return }
        
        if !pingGuard.isRunning {
            if let iconImage = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
                let configuredImage = iconImage.withSymbolConfiguration(config) ?? iconImage
                configuredImage.isTemplate = true
                button.image = configuredImage
            }
            button.title = ""
            return
        }
        
        var color: NSColor = .systemGray
        var currentLatency: Double? = nil
        
        if pingGuard.isRunning {
            if let targetData = pingGuard.rollingWindows.values.first, let last = targetData.last, last.isSuccess {
                currentLatency = last.latencyMs
            }
            
            if let lat = currentLatency {
                if lat < 30 {
                    color = .systemGreen
                } else if lat < 80 {
                    color = .systemOrange
                } else {
                    color = .systemRed
                }
            } else {
                color = .systemRed
            }
        }
        
        var sparklineData: [Double?] = []
        if pingGuard.isRunning {
            if let targetData = pingGuard.rollingWindows.values.first {
                let recent = targetData.suffix(30)
                sparklineData = recent.map { $0.isSuccess ? $0.latencyMs : nil }
            }
        }
        
        let iconSize = NSSize(width: 0, height: 14)
        let sparklineWidth: CGFloat = 40
        let spacing: CGFloat = 0
        
        let totalWidth = sparklineWidth
        let size = NSSize(width: totalWidth, height: 14)
        
        let image = NSImage(size: size, flipped: false) { rect in
            
            if sparklineData.count > 1 {
                let sparkRect = NSRect(x: iconSize.width + spacing, y: 0, width: sparklineWidth, height: iconSize.height)
                let sPath = NSBezierPath()
                sPath.lineWidth = 1.0
                
                let stepX = sparklineWidth / CGFloat(sparklineData.count - 1)
                let maxVal = sparklineData.compactMap { $0 }.max() ?? 100.0
                let maxRange = max(maxVal, 50.0)
                
                var isFirst = true
                for (index, value) in sparklineData.enumerated() {
                    let x = sparkRect.minX + CGFloat(index) * stepX
                    let y: CGFloat
                    if let val = value {
                        let normalized = CGFloat(val / maxRange)
                        let bounded = min(max(normalized, 0), 1)
                        y = sparkRect.minY + (sparkRect.height * bounded)
                    } else {
                        y = sparkRect.maxY
                    }
                    
                    if isFirst {
                        sPath.move(to: NSPoint(x: x, y: y))
                        isFirst = false
                    } else {
                        sPath.line(to: NSPoint(x: x, y: y))
                    }
                    
                    if value == nil {
                        let dotRect = NSRect(x: x - 1, y: y - 1, width: 2, height: 2)
                        let dotPath = NSBezierPath(ovalIn: dotRect)
                        NSColor.systemRed.setFill()
                        dotPath.fill()
                    }
                }
                color.setStroke()
                sPath.stroke()
            }
            
            return true
        }
        
        button.image = image
        button.title = ""
    }
}
