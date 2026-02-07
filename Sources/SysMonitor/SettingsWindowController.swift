import Cocoa
import SwiftUI

class SettingsWindowController: NSWindowController {
    private static var _shared: SettingsWindowController?
    
    static var shared: SettingsWindowController {
        if let existing = _shared {
            return existing
        }
        let controller = SettingsWindowController()
        _shared = controller
        return controller
    }

    convenience init() {
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 80),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentViewController = hostingController
        window.center()
        window.level = .mainMenu
        
        self.init(window: window)
    }

    func showWindow() {
        if let window = self.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
