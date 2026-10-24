import Foundation
import Testing
@testable import SysMonitor

@Test func cpuCountersCrossSignedBoundaryAndWrap() throws {
    for start: UInt32 in [2_147_483_644, UInt32.max - 3] {
        var tracker = CPUTracker()
        let old = CPUCounters(user: start, system: 0, nice: 0, idle: start)
        #expect(tracker.update([old], at: 1).value == nil)
        let next = CPUCounters(user: start &+ 7, system: 0, nice: 0, idle: start &+ 14)
        let value = try #require(tracker.update([next], at: 2).value)
        #expect(abs(value - 100.0 / 3) < 0.0001)
    }
}

@Test func cpuTotalsUseWideArithmetic() {
    let zero = CPUCounters(user: 0, system: 0, nice: 0, idle: 0)
    let large = CPUCounters(user: .max, system: .max, nice: .max, idle: .max)
    #expect(large.delta(from: zero).used == UInt64(UInt32.max) * 3)
    var tracker = CPUTracker()
    _ = tracker.update([zero, zero], at: 1)
    #expect(tracker.update([large, large], at: 2).value == 75)
}

@Test func cpuRebaselinesAfterWakeCoreChangesAndFailure() {
    var tracker = CPUTracker()
    let start = CPUCounters(user: 0, system: 0, nice: 0, idle: 1)
    let end = CPUCounters(user: 0, system: 0, nice: 0, idle: 101)
    _ = tracker.update([start], at: 1)
    #expect(tracker.update([end], at: 20).value == nil)
    #expect(tracker.update([end, end], at: 21).value == nil)
    tracker.reset()
    #expect(tracker.update([end, end], at: 22).value == nil)
}

@Test func idleCPUIsARealZero() {
    var tracker = CPUTracker()
    _ = tracker.update([CPUCounters(user: 1, system: 1, nice: 0, idle: 10)], at: 1)
    #expect(tracker.update([CPUCounters(user: 1, system: 1, nice: 0, idle: 110)], at: 2).value == 0)
}

@Test func networkCountersContinueBeyondFourGiB() {
    var tracker = NetworkTracker()
    _ = tracker.update(["en0": NetworkCounters(received: 4_294_967_200, sent: 10)], at: 1)
    let result = tracker.update(["en0": NetworkCounters(received: 4_294_967_396, sent: 30)], at: 3)
    #expect(result.value?.download == 98)
    #expect(result.value?.upload == 10)
}

@Test func interfaceChangesDoNotCreateSpikesOrEraseValidTraffic() {
    var tracker = NetworkTracker()
    _ = tracker.update(["en0": NetworkCounters(received: 1_000, sent: 100)], at: 1)
    let added = tracker.update(["en0": NetworkCounters(received: 1_100, sent: 110),
                                "en1": NetworkCounters(received: 9_000_000_000, sent: 8_000_000_000)], at: 2)
    #expect(added.value?.download == 100)
    let removed = tracker.update(["en0": NetworkCounters(received: 1_200, sent: 120)], at: 3)
    #expect(removed.value?.download == 100)
    #expect(removed.value?.upload == 10)
    #expect(tracker.update(["en0": NetworkCounters(received: 10, sent: 1)], at: 4).value == nil)
    #expect(tracker.update(["en0": NetworkCounters(received: 110, sent: 11)], at: 5).value?.download == 100)
}

@Test func networkRebaselinesAfterSleepOrReadFailure() {
    var tracker = NetworkTracker()
    let counters = ["en0": NetworkCounters(received: 1_000, sent: 100)]
    _ = tracker.update(counters, at: 1)
    #expect(tracker.update(counters, at: 30).value == nil)
    tracker.reset()
    #expect(tracker.update(counters, at: 31).value == nil)
    if case .unavailable = tracker.update([:], at: 32) {} else { Issue.record("Missing interfaces must be unavailable, not zero.") }
}
