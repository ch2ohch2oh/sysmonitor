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
        // Read setting
        let modeRaw = UserDefaults.standard.string(forKey: "statusBarDisplayMode") ?? "Text"
        // If DisplayMode is internal to SettingsView.swift but top-level, we can access it. 
        // If not found, default to text.
        
        if modeRaw == "Mini Chart" {
            updateStatusBarAsChart(metrics)
        } else {
            updateStatusBarAsText(metrics)
        }
    }

    private func updateStatusBarAsText(_ metrics: UsageMetrics) {
        // Clear image if any
        if statusItem.button?.image != nil {
            statusItem.button?.image = nil
        }
        
        // Memory as Percentage:
        let memPercent = metrics.memoryTotalGB > 0 ? Int((metrics.memoryUsedGB / metrics.memoryTotalGB) * 100) : 0
        
        // C:%3d%% -> 3 digits. Replace spaces with Figure Space (U+2007) to match digit width.
        let figureSpace = "\u{2007}"
        let cpuText = String(format: "%3d", Int(metrics.cpuUsage)).replacingOccurrences(of: " ", with: figureSpace)
        let memText = String(format: "%3d", memPercent).replacingOccurrences(of: " ", with: figureSpace)
        
        // Only CPU and Memory
        let text = "CPU:\(cpuText)% RAM:\(memText)%"
        
        if let button = self.statusItem.button {
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            button.title = text
        }
    }
    
    private func updateStatusBarAsChart(_ metrics: UsageMetrics) {
        let width: CGFloat = 150 // Match statusItem length
        let height: CGFloat = 22 // Standard status bar height
        let size = NSSize(width: width, height: height)
        let img = NSImage(size: size)
        
        img.lockFocus()
        
        // Draw CPU Chart (Left half)
        let cpuRect = NSRect(x: 0, y: 0, width: width / 2 - 2, height: height)
        let cpuVal = Int(metrics.cpuUsage)
        drawChart(in: cpuRect, history: viewModel.cpuHistory, color: .white, title: "CPU", value: "\(cpuVal)%")
        
        // Draw RAM Chart (Right half)
        let ramRect = NSRect(x: width / 2 + 2, y: 0, width: width / 2 - 2, height: height)
        let memPercent = metrics.memoryTotalGB > 0 ? Int((metrics.memoryUsedGB / metrics.memoryTotalGB) * 100) : 0
        drawChart(in: ramRect, history: viewModel.memoryHistory, color: .white, title: "RAM", value: "\(memPercent)%")
        
        img.unlockFocus()
        
        if let button = statusItem.button {
            button.title = "" // Clear text
            button.image = img
            button.imagePosition = .imageOnly
        }
    }
    
    private func drawChart(in rect: NSRect, history: [Double], color: NSColor, title: String, value: String) {
        // Split rect: Text (35px) | Chart (Rest)
        let textWidth: CGFloat = 35
        let textRect = NSRect(x: rect.minX, y: rect.minY, width: textWidth, height: rect.height)
        let chartRect = NSRect(x: rect.minX + textWidth, y: rect.minY, width: rect.width - textWidth, height: rect.height)
        
        // Draw Text
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]
        
        let valAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]
        
        // Draw Title (Top) - manually positioned
        let titleStr = NSAttributedString(string: title, attributes: titleAttrs)
        let valStr = NSAttributedString(string: value, attributes: valAttrs)
        
        let totalHeight = titleStr.size().height + valStr.size().height      
        let startY = textRect.midY - (totalHeight / 2)

        // Draw Value (Bottom)
        valStr.draw(at: NSPoint(x: textRect.maxX - valStr.size().width - 2, y: startY))
        
        // Draw Title (Top)
        titleStr.draw(at: NSPoint(x: textRect.maxX - titleStr.size().width - 2, y: startY + valStr.size().height))

        guard !history.isEmpty else { return }
        
        // Draw Path in chartRect
        let linePath = NSBezierPath()
        let stepX = chartRect.width / CGFloat(max(history.count - 1, 1))
        
        for (i, v) in history.enumerated() {
            let x = chartRect.minX + CGFloat(i) * stepX
            let normalized = CGFloat(min(max(v, 0), 100)) / 100.0
            let y = chartRect.minY + normalized * (chartRect.height - 4) + 2 // Padding
            
            if i == 0 {
                linePath.move(to: NSPoint(x: x, y: y))
            } else {
                linePath.line(to: NSPoint(x: x, y: y))
            }
        }
        
        color.setStroke()
        linePath.lineWidth = 1.0
        linePath.stroke()
    }
    
    @objc func toggleWindow(_ sender: AnyObject?) {
        let event = NSApp.currentEvent
        
        if event?.type == .rightMouseUp {
            let menu = NSMenu()
            let aboutItem = NSMenuItem(title: "About SysMonitor", action: #selector(showAbout(_:)), keyEquivalent: "")
            aboutItem.target = self
            menu.addItem(aboutItem)
            
            let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings(_:)), keyEquivalent: ",")
            settingsItem.target = self
            menu.addItem(settingsItem)
            
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
    
    @objc func showSettings(_ sender: AnyObject?) {
        SettingsWindowController.shared.showWindow()
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
