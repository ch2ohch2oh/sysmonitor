import Cocoa

@MainActor
class DetailViewController: NSViewController {
    
    // UI Elements
    private let gridView = NSGridView()
    
    // CPU
    private let cpuIcon = NSImageView(image: NSImage(systemSymbolName: "cpu", accessibilityDescription: "CPU") ?? NSImage())
    private let cpuLabel = NSTextField(labelWithString: "CPU")
    private let cpuValueLabel = NSTextField(labelWithString: "-")

    
    private let cpuHistoryChart: HistoryChartView = {
        let view = HistoryChartView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.themeColor = .systemBlue
        return view
    }()

    // GPU
    private let gpuIcon = NSImageView(image: NSImage(systemSymbolName: "cpu.fill", accessibilityDescription: "GPU") ?? NSImage())
    private let gpuLabel = NSTextField(labelWithString: "GPU")
    private let gpuValueLabel = NSTextField(labelWithString: "-")
    
    private let gpuHistoryChart: HistoryChartView = {
        let view = HistoryChartView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.themeColor = .systemPurple
        return view
    }()

    
    // Memory
    private let memoryIcon = NSImageView(image: NSImage(systemSymbolName: "memorychip", accessibilityDescription: "Memory") ?? NSImage())
    private let memoryLabel = NSTextField(labelWithString: "RAM")
    private let memoryValueLabel = NSTextField(labelWithString: "-")
    
    private let memoryHistoryChart: HistoryChartView = {
        let view = HistoryChartView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.themeColor = .systemGreen
        return view
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
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
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
        gridView.addRow(with: [cpuIcon, cpuLabel, cpuValueLabel])
        
        // CPU History Chart Row
        // We add it as a new row, and we'll merge cells later or effectively just add it
        let chartRow = gridView.addRow(with: [cpuHistoryChart])
        chartRow.mergeCells(in: NSRange(location: 0, length: 3))
        
        // Height constraint for the chart
        cpuHistoryChart.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        // GPU
        gridView.addRow(with: [gpuIcon, gpuLabel, gpuValueLabel])
        let gpuChartRow = gridView.addRow(with: [gpuHistoryChart])
        gpuChartRow.mergeCells(in: NSRange(location: 0, length: 3))
        gpuHistoryChart.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        // Memory
        gridView.addRow(with: [memoryIcon, memoryLabel, memoryValueLabel])
        
        // Memory History Chart Row
        let memChartRow = gridView.addRow(with: [memoryHistoryChart])
        memChartRow.mergeCells(in: NSRange(location: 0, length: 3))
        memoryHistoryChart.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        // Disk
        gridView.addRow(with: [diskIcon, diskLabel, diskValueLabel])
        
        let diskLevelRow = gridView.addRow(with: [diskLevel])
        diskLevelRow.mergeCells(in: NSRange(location: 0, length: 3))
        
        
        // Stabilize Column Widths
        gridView.column(at: 0).width = 18
        gridView.column(at: 1).width = 36
        // gridView.column(at: 2).width = 80 // Removed to allow left alignment of values in this column to sit near label
        // gridView.column(at: 3).width = 70 // Removed to allow disk stack to expand
    }
    
    private func setupStyling() {
        // Use a consistent font for everything to avoid "funny" look
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        
        let allLabels = [
            cpuLabel, gpuLabel, memoryLabel, diskLabel,
            cpuValueLabel, gpuValueLabel, memoryValueLabel, diskValueLabel
        ]
        
        for label in allLabels {
            label.font = font
            label.textColor = .labelColor
        }
        
        // Icons tint
        let icons = [cpuIcon, gpuIcon, memoryIcon, diskIcon]
        for icon in icons {
            icon.contentTintColor = .labelColor
            icon.symbolConfiguration = .init(scale: .small)
        }
        
        // Level Indicators
        // Level Indicators
        // diskLevel.widthAnchor.constraint(equalToConstant: 80).isActive = true
        
        // Align Labels
        diskLabel.alignment = .left 
        
        // Align Values
        cpuValueLabel.alignment = .left
        gpuValueLabel.alignment = .left
        memoryValueLabel.alignment = .left
        diskValueLabel.alignment = .left
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
        Task {
            let metrics = await SystemUsage.shared.currentUsage()
            
            await MainActor.run {
                // CPU
                cpuValueLabel.stringValue = String(format: "%.0f%%", metrics.cpuUsage)
                
                // Update History
                cpuHistoryChart.addValue(metrics.cpuUsage)
                
                // GPU
                gpuValueLabel.stringValue = String(format: "%.0f%%", metrics.gpuUsage)
                gpuHistoryChart.addValue(metrics.gpuUsage)
                
                // Memory
                let memPercent = (metrics.memoryUsedGB / metrics.memoryTotalGB) * 100.0
                memoryValueLabel.stringValue = String(format: "%.1f/%.1f GB", metrics.memoryUsedGB, metrics.memoryTotalGB)
                memoryHistoryChart.addValue(memPercent)
                
                // Disk
                diskLevel.maxValue = metrics.diskTotalGB
                diskLevel.doubleValue = metrics.diskUsedGB
                
                diskValueLabel.stringValue = String(format: "%.0f/%.0f GB", metrics.diskUsedGB, metrics.diskTotalGB)
            }
        }
    }
    


}
