import Cocoa

@MainActor
class DetailViewController: NSViewController {
    
    // UI Elements
    private let gridView = NSGridView()
    
    // CPU
    private let cpuIcon = NSImageView(image: NSImage(systemSymbolName: "cpu", accessibilityDescription: "CPU") ?? NSImage())
    private let cpuLabel = NSTextField(labelWithString: "CPU")
    private let cpuValueLabel = NSTextField(labelWithString: "-")
    private let cpuLevel: NSLevelIndicator = {
        let level = NSLevelIndicator()
        level.maxValue = 100
        level.warningValue = 80
        level.criticalValue = 90
        level.levelIndicatorStyle = .continuousCapacity
        level.controlSize = .small
        return level
    }()
    
    // Memory
    private let memoryIcon = NSImageView(image: NSImage(systemSymbolName: "memorychip", accessibilityDescription: "Memory") ?? NSImage())
    private let memoryLabel = NSTextField(labelWithString: "RAM")
    private let memoryValueLabel = NSTextField(labelWithString: "-")
    private let memoryLevel: NSLevelIndicator = {
        let level = NSLevelIndicator()
        level.levelIndicatorStyle = .continuousCapacity
        level.controlSize = .small
        return level
    }()
    
    // Disk
    private let diskIcon = NSImageView(image: NSImage(systemSymbolName: "internaldrive", accessibilityDescription: "Disk") ?? NSImage())
    private let diskLabel = NSTextField(labelWithString: "Disk")
    private let diskValueLabel = NSTextField(labelWithString: "-")
    private let diskSpeedLabel = NSTextField(labelWithString: "-")
    
    // Network
    private let netIcon = NSImageView(image: NSImage(systemSymbolName: "network", accessibilityDescription: "Network") ?? NSImage())
    private let netLabel = NSTextField(labelWithString: "Net")
    private let netValueLabel = NSTextField(labelWithString: "-")
    
    // Timer
    private var timer: Timer?
    
    override func loadView() {
        self.view = NSView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Fix transparency
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.cgColor
        
        setupUI()
        setupStyling()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        updateMetrics()
        startTimer()
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        timer?.invalidate()
    }
    
    private func setupUI() {
        // Grid setup
        gridView.translatesAutoresizingMaskIntoConstraints = false
        gridView.rowSpacing = 8
        gridView.columnSpacing = 4
        gridView.xPlacement = .leading
        gridView.rowAlignment = .none
        gridView.yPlacement = .center
        
        view.addSubview(gridView)
        
        NSLayoutConstraint.activate([
            gridView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            gridView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            gridView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            gridView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            gridView.widthAnchor.constraint(greaterThanOrEqualToConstant: 260)
        ])
        
        // Add Rows
        
        // CPU
        gridView.addRow(with: [cpuIcon, cpuLabel, cpuLevel, cpuValueLabel])
        
        // Memory
        gridView.addRow(with: [memoryIcon, memoryLabel, memoryLevel, memoryValueLabel])
        
        // Disk Space
        // Icon | "Disk" | "Free: 500 GB" (merged Col 2-3)
        gridView.addRow(with: [diskIcon, diskLabel, diskValueLabel])
        gridView.mergeCells(inHorizontalRange: NSRange(location: 2, length: 2), verticalRange: NSRange(location: 2, length: 1))
        
        // Disk IO
        // (Merged Icon) | (Merged Label) | "R: 12M W: 5M" (merged Col 2-3)
        gridView.addRow(with: [NSGridCell.emptyContentView, NSGridCell.emptyContentView, diskSpeedLabel])
        gridView.mergeCells(inHorizontalRange: NSRange(location: 2, length: 2), verticalRange: NSRange(location: 3, length: 1))
        
        // Vertical Merges for Disk Icon/Label
        gridView.mergeCells(inHorizontalRange: NSRange(location: 0, length: 1), verticalRange: NSRange(location: 2, length: 2))
        gridView.mergeCells(inHorizontalRange: NSRange(location: 1, length: 1), verticalRange: NSRange(location: 2, length: 2))
        
        // Network
        gridView.addRow(with: [netIcon, netLabel, netValueLabel])
        gridView.mergeCells(inHorizontalRange: NSRange(location: 2, length: 2), verticalRange: NSRange(location: 4, length: 1))
        
        // Stabilize Column Widths
        gridView.column(at: 0).width = 18
        gridView.column(at: 1).width = 36
        gridView.column(at: 2).width = 80
        gridView.column(at: 3).width = 70
    }
    
    private func setupStyling() {
        // Use a consistent font for everything to avoid "funny" look
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        
        let allLabels = [
            cpuLabel, memoryLabel, diskLabel, netLabel,
            cpuValueLabel, memoryValueLabel, diskValueLabel, diskSpeedLabel, netValueLabel
        ]
        
        for label in allLabels {
            label.font = font
            label.textColor = .labelColor
        }
        
        // Icons tint
        let icons = [cpuIcon, memoryIcon, diskIcon, netIcon]
        for icon in icons {
            icon.contentTintColor = .labelColor
            icon.symbolConfiguration = .init(scale: .small)
        }
        
        // Level Indicators
        cpuLevel.widthAnchor.constraint(equalToConstant: 80).isActive = true
        memoryLevel.widthAnchor.constraint(equalToConstant: 80).isActive = true
        
        // Align Disk Label to the top of the merged cell since it spans 2 rows
        diskLabel.alignment = .left 
        // Note: Vertical alignment in merged cells can be tricky.
        // Grid View aligns vertically based on rowAlignment.
        // Since we merged vertically, let's see how it looks.
        // Usually it centers vertically.
        // We might want to center the Icon/Label vertically in the 2-row span.
        // The default central alignment is effectively what we want for the group.
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetrics()
            }
        }
    }
    
    private func updateMetrics() {
        let metrics = SystemUsage.shared.currentUsage()
        
        // CPU
        cpuLevel.doubleValue = metrics.cpuUsage
        cpuValueLabel.stringValue = String(format: "%.0f%%", metrics.cpuUsage)
        
        // Memory
        memoryLevel.maxValue = metrics.memoryTotalGB
        memoryLevel.doubleValue = metrics.memoryUsedGB
        memoryValueLabel.stringValue = String(format: "%.1f GB", metrics.memoryUsedGB)
        
        // Disk
        let diskRead = formatNetwork(metrics.diskReadKBps)
        let diskWrite = formatNetwork(metrics.diskWriteKBps)
        diskSpeedLabel.stringValue = "R:\(diskRead) W:\(diskWrite)"
        diskValueLabel.stringValue = String(format: "%.0f GB Free", metrics.diskFreeGB)
        
        // Network
        let downText = formatNetwork(metrics.networkDownKBps)
        let upText = formatNetwork(metrics.networkUpKBps)
        netValueLabel.stringValue = "↓\(downText) ↑\(upText)"
    }
    
    private func formatNetwork(_ kbps: Double) -> String {
        // Padded to constant length
        // "100.0 M" -> 7 chars
        if kbps > 1024 {
             let val = kbps / 1024
             // %5.1f ensures " 12.3" or "123.4"
             return String(format: "%5.1f M", val)
        }
        return String(format: "%5.0f K", kbps)
    }
}
