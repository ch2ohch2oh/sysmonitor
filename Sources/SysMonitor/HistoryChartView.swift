import Cocoa

class HistoryChartView: NSView {
    
    // Data storage (0.0 to 100.0)
    private var history: [Double] = []
    private let maxDataPoints = 60 // Keep last 60 updates
    
    // Colors
    var themeColor: NSColor = .systemBlue {
        didSet {
            chartStrokeColor = themeColor
            chartFillColor = themeColor.withAlphaComponent(0.2)
            needsDisplay = true
        }
    }
    
    private let gridColor = NSColor.gridColor.withAlphaComponent(0.2)
    private var chartFillColor = NSColor.systemBlue.withAlphaComponent(0.2)
    private var chartStrokeColor = NSColor.systemBlue
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        wantsLayer = true
        // Darker background for the chart area
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = 4
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.borderWidth = 1
        
        // Pre-fill with empty data
        history = [Double](repeating: 0, count: maxDataPoints)
    }
    
    func addValue(_ value: Double) {
        history.append(value)
        if history.count > maxDataPoints {
            history.removeFirst()
        }
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // 1. Draw Grid
        drawGrid()
        
        // 2. Draw Graph
        if history.isEmpty { return }
        drawChart()
    }
    
    private func drawGrid() {
        gridColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.0
        
        // Horizontal middle line (50%)
        let midY = bounds.height / 2
        path.move(to: NSPoint(x: 0, y: midY))
        path.line(to: NSPoint(x: bounds.width, y: midY))
        
        // Vertical lines (every ~10 points)
        for i in 1...3 {
            let x = bounds.width * CGFloat(i) / 4.0
            path.move(to: NSPoint(x: x, y: 0))
            path.line(to: NSPoint(x: x, y: bounds.height))
        }
        
        path.stroke()
    }
    
    private func drawChart() {
        guard !history.isEmpty else { return }
        
        let width = bounds.width
        let height = bounds.height
        let stepX = width / CGFloat(maxDataPoints - 1)
        
        var points: [NSPoint] = []
        for (index, value) in history.enumerated() {
            let x = CGFloat(index) * stepX
            
            let clampedValue = max(0, min(100, value))
            let y = (CGFloat(clampedValue) / 100.0) * height
            
            points.append(NSPoint(x: x, y: y))
        }
        
        guard let firstPoint = points.first else { return }
        
        // --- Draw Fill ---
        let fillPath = NSBezierPath()
        fillPath.move(to: NSPoint(x: 0, y: 0)) // Start at bottom-left
        fillPath.line(to: firstPoint)
        
        for p in points.dropFirst() {
            fillPath.line(to: p)
        }
        
        if let lastPoint = points.last {
             fillPath.line(to: NSPoint(x: lastPoint.x, y: 0))
        }
        // No need to close, we are connecting to the bottom edge.
        
        chartFillColor.setFill()
        fillPath.fill()
        
        // --- Draw Stroke ---
        let strokePath = NSBezierPath()
        strokePath.move(to: firstPoint)
        for p in points.dropFirst() {
            strokePath.line(to: p)
        }
        
        chartStrokeColor.setStroke()
        strokePath.lineWidth = 1.5
        strokePath.stroke()
    }
}
