import Foundation
import Testing
import Combine
@testable import SysMonitor

@Test func historiesContainOnlyRealSamplesAndLeaveFailureGaps() {
    var snapshot = UsageSnapshot()
    #expect(snapshot.cpuHistory.isEmpty)
    snapshot.append(UsageMetrics(sampledAt: Date(timeIntervalSince1970: 100), cpu: .available(0)))
    #expect(snapshot.cpuHistory.count == 1)
    #expect(snapshot.cpuHistory.last?.value == 0)
    snapshot.append(UsageMetrics(sampledAt: Date(timeIntervalSince1970: 101), cpu: .failed("Read failed")))
    #expect(snapshot.cpuHistory.count == 2)
    #expect(snapshot.cpuHistory.last?.value == nil)
    if case .failed = snapshot.metrics.cpu {} else { Issue.record("Preserve the read failure.") }
}

@Test func historyIsBoundedByTimeAndCount() {
    var snapshot = UsageSnapshot()
    for time in 0..<100 {
        snapshot.append(UsageMetrics(sampledAt: Date(timeIntervalSince1970: Double(time)), cpu: .available(Double(time))))
    }
    #expect(snapshot.cpuHistory.count == 60)
    #expect(snapshot.cpuHistory.first?.date == Date(timeIntervalSince1970: 40))
    snapshot.append(UsageMetrics(sampledAt: Date(timeIntervalSince1970: 200), cpu: .available(10)))
    #expect(snapshot.cpuHistory.count == 1)
}

@Test func swapHistoryUsesGiBAndPreservesZeroAndIndependentFailures() {
    var snapshot = UsageSnapshot()
    let memory = MemoryUsage(usedGB: 12, totalGB: 16)
    snapshot.append(UsageMetrics(sampledAt: Date(timeIntervalSince1970: 100),
                                 memory: .available(memory), swap: .available(SwapUsage(usedBytes: 0))))
    #expect(snapshot.memoryHistory.last?.value == 75)
    #expect(snapshot.swapHistory.last?.value == 0)

    // A value over 4 GiB exercises the full-width kernel counter, independently of RAM's percentage scale.
    snapshot.append(UsageMetrics(sampledAt: Date(timeIntervalSince1970: 101),
                                 memory: .failed("Memory read failed"),
                                 swap: .available(SwapUsage(usedBytes: 9 * 1_073_741_824))))
    #expect(snapshot.memoryHistory.last?.value == nil)
    #expect(snapshot.swapHistory.last?.value == 9)

    snapshot.append(UsageMetrics(sampledAt: Date(timeIntervalSince1970: 102),
                                 memory: .available(memory), swap: .failed("Swap read failed")))
    #expect(snapshot.metrics.memory.value?.percentUsed == 75)
    #expect(snapshot.memoryHistory.last?.value == 75)
    #expect(snapshot.swapHistory.last?.value == nil)

    snapshot.append(UsageMetrics(sampledAt: Date(timeIntervalSince1970: 163),
                                 swap: .available(SwapUsage(usedBytes: 536_870_912))))
    #expect(snapshot.swapHistory.count == 1)
    #expect(snapshot.swapHistory.last?.value == 0.5)
}

@Test func staleReadingsAreMarkedUntilANewSampleArrives() {
    var snapshot = UsageSnapshot()
    snapshot.append(UsageMetrics(sampledAt: Date(timeIntervalSince1970: 100), cpu: .available(42)))
    snapshot.refreshFreshness(at: Date(timeIntervalSince1970: 106))
    #expect(snapshot.isStale)
    #expect(snapshot.metrics.cpu.value == 42)
    snapshot.append(UsageMetrics(sampledAt: Date(timeIntervalSince1970: 107), cpu: .available(20)))
    #expect(!snapshot.isStale)
}

private actor ControlledSampler: UsageSampling {
    private var waiting: CheckedContinuation<UsageMetrics, Never>?
    private var started: CheckedContinuation<Void, Never>?
    private var hasStarted = false
    private(set) var calls = 0

    func currentUsage() async -> UsageMetrics {
        calls += 1
        hasStarted = true
        started?.resume()
        started = nil
        return await withCheckedContinuation { waiting = $0 }
    }

    func waitUntilStarted() async {
        if hasStarted { return }
        await withCheckedContinuation { started = $0 }
    }

    func complete(_ metrics: UsageMetrics) {
        waiting?.resume(returning: metrics)
        waiting = nil
    }
}

@Test(.timeLimit(.minutes(1))) @MainActor
func viewModelPublishesMatchingMetricsAndHistoryWithoutOverlappingFetches() async {
    let sampler = ControlledSampler()
    let model = SystemUsageViewModel(sampler: sampler, startAutomatically: false)
    var subscription: AnyCancellable?
    let updates = AsyncStream<UsageSnapshot> { continuation in
        subscription = model.$snapshot.dropFirst().sink { continuation.yield($0) }
    }
    var iterator = updates.makeAsyncIterator()
    model.fetchMetrics()
    model.fetchMetrics()
    await sampler.waitUntilStarted()
    #expect(await sampler.calls == 1)
    await sampler.complete(UsageMetrics(sampledAt: Date(), cpu: .available(37)))
    let update = await iterator.next()
    #expect(update?.metrics.cpu.value == 37)
    #expect(update?.cpuHistory.last?.value == 37)
    subscription?.cancel()
    model.stopTimer()
}
