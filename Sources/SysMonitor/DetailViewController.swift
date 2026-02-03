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

    private let diskLevel: NSLevelIndicator = {
        let level = NSLevelIndicator()
        level.levelIndicatorStyle = .continuousCapacity
        level.controlSize = .small
        return level
    }()
    

    
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
            gridView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])
        
        // Add Rows
        
        // CPU
        gridView.addRow(with: [cpuIcon, cpuLabel, cpuLevel, cpuValueLabel])
        
        // Memory
        gridView.addRow(with: [memoryIcon, memoryLabel, memoryLevel, memoryValueLabel])
        
        // Disk
        gridView.addRow(with: [diskIcon, diskLabel, diskLevel, diskValueLabel])
        

        
        // Stabilize Column Widths
        gridView.column(at: 0).width = 18
        gridView.column(at: 1).width = 36
        gridView.column(at: 2).width = 80
        // gridView.column(at: 3).width = 70 // Removed to allow disk stack to expand
    }
    
    private func setupStyling() {
        // Use a consistent font for everything to avoid "funny" look
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        
        let allLabels = [
            cpuLabel, memoryLabel, diskLabel,
            cpuValueLabel, memoryValueLabel, diskValueLabel
        ]
        
        for label in allLabels {
            label.font = font
            label.textColor = .labelColor
        }
        
        // Icons tint
        let icons = [cpuIcon, memoryIcon, diskIcon]
        for icon in icons {
            icon.contentTintColor = .labelColor
            icon.symbolConfiguration = .init(scale: .small)
        }
        
        // Level Indicators
        cpuLevel.widthAnchor.constraint(equalToConstant: 80).isActive = true
        memoryLevel.widthAnchor.constraint(equalToConstant: 80).isActive = true
        diskLevel.widthAnchor.constraint(equalToConstant: 80).isActive = true
        
        // Align Disk Label
        diskLabel.alignment = .left 
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
        memoryValueLabel.stringValue = String(format: "%.1f/%.1f GB", metrics.memoryUsedGB, metrics.memoryTotalGB)
        
        // Disk
        diskLevel.maxValue = metrics.diskTotalGB
        diskLevel.doubleValue = metrics.diskUsedGB
        
        diskValueLabel.stringValue = String(format: "%.0f/%.0f GB", metrics.diskUsedGB, metrics.diskTotalGB)
    }
    


}
