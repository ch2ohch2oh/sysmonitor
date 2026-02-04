import Cocoa

@MainActor
class StatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var timer: Timer?
    private var detailViewController: DetailViewController // Strong reference
    
    init() {
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        
        detailViewController = DetailViewController()
        
        popover = NSPopover()
        popover.contentViewController = detailViewController
        popover.behavior = .applicationDefined // Changed from .transient
        
        if let button = statusItem.button {
            button.title = "Initializing..."
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        startTimer()
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        let event = NSApp.currentEvent
        
        if event?.type == .rightMouseUp {
            let menu = NSMenu()
            let aboutItem = NSMenuItem(title: "About SysMonitor", action: #selector(showAbout(_:)), keyEquivalent: "")
            aboutItem.target = self
            menu.addItem(aboutItem)
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit SysMonitor", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            
            // Pop up the menu at the cursor location or properly anchored to button
            if let button = statusItem.button {
                 menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
            }
        } else {
            if let button = statusItem.button {
                if popover.isShown {
                    popover.performClose(sender)
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                }
            }
        }
    }
    
    @objc func showAbout(_ sender: AnyObject?) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        
        let year = Calendar.current.component(.year, from: Date())
        let copyright = "Copyright © \(year) SysMonitor. All rights reserved."
        
        let alert = NSAlert()
        alert.messageText = "About SysMonitor"
        alert.informativeText = """
        SysMonitor
        Version \(version) (Build \(build))
        
        A simple status bar application that displays your system's CPU and RAM usage.

        \(copyright)
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetrics()
            }
        }
    }
    
    private func updateMetrics() {
        Task {
            let metrics = await SystemUsage.shared.metrics
            
            // Memory as Percentage:
            var memPercent = 0
            if metrics.memoryTotalGB > 0 {
                memPercent = Int((metrics.memoryUsedGB / metrics.memoryTotalGB) * 100)
            }
            
            // C:%2d%% -> 2 digits usually sufficient (0-99). 100% will shift slightly but rare.
            let cpuText = String(format: "%2d", Int(metrics.cpuUsage))
            let memText = String(format: "%2d", memPercent)
            
            // Only CPU and Memory
            let text = "CPU:\(cpuText)% RAM:\(memText)%"
            
            if let button = self.statusItem.button {
                // Use monospacedDigitSystemFont for compact but stable numbers.
                button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
                button.title = text
            }
        }
    }
}
