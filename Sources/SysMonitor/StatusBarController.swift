import Cocoa
import SwiftUI
import Combine

@MainActor
class StatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var popoverViewController: NSHostingController<DetailView>
    
    // Shared ViewModel
    private var viewModel = SystemUsageViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        statusBar = NSStatusBar.system
        // Use fixed length to avoid popover moving around when text width changes
        // Increased to 150 to prevent text wrapping/stacking
        statusItem = statusBar.statusItem(withLength: 150)
        
        // Pass shared viewModel to DetailView
        let detailView = DetailView(viewModel: viewModel)
        popoverViewController = NSHostingController(rootView: detailView)
        
        popover = NSPopover()
        popover.contentViewController = popoverViewController
        popover.behavior = .transient 
        
        if let button = statusItem.button {
            button.title = "Initializing..."
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Subscribe to metrics updates
        viewModel.$metrics
            .sink { [weak self] metrics in
                self?.updateStatusBar(with: metrics)
            }
            .store(in: &cancellables)
            
        // Make sure timer is running (ViewModel starts it on init, but good to be explicit/aware)
        // viewModel.startTimer() // It's already started in init
    }
    
    private func updateStatusBar(with metrics: UsageMetrics) {
        // Memory as Percentage:
        let memPercent = metrics.memoryTotalGB > 0 ? Int((metrics.memoryUsedGB / metrics.memoryTotalGB) * 100) : 0
        
        // C:%3d%% -> 3 digits. Replace spaces with Figure Space (U+2007) to match digit width.
        let figureSpace = "\u{2007}"
        let cpuText = String(format: "%3d", Int(metrics.cpuUsage)).replacingOccurrences(of: " ", with: figureSpace)
        let memText = String(format: "%3d", memPercent).replacingOccurrences(of: " ", with: figureSpace)
        
        // Only CPU and Memory
        let text = "CPU:\(cpuText)% RAM:\(memText)%"
        
        if let button = self.statusItem.button {
            // Use monospacedDigitSystemFont: letters are proportional, digits are fixed width.
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            button.title = text
        }
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
                    // Use minY (bottom edge) but offset slightly to avoid overlapping text
                    let rect = button.bounds.offsetBy(dx: 0, dy: -15)
                    popover.show(relativeTo: rect, of: button, preferredEdge: .minY)
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
}
