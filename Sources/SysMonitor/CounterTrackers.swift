import Foundation

struct CPUCounters: Sendable {
    let user: UInt32
    let system: UInt32
    let nice: UInt32
    let idle: UInt32

    func delta(from previous: CPUCounters) -> (used: UInt64, total: UInt64) {
        let used = UInt64(user &- previous.user) + UInt64(system &- previous.system)
            + UInt64(nice &- previous.nice)
        return (used, used + UInt64(idle &- previous.idle))
    }
}

struct CPUTracker {
    private var previous: (counters: [CPUCounters], time: TimeInterval)?
    mutating func reset() { previous = nil }

    mutating func update(_ counters: [CPUCounters], at time: TimeInterval) -> Reading<Double> {
        defer { previous = (counters, time) }
        guard let previous, previous.counters.count == counters.count,
              time > previous.time, time - previous.time <= 5, !counters.isEmpty else { return .loading }
        var used: UInt64 = 0
        var total: UInt64 = 0
        for (current, old) in zip(counters, previous.counters) {
            let delta = current.delta(from: old)
            used += delta.used
            total += delta.total
        }
        guard total > 0 else { return .loading }
        return .available(Double(used) / Double(total) * 100)
    }
}

struct NetworkCounters: Sendable {
    let received: UInt64
    let sent: UInt64
}

struct NetworkTracker {
    private var previous: (counters: [String: NetworkCounters], time: TimeInterval)?
    mutating func reset() { previous = nil }

    mutating func update(_ counters: [String: NetworkCounters], at time: TimeInterval) -> Reading<NetworkRates> {
        defer { previous = (counters, time) }
        guard !counters.isEmpty else { return .unavailable("No active Wi-Fi or Ethernet interface.") }
        guard let previous, time > previous.time, time - previous.time <= 5 else { return .loading }
        var received: Double = 0
        var sent: Double = 0
        var matched = false
        for (name, current) in counters {
            guard let old = previous.counters[name], current.received >= old.received,
                  current.sent >= old.sent else { continue }
            matched = true
            received += Double(current.received - old.received)
            sent += Double(current.sent - old.sent)
        }
        guard matched else { return .loading }
        let elapsed = time - previous.time
        return .available(NetworkRates(download: received / elapsed, upload: sent / elapsed))
    }
}
