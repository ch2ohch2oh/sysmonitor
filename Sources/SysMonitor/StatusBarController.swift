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
        }
        
        startTimer()
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
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
        
        // Minimalistic format:
        // C:12% M:32% D:100G N:5K
        // Or using icons? User asked for minimal standard text.
        // Let's stick to text for now as it's cleaner.
        
        // Memory as Percentage: 
        let memPercent = Int((metrics.memoryUsedGB / metrics.memoryTotalGB) * 100)
        
        // Network: smart formatting
        let netDown = formatNetwork(metrics.networkDownKBps)
        let diskRead = formatNetwork(metrics.diskReadKBps)
        let diskWrite = formatNetwork(metrics.diskWriteKBps)
        
        // Condensed format to fit in status bar:
        // C:10% M:20% R:10K W:5K ↓10K
        let text = String(format: "C:%2d%% M:%2d%% R:%@ W:%@ ↓%@", 
                          Int(metrics.cpuUsage),
                          memPercent,
                          diskRead,
                          diskWrite,
                          netDown)
        
        // Since we are likely on main thread (due to Timer or MainActor), we might not need dispatch, 
        // but if updateMetrics is called from background, this ensures safety.
        // But since this is @MainActor, updateMetrics is on main thread.
        if let button = self.statusItem.button {
            button.title = text
        }

    }
    
    private func formatNetwork(_ kbps: Double) -> String {
        if kbps > 1024 {
             return String(format: "%.1fM", kbps / 1024)
        }
        return String(format: "%.0fK", kbps)
    }
}
