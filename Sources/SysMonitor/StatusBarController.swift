import Cocoa
import SwiftUI
import Combine

@MainActor
class StatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var window: NSPanel
    private var eventMonitor: EventMonitor?
    
    // Shared ViewModel
    private var viewModel = SystemUsageViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        statusBar = NSStatusBar.system
        // Use fixed length to avoid popover moving around when text width changes
        // Increased to 150 to prevent text wrapping/stacking
        statusItem = statusBar.statusItem(withLength: 150)
        
        // Setup Window (NSPanel)
        // StyleMask .borderless removes the title bar and standard window frame => "No Arrow"
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 300), // Height might vary, SwiftView will dictate
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = .mainMenu
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        
        // Pass shared viewModel to DetailView
        let detailView = DetailView(viewModel: viewModel)
        // Use NSHostingView directly for the window content
        let hostingView = NSHostingView(rootView: detailView)
        // hostingView.translatesAutoresizingMaskIntoConstraints = false 
        // Autoresizing is simpler for fixed size content.
        
        window.contentView = hostingView
        
        if let button = statusItem.button {
            button.title = "Initializing..."
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            button.action = #selector(toggleWindow(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Setup Event Monitor to detect clicks outside
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let strongSelf = self, strongSelf.window.isVisible {
                strongSelf.hideWindow()
            }
        }
        
        // Subscribe to metrics updates
        viewModel.$metrics
            .sink { [weak self] metrics in
                self?.updateStatusBar(with: metrics)
            }
            .store(in: &cancellables)
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
    
    @objc func toggleWindow(_ sender: AnyObject?) {
        let event = NSApp.currentEvent
        
        if event?.type == .rightMouseUp {
            let menu = NSMenu()
            let aboutItem = NSMenuItem(title: "About SysMonitor", action: #selector(showAbout(_:)), keyEquivalent: "")
            aboutItem.target = self
            menu.addItem(aboutItem)
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit SysMonitor", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            
            if let button = statusItem.button {
                 menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
            }
        } else {
            if window.isVisible {
                hideWindow()
            } else {
                showWindow()
            }
        }
    }
    
    private func showWindow() {
        guard let button = statusItem.button else { return }
        
        // Calculate position
        // Translate button coordinate to screen coordinates
        // Note: 'button.window' is the status bar window.
        let buttonRectInWindow = button.convert(button.bounds, to: nil)
        let buttonRectInScreen = button.window?.convertToScreen(buttonRectInWindow) ?? .zero
        
        // Get content size. Wait, NSHostingView should size itself?
        // We forced DetailView frame(width: 220).
        // Let's ask the hosting view for its fitting size.
        let contentSize = window.contentView?.fittingSize ?? CGSize(width: 220, height: 300)
        
        // Center X relative to button
        let x = buttonRectInScreen.origin.x + (buttonRectInScreen.width / 2) - (contentSize.width / 2)
        
        // Align Y below button
        // Screen Y is 0 at bottom. Button Y is top.
        // buttonRectInScreen.origin.y is the bottom-left corner of the button in screen coords.
        // We want the window top to be slightly below button bottom.
        let y = buttonRectInScreen.origin.y - contentSize.height - 5 // 5px gap
        
        let frame = NSRect(x: x, y: y, width: contentSize.width, height: contentSize.height)
        
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        eventMonitor?.start()
    }
    
    private func hideWindow() {
        window.orderOut(nil)
        eventMonitor?.stop()
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
