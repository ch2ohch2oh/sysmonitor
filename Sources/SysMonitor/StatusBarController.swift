import Cocoa
import SwiftUI
import Combine
import os

private final class MonitorPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
class StatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var window: NSPanel
    private var eventMonitor: EventMonitor?
    private let popupLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.sysmonitor", category: "PopupPosition")
    
    // Shared ViewModel
    private var viewModel = SystemUsageViewModel()
    private var cancellables = Set<AnyCancellable>()
    private var storageRowCount: Int?
    
    init() {
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        
        window = MonitorPanel(
            contentRect: NSRect(origin: .zero, size: DetailView.popupSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = .mainMenu
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.title = "SysMonitor"
        
        let detailView = makeDetailView(height: DetailView.popupSize.height)
        let hostingView = NSHostingView(rootView: detailView)
        
        window.contentView = hostingView
        
        if let button = statusItem.button {
            button.title = "Initializing..."
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            button.action = #selector(toggleWindow(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Setup Event Monitor to detect clicks outside
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self, self.window.isVisible else { return }
            if event?.type == .keyDown {
                if event?.keyCode == 53 { self.hideWindow() }
            } else if RunLoop.current.currentMode == .eventTracking {
                // Keep the popup open while its gear menu is tracking a selection.
                return
            } else if event?.window !== self.window && event?.window !== self.statusItem.button?.window {
                self.hideWindow()
            }
        }
        
        // Subscribe to metrics updates
        viewModel.$snapshot
            .sink { [weak self] snapshot in
                guard let self else { return }
                self.updateStatusBar(with: snapshot)
                let rowCount = snapshot.metrics.disks.value?.count ?? -1
                if self.storageRowCount != rowCount {
                    self.storageRowCount = rowCount
                    // @Published delivers before the model stores its new snapshot.
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.window.isVisible else { return }
                        _ = self.positionWindow()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateStatusBar(with snapshot: UsageSnapshot) {
        let modeRaw = UserDefaults.standard.string(forKey: "statusBarDisplayMode") ?? "Mini Chart"
        
        if modeRaw == "Mini Chart" {
            updateStatusBarAsChart(snapshot)
        } else {
            updateStatusBarAsText(snapshot)
        }
        let cpu = snapshot.isStale ? "Stale" : MetricFormatting.percent(snapshot.metrics.cpu.value)
        let memory = snapshot.isStale ? "Stale" : MetricFormatting.percent(snapshot.metrics.memory.value?.percentUsed)
        let summary = "SysMonitor. CPU \(cpu), RAM \(memory). Click for details, Settings, and Quit."
        statusItem.button?.toolTip = summary
        statusItem.button?.setAccessibilityLabel(summary)
    }

    private func updateStatusBarAsText(_ snapshot: UsageSnapshot) {
        // Clear image and ensure no space is reserved for it
        if statusItem.button?.image != nil {
            statusItem.button?.image = nil
        }
        statusItem.button?.imagePosition = .noImage
        
        let cpuText = alignedPercent(snapshot.isStale ? nil : snapshot.metrics.cpu.value)
        let memText = alignedPercent(snapshot.isStale ? nil : snapshot.metrics.memory.value?.percentUsed)
        
        // Only CPU and Memory
        let text = "CPU: \(cpuText) RAM: \(memText)"
        
        if let button = self.statusItem.button {
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            button.title = text
        }
    }

    private func alignedPercent(_ value: Double?) -> String {
        let text = MetricFormatting.percent(value)
        return String(repeating: "\u{2007}", count: max(4 - text.count, 0)) + text
    }
    
    private func updateStatusBarAsChart(_ snapshot: UsageSnapshot) {
        let width: CGFloat = 164
        let height: CGFloat = 22 // Standard status bar height
        let size = NSSize(width: width, height: height)
        let img = NSImage(size: size)
        
        img.lockFocus()
        
        // Draw CPU Chart (Left half)
        let cpuRect = NSRect(x: 0, y: 0, width: width / 2 - 3, height: height)
        let cpuValue = snapshot.isStale ? "—" : MetricFormatting.percent(snapshot.metrics.cpu.value)
        drawChart(in: cpuRect, history: snapshot.cpuHistory, date: snapshot.metrics.sampledAt ?? Date(), color: .white, title: "CPU", value: cpuValue)
        
        // Draw RAM Chart (Right half)
        let ramRect = NSRect(x: width / 2 + 3, y: 0, width: width / 2 - 3, height: height)
        let memoryValue = snapshot.isStale ? "—" : MetricFormatting.percent(snapshot.metrics.memory.value?.percentUsed)
        drawChart(in: ramRect, history: snapshot.memoryHistory, date: snapshot.metrics.sampledAt ?? Date(), color: .white, title: "RAM", value: memoryValue)
        
        img.unlockFocus()
        // Let macOS tint the complete image for the active menu-bar appearance.
        img.isTemplate = true
        
        if let button = statusItem.button {
            button.title = "" // Clear text
            button.image = img
            button.imagePosition = .imageOnly
        }
    }
    
    private func drawChart(in rect: NSRect, history: [HistoryPoint], date: Date, color: NSColor, title: String, value: String) {
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
        
        // Create attributed strings to measure size
        let titleStr = NSAttributedString(string: title, attributes: titleAttrs)
        let valStr = NSAttributedString(string: value, attributes: valAttrs)
        
        // Calculate text width dynamically based on actual content
        let maxTextWidth = max(titleStr.size().width, valStr.size().width)
        let textWidth = maxTextWidth + 2 // Add small padding
        let gap: CGFloat = 1
        
        // Split rect: Text (dynamic) | Chart (Rest)
        let textRect = NSRect(x: rect.minX, y: rect.minY, width: textWidth, height: rect.height)
        let chartRect = NSRect(x: rect.minX + textWidth + gap, y: rect.minY, width: rect.width - textWidth - gap, height: rect.height)
        
        let totalHeight = titleStr.size().height + valStr.size().height      
        let startY = textRect.midY - (totalHeight / 2)

        // Draw Value (Bottom)
        valStr.draw(at: NSPoint(x: textRect.maxX - valStr.size().width - 1, y: startY))
        
        // Draw Title (Top)
        titleStr.draw(at: NSPoint(x: textRect.maxX - titleStr.size().width - 1, y: startY + valStr.size().height))

        guard !history.isEmpty else { return }
        
        // Draw Path in chartRect
        let linePath = NSBezierPath()
        var previousDate: Date?
        for sample in history {
            guard let v = sample.value else { previousDate = nil; continue }
            let x = chartRect.minX + CGFloat(min(max(1 + sample.date.timeIntervalSince(date) / 60, 0), 1)) * chartRect.width
            let normalized = CGFloat(min(max(v, 0), 100)) / 100.0
            let y = chartRect.minY + normalized * (chartRect.height - 4) + 2 // Padding
            
            if let previousDate, sample.date.timeIntervalSince(previousDate) <= 2.5 {
                linePath.line(to: NSPoint(x: x, y: y))
            } else {
                linePath.move(to: NSPoint(x: x, y: y))
            }
            previousDate = sample.date
        }
        
        color.setStroke()
        linePath.lineWidth = 1.0
        linePath.stroke()
    }
    
    @objc func toggleWindow(_ sender: AnyObject?) {
        let event = NSApp.currentEvent
        
        if event?.type == .rightMouseUp {
            hideWindow()
            let menu = NSMenu()
            let activityItem = NSMenuItem(title: "Open Activity Monitor", action: #selector(openActivityMonitor(_:)), keyEquivalent: "")
            activityItem.target = self
            menu.addItem(activityItem)
            menu.addItem(.separator())
            let aboutItem = NSMenuItem(title: "About", action: #selector(showAbout(_:)), keyEquivalent: "")
            aboutItem.target = self
            menu.addItem(aboutItem)
            
            let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings(_:)), keyEquivalent: ",")
            settingsItem.target = self
            menu.addItem(settingsItem)
            
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            
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
        hideWindow()
        SettingsWindowController.shared.showWindow()
    }

    private func makeDetailView(height: CGFloat?) -> DetailView {
        DetailView(viewModel: viewModel, popupHeight: height,
                   onSettings: { [weak self] in self?.showSettings(nil) },
                   onAbout: { [weak self] in self?.showAbout(nil) },
                   onActivityMonitor: { [weak self] in self?.openActivityMonitor(nil) },
                   onQuit: { NSApp.terminate(nil) })
    }

    @objc func openActivityMonitor(_ sender: AnyObject?) {
        hideWindow()
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") else {
            showLaunchError("Activity Monitor could not be found on this Mac.")
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
            if let error {
                Task { @MainActor [weak self] in self?.showLaunchError(error.localizedDescription) }
            }
        }
    }

    private func showLaunchError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Couldn’t open Activity Monitor"
        alert.informativeText = message
        alert.runModal()
    }

    func stop() {
        hideWindow()
        viewModel.stopTimer()
    }
    
    private func positionWindow() -> Bool {
        guard let button = statusItem.button, let screen = button.window?.screen ?? NSScreen.main else { return false }
        
        let buttonRectInWindow = button.convert(button.bounds, to: nil)
        let buttonRectInScreen = button.window?.convertToScreen(buttonRectInWindow) ?? .zero
        
        let measuredSize = NSHostingView(rootView: makeDetailView(height: nil)).fittingSize
        let contentSize = CGSize(width: DetailView.popupSize.width,
                                 height: min(ceil(measuredSize.height / 4) * 4, DetailView.popupSize.height))
        let frame = PopupPlacement.frame(contentSize: contentSize, button: buttonRectInScreen, visibleFrame: screen.visibleFrame)
        if let hostingView = window.contentView as? NSHostingView<DetailView> {
            hostingView.rootView = makeDetailView(height: frame.height)
        }

        popupLogger.debug(
            "Popup placement requested: buttonWindow=\(String(describing: button.window), privacy: .public), buttonRect=\(String(describing: buttonRectInScreen), privacy: .public), contentSize=\(String(describing: contentSize), privacy: .public), frame=\(String(describing: frame), privacy: .public)"
        )
        
        window.setFrame(frame, display: true)
        return true
    }

    private func showWindow() {
        let openedWithPointer = NSApp.currentEvent?.type == .leftMouseUp
        guard positionWindow() else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async { [weak self] in
            guard let self, self.window.isVisible else { return }
            // Leave mouse-opened popups neutral; Tab can still focus the menu normally.
            if openedWithPointer { self.window.makeFirstResponder(nil) }
            self.popupLogger.debug(
                "Popup placement applied: frame=\(String(describing: self.window.frame), privacy: .public), contentFrame=\(String(describing: self.window.contentView?.frame), privacy: .public)"
            )
        }
        
        eventMonitor?.start()
    }
    
    private func hideWindow() {
        window.orderOut(nil)
        eventMonitor?.stop()
    }
    
    @objc func showAbout(_ sender: AnyObject?) {
        hideWindow()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        
        let year = Calendar.current.component(.year, from: Date())
        let copyright = "Copyright © \(year) SysMonitor. All rights reserved."
        
        let alert = NSAlert()
        alert.messageText = "About SysMonitor"
        alert.informativeText = """
        SysMonitor
        Version \(version) (Build \(build))
        
        CPU, GPU, memory, swap, network, and disk usage at a glance.

        \(copyright)
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
