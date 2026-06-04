import Foundation
import ServiceManagement
import Combine

@MainActor
class LoginItemManager: ObservableObject {
    @Published var isEnabled: Bool = false
    
    init() {
        if #available(macOS 13.0, *) {
            isEnabled = SMAppService.mainApp.status == .enabled
        }
    }
    
    func toggle() {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    self.isEnabled = false
                } else {
                    try SMAppService.mainApp.register()
                    self.isEnabled = true
                }
            } catch {
                print("Failed to toggle login item: \(error)")
            }
        }
    }
}
