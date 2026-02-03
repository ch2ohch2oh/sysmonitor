import Cocoa

@MainActor
class DetailViewController: NSViewController {
    
    // UI Elements
    private let stackView = NSStackView()
    private let cpuLabel = NSTextField(labelWithString: "CPU Usage: -")
    private let memoryLabel = NSTextField(labelWithString: "Memory: -")
    private let diskLabel = NSTextField(labelWithString: "Disk Free: -")
    private let networkLabel = NSTextField(labelWithString: "Network: -")
    
    // Timer for updates
    private var timer: Timer?
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 150))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
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
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 12
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Add arranged subviews
        let labels = [cpuLabel, memoryLabel, diskLabel, networkLabel]
        for label in labels {
            label.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            stackView.addArrangedSubview(label)
        }
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
        
        cpuLabel.stringValue = String(format: "CPU Usage: %.1f%%", metrics.cpuUsage)
        memoryLabel.stringValue = String(format: "Memory: %.1f / %.0f GB", metrics.memoryUsedGB, metrics.memoryTotalGB)
        let diskRead = formatNetwork(metrics.diskReadKBps) // Reuse formatNetwork for KB/MB logic
        let diskWrite = formatNetwork(metrics.diskWriteKBps)
        diskLabel.stringValue = String(format: "Disk: Free %.0fGB (R:%@ W:%@)", metrics.diskFreeGB, diskRead, diskWrite)
        
        let downText = formatNetwork(metrics.networkDownKBps)
        let upText = formatNetwork(metrics.networkUpKBps)
        networkLabel.stringValue = "Net: ↓\(downText) ↑\(upText)"
    }
    
    private func formatNetwork(_ kbps: Double) -> String {
        if kbps > 1024 {
             return String(format: "%.1f MB/s", kbps / 1024)
        }
        return String(format: "%.0f KB/s", kbps)
    }
}
