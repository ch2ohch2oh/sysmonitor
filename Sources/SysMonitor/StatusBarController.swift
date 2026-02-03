import Cocoa

@MainActor
class StatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var timer: Timer?
    
    init() {
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        
        popover = NSPopover()
        popover.contentViewController = DetailViewController()
        popover.behavior = .transient
        
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
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                }
            }
        }
    }
    
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetrics()
            }
        }
        // Fire immediately once
        updateMetrics()
    }
    
    private func updateMetrics() {
        let metrics = SystemUsage.shared.currentUsage()
        
        // Memory as Percentage: 
        let memPercent = Int((metrics.memoryUsedGB / metrics.memoryTotalGB) * 100)
        
        // C:%2d%% -> 2 digits usually sufficient (0-99). 100% will shift slightly but rare.
        let cpuText = pad(Int(metrics.cpuUsage), width: 2)
        let memText = pad(memPercent, width: 2)
        
        // Only CPU and Memory
        let text = "C:\(cpuText)% M:\(memText)%"
        
        if let button = self.statusItem.button {
            // Use monospacedDigitSystemFont for compact but stable numbers.
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            button.title = text
        }

    }
    
    private func pad(_ number: Int, width: Int) -> String {
        let s = String(number)
        if s.count < width {
            // U+2007 is Figure Space (width of a digit)
            return String(repeating: "\u{2007}", count: width - s.count) + s
        }
        return s
    }
}
