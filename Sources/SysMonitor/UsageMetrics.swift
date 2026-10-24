import Foundation

enum Reading<Value: Sendable>: Sendable {
    case loading
    case available(Value)
    case unavailable(String)
    case failed(String)

    var value: Value? {
        if case .available(let value) = self { return value }
        return nil
    }

    var statusText: String {
        switch self {
        case .loading: return "Sampling…"
        case .available: return ""
        case .unavailable: return "Unavailable"
        case .failed: return "Read failed"
        }
    }

    var explanation: String {
        switch self {
        case .loading: return "Waiting for enough samples to calculate a reading."
        case .available: return ""
        case .unavailable(let reason), .failed(let reason): return reason
        }
    }
}

struct MemoryUsage: Sendable {
    let usedGB: Double
    let totalGB: Double
    var percentUsed: Double { totalGB > 0 ? usedGB / totalGB * 100 : 0 }
}

struct SwapUsage: Sendable {
    let usedBytes: UInt64
    var usedGB: Double { Double(usedBytes) / 1_073_741_824 }
}

struct NetworkRates: Sendable {
    let download: Double
    let upload: Double
}

struct DiskUsage: Identifiable, Hashable, Sendable {
    let id: URL
    let name: String
    let usedGB: Double
    let totalGB: Double
    var percentUsed: Double { totalGB > 0 ? usedGB / totalGB * 100 : 0 }
}

struct UsageMetrics: Sendable {
    var sampledAt: Date?
    var cpu: Reading<Double> = .loading
    var gpu: Reading<Double> = .loading
    var memory: Reading<MemoryUsage> = .loading
    var swap: Reading<SwapUsage> = .loading
    var disks: Reading<[DiskUsage]> = .loading
    var network: Reading<NetworkRates> = .loading
    var uptimeSeconds: TimeInterval = 0
}

struct HistoryPoint: Sendable {
    let date: Date
    let value: Double?
}

struct UsageSnapshot: Sendable {
    var metrics = UsageMetrics()
    var cpuHistory: [HistoryPoint] = []
    var gpuHistory: [HistoryPoint] = []
    var memoryHistory: [HistoryPoint] = []
    var swapHistory: [HistoryPoint] = []
    var downloadHistory: [HistoryPoint] = []
    var uploadHistory: [HistoryPoint] = []
    var isStale = false

    mutating func append(_ metrics: UsageMetrics) {
        guard let date = metrics.sampledAt else { return }
        self.metrics = metrics
        isStale = false
        Self.append(&cpuHistory, value: metrics.cpu.value, at: date)
        Self.append(&gpuHistory, value: metrics.gpu.value, at: date)
        Self.append(&memoryHistory, value: metrics.memory.value?.percentUsed, at: date)
        Self.append(&swapHistory, value: metrics.swap.value?.usedGB, at: date)
        Self.append(&downloadHistory, value: metrics.network.value?.download, at: date)
        Self.append(&uploadHistory, value: metrics.network.value?.upload, at: date)
    }

    mutating func refreshFreshness(at date: Date) {
        isStale = metrics.sampledAt.map { date.timeIntervalSince($0) > 5 } ?? false
    }

    private static func append(_ history: inout [HistoryPoint], value: Double?, at date: Date) {
        history.removeAll { date.timeIntervalSince($0.date) >= 60 }
        history.append(HistoryPoint(date: date, value: value))
        if history.count > 60 { history.removeFirst(history.count - 60) }
    }
}

protocol UsageSampling: Sendable {
    func currentUsage() async -> UsageMetrics
}
