import Foundation
import Combine

@MainActor
final class SystemUsageViewModel: ObservableObject {
    @Published private(set) var snapshot = UsageSnapshot()
    private let sampler: any UsageSampling
    private var timer: Timer?
    private var fetchTask: Task<Void, Never>?
    private var generation = 0

    init(sampler: any UsageSampling = SystemUsage.shared, startAutomatically: Bool = true) {
        self.sampler = sampler
        if startAutomatically { startTimer() }
    }

    func startTimer() {
        stopTimer()
        fetchMetrics()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                var next = self.snapshot
                next.refreshFreshness(at: Date())
                if next.isStale != self.snapshot.isStale { self.snapshot = next }
                self.fetchMetrics()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        generation += 1
        fetchTask?.cancel()
        fetchTask = nil
    }

    func fetchMetrics() {
        guard fetchTask == nil else { return }
        let generation = generation
        let sampler = sampler
        fetchTask = Task { [weak self] in
            let metrics = await sampler.currentUsage()
            guard !Task.isCancelled, let self, self.generation == generation else { return }
            var next = self.snapshot
            next.append(metrics)
            self.snapshot = next
            self.fetchTask = nil
        }
    }
}
