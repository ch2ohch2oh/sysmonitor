import SwiftUI
import Combine

@MainActor
class SystemUsageViewModel: ObservableObject {
    @Published var metrics: UsageMetrics = UsageMetrics(cpuUsage: 0, gpuUsage: 0, memoryUsedGB: 0, memoryTotalGB: 0, diskUsedGB: 0, diskTotalGB: 0)
    
    // History Data for Charts
    @Published var cpuHistory: [Double]
    @Published var gpuHistory: [Double]
    @Published var memoryHistory: [Double]
    
    private var timer: Timer?
    private let maxHistoryPoints = 60
    
    init() {
        // Initialize with zeros so charts scroll in
        let zeros = Array(repeating: 0.0, count: 60)
        cpuHistory = zeros
        gpuHistory = zeros
        memoryHistory = zeros
        
        startTimer()
    }
    
    func startTimer() {
        timer?.invalidate()
        
        // Initial fetch
        fetchMetrics()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchMetrics()
            }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func fetchMetrics() {
        Task {
            let newMetrics = await SystemUsage.shared.currentUsage()
            
            await MainActor.run {
                self.metrics = newMetrics
                
                // Update History
                self.addToHistory(&self.cpuHistory, value: newMetrics.cpuUsage)
                self.addToHistory(&self.gpuHistory, value: newMetrics.gpuUsage)
                
                let memPercent = newMetrics.memoryTotalGB > 0 ? (newMetrics.memoryUsedGB / newMetrics.memoryTotalGB) * 100.0 : 0.0
                self.addToHistory(&self.memoryHistory, value: memPercent)
            }
        }
    }
    
    private func addToHistory(_ history: inout [Double], value: Double) {
        history.append(value)
        if history.count > maxHistoryPoints {
            history.removeFirst()
        }
    }
}
