import SwiftUI

struct ControlCenterView: View {
    @ObservedObject var pingGuard: PingGuardModule
    @ObservedObject var loginItemManager: LoginItemManager
    let store: PingStore
    var onClose: (() -> Void)?
    
    @State private var isPingGuardHovering = false
    @State private var isLoginItemHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                Button(action: {
                    if pingGuard.isRunning {
                        pingGuard.stop()
                    } else {
                        pingGuard.start()
                    }
                }) {
                    HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(pingGuard.isRunning ? Color.blue : Color.primary.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "waveform.path.ecg")
                            .foregroundColor(pingGuard.isRunning ? .white : .primary.opacity(0.6))
                            .font(.system(size: 16, weight: .semibold))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        if pingGuard.isRunning, let snap = pingGuard.latestWiFiSnapshot {
                            Text(snap.ssid ?? "Wi-Fi")
                                .font(.system(size: 13, weight: .bold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Text("\(snap.rssi) dBm")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        } else {
                            Text("PingGuard")
                                .font(.system(size: 13, weight: .bold))
                            if pingGuard.isRunning {
                                Text("Monitoring Active")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Inactive")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer()
                    }
                    .padding(12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(isPingGuardHovering ? Color.primary.opacity(0.05) : Color.clear)
                .onHover { isPingGuardHovering = $0 }

                if pingGuard.isRunning {
                    Divider()
                    PingChartView(pingGuard: pingGuard)
                        .frame(height: 110)
                        .padding(12)
                }
            }
            .padding(.top, 4)

            Divider()

            VStack(spacing: 0) {
                Button(action: {
                    loginItemManager.toggle()
                }) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(loginItemManager.isEnabled ? Color.blue : Color.primary.opacity(0.1))
                                .frame(width: 28, height: 28)
                            Image(systemName: "bolt.fill")
                                .foregroundColor(loginItemManager.isEnabled ? .white : .primary.opacity(0.8))
                                .font(.system(size: 12))
                        }
                        Text("Auto-start at Login")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        if loginItemManager.isEnabled {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                                .font(.system(size: 13, weight: .bold))
                        }
                    }
                    .padding(12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(isLoginItemHovering ? Color.primary.opacity(0.05) : Color.clear)
                .onHover { isLoginItemHovering = $0 }

                Divider()

                HoverableRow(icon: "doc.text.fill", title: "Reports...") {
                    ReportWindowController.shared.showWindow(store: store)
                    onClose?()
                }
            }
            .padding(.vertical, 4)

            Divider()

            VStack(spacing: 0) {
                HoverableRow(icon: "power", title: "Quit Pepepe", isDestructive: true) {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.bottom, 4)
        }
        .frame(width: 280)
        .fixedSize(horizontal: true, vertical: true)
    }
}

struct HoverableRow: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isDestructive ? Color.red.opacity(0.15) : Color.primary.opacity(0.1))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .foregroundColor(isDestructive ? .red : .primary.opacity(0.8))
                        .font(.system(size: 12, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isDestructive ? .red : .primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        .onHover { isHovering = $0 }
    }
}
