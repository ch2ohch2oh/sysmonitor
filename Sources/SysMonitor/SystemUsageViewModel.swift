import SwiftUI
import Combine

@MainActor
class SystemUsageViewModel: ObservableObject {
    @Published var metrics: UsageMetrics = UsageMetrics(cpuUsage: 0, perCoreUsage: [], eCoreCount: 0, pCoreCount: 0, gpuUsage: 0, memoryUsedGB: 0, memoryTotalGB: 0, diskUsedGB: 0, diskTotalGB: 0)
    
    // History Data for Charts
    @Published var cpuHistory: [Double]
    @Published var perCoreHistory: [[Double]] // Index = Core Index
    @Published var gpuHistory: [Double]
    @Published var memoryHistory: [Double]
    
    private var timer: Timer?
    private let maxHistoryPoints = 60
    
    init() {
        // Initialize with zeros so charts scroll in
        let zeros = Array(repeating: 0.0, count: maxHistoryPoints)
        cpuHistory = zeros
        gpuHistory = zeros
        memoryHistory = zeros
        perCoreHistory = [] // Will be initialized when we know core count
        
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
                
                // Update CPU History
                self.addToHistory(&self.cpuHistory, value: newMetrics.cpuUsage)
                
                // Update Per-Core History
                if self.perCoreHistory.isEmpty && !newMetrics.perCoreUsage.isEmpty {
                    // Initialize with 60 zeros for each core
                    self.perCoreHistory = newMetrics.perCoreUsage.map { _ in
                         Array(repeating: 0.0, count: self.maxHistoryPoints)
                    }
                }
                
                if !newMetrics.perCoreUsage.isEmpty {
                     if self.perCoreHistory.count != newMetrics.perCoreUsage.count {
                        // Core count mismatch / fallback re-init
                        self.perCoreHistory = newMetrics.perCoreUsage.map { _ in
                             Array(repeating: 0.0, count: self.maxHistoryPoints)
                        }
                    }
                    
                    for (index, usage) in newMetrics.perCoreUsage.enumerated() {
                        if index < self.perCoreHistory.count {
                             self.addToHistory(&self.perCoreHistory[index], value: usage)
                        }
                    }
                }
                
                // Update GPU History
                self.addToHistory(&self.gpuHistory, value: newMetrics.gpuUsage)
                
                // Update Memory History
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
