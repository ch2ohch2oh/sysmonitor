import Foundation
import Darwin
import IOKit

actor SystemUsage: UsageSampling {
    static let shared = SystemUsage()
    private var cpuTracker = CPUTracker()
    private var networkTracker = NetworkTracker()
    private var cachedDisks: Reading<[DiskUsage]> = .loading
    private var lastDiskSample: TimeInterval = -.infinity

    func currentUsage() async -> UsageMetrics {
        let time = ProcessInfo.processInfo.systemUptime
        if time - lastDiskSample >= 15 {
            cachedDisks = getDisks()
            lastDiskSample = time
        }
        return UsageMetrics(
            sampledAt: Date(), cpu: getCPU(at: time), gpu: getGPU(), memory: getMemory(), swap: getSwap(),
            disks: cachedDisks, network: getNetworkRates(at: time), uptimeSeconds: time
        )
    }

    private func getCPU(at time: TimeInterval) -> Reading<Double> {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let result = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount)
        guard result == KERN_SUCCESS, let info else {
            cpuTracker.reset()
            return .failed("CPU statistics could not be read (Mach error \(result)).")
        }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info),
                          vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size))
        }
        guard Int(infoCount) >= Int(cpuCount) * Int(CPU_STATE_MAX) else {
            cpuTracker.reset()
            return .failed("CPU statistics were incomplete.")
        }
        let counters = (0..<Int(cpuCount)).map { index in
            let offset = index * Int(CPU_STATE_MAX)
            return CPUCounters(
                user: UInt32(bitPattern: info[offset + Int(CPU_STATE_USER)]),
                system: UInt32(bitPattern: info[offset + Int(CPU_STATE_SYSTEM)]),
                nice: UInt32(bitPattern: info[offset + Int(CPU_STATE_NICE)]),
                idle: UInt32(bitPattern: info[offset + Int(CPU_STATE_IDLE)])
            )
        }
        return cpuTracker.update(counters, at: time)
    }

    private func getGPU() -> Reading<Double> {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator)
        guard result == KERN_SUCCESS else { return .failed("GPU statistics could not be read.") }
        defer { IOObjectRelease(iterator) }
        var values: [Double] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let stats = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString,
                                                          kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
                for key in ["Device Utilization %", "GPU Activity(%)", "Utilization %"] {
                    if let value = stats[key] as? NSNumber, value.doubleValue.isFinite {
                        values.append(min(max(value.doubleValue, 0), 100))
                        break
                    }
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        guard !values.isEmpty else { return .unavailable("This Mac does not expose a supported GPU utilization counter.") }
        return .available(values.reduce(0, +) / Double(values.count))
    }

    private func getMemory() -> Reading<MemoryUsage> {
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var info = vm_statistics64_data_t()
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        let pageSize = sysconf(_SC_PAGESIZE)
        guard result == KERN_SUCCESS, pageSize > 0 else { return .failed("Memory statistics could not be read.") }
        let usedPages = UInt64(info.active_count) + UInt64(info.wire_count) + UInt64(info.compressor_page_count)
        let total = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        return .available(MemoryUsage(usedGB: min(Double(usedPages) * Double(pageSize) / 1_073_741_824, total),
                                      totalGB: total))
    }

    private func getSwap() -> Reading<SwapUsage> {
        var info = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &info, &size, nil, 0) == 0,
              size == MemoryLayout<xsw_usage>.size else {
            return .failed("Swap usage could not be read.")
        }
        return .available(SwapUsage(usedBytes: info.xsu_used))
    }

    private func getDisks() -> Reading<[DiskUsage]> {
        let keys: Set<URLResourceKey> = [.volumeNameKey, .volumeIsLocalKey, .volumeIsReadOnlyKey,
                                        .volumeAvailableCapacityKey, .volumeTotalCapacityKey]
        guard let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: Array(keys),
                                                               options: [.skipHiddenVolumes]) else {
            return .failed("Mounted disks could not be enumerated.")
        }
        var readFailed = false
        let disks: [DiskUsage] = urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: keys) else {
                readFailed = true
                return nil
            }
            guard values.volumeIsLocal == true, values.volumeIsReadOnly == false else { return nil }
            guard let available = values.volumeAvailableCapacity, let total = values.volumeTotalCapacity,
                  total > 0 else { readFailed = true; return nil }
            return DiskUsage(id: url, name: values.volumeName ?? url.lastPathComponent,
                             usedGB: Double(max(total - available, 0)) / 1_073_741_824,
                             totalGB: Double(total) / 1_073_741_824)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        if readFailed { return .failed("Some disk statistics could not be read. Retrying within 15 seconds.") }
        return disks.isEmpty ? .unavailable("No writable local disks were found.") : .available(disks)
    }

    private func getNetworkRates(at time: TimeInterval) -> Reading<NetworkRates> {
        guard let counters = NetworkInterfaces.readCounters() else {
            networkTracker.reset()
            return .failed("Network interface statistics could not be read.")
        }
        return networkTracker.update(counters, at: time)
    }
}
