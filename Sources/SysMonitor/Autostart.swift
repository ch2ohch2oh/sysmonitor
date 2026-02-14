import Foundation
import ServiceManagement
import os
import SwiftUI

@MainActor
final class Autostart: ObservableObject {
    @Published private(set) var isEnabled: Bool = false
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.sysmonitor", category: "Autostart")
    
    static let shared = Autostart()
    
    init() {
        self.refresh()
    }
    
    func refresh() {
        self.isEnabled = SMAppService.mainApp.status == .enabled
    }
    
    func toggle(enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled { return }
                try SMAppService.mainApp.register()
            } else {
                if SMAppService.mainApp.status == .notRegistered { return }
                try SMAppService.mainApp.unregister()
            }
            logger.info("Successfully set autostart to \(enabled)")
        } catch {
            logger.error("Failed to update autostart: \(error.localizedDescription)")
        }
        self.refresh()
    }
}
