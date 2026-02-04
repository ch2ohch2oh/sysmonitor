import Foundation
import Darwin
import IOKit

struct UsageMetrics {
    var cpuUsage: Double
    var perCoreUsage: [Double]
    var gpuUsage: Double
    var memoryUsedGB: Double
    var memoryTotalGB: Double
    var diskUsedGB: Double
    var diskTotalGB: Double
}

actor SystemUsage {
    nonisolated static let shared = SystemUsage()
    
    // CPU State
    private var previousInfo = processor_info_array_t(bitPattern: 0)
    private var previousCount = mach_msg_type_number_t(0)
    

    
    init() {
        // Initialize CPU baseline
        Task {
            let _ = await getCPU()
        }
    }
    
    func currentUsage() async -> UsageMetrics {
        let (diskUsed, diskTotal) = getDisk()
        let (cpu, perCore) = await getCPU()
        return UsageMetrics(
            cpuUsage: cpu,
            perCoreUsage: perCore,
            gpuUsage: getGPU(),
            memoryUsedGB: getMemory().used,
            memoryTotalGB: getMemory().total,
            diskUsedGB: diskUsed,
            diskTotalGB: diskTotal
        )
    }
    
    // MARK: - CPU
    private func getCPU() async -> (Double, [Double]) {
        var count = mach_msg_type_number_t(0)
        var info = processor_info_array_t(bitPattern: 0)
        let host = mach_host_self()
        
        var msgCount = count
        let result = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &count, &info, &msgCount)
        
        guard result == KERN_SUCCESS, let infoArray = info else {
            return (0.0, [])
        }
        
        var totalSystem: Int32 = 0
        var totalUser: Int32 = 0
        var totalIdle: Int32 = 0
        
        // 'count' is the number of processors (not the number of integers in info array)
        let numCPUs = Int(count)
        var coreUsages: [Double] = []
        
        if let prevInfo = previousInfo {
            for i in 0..<numCPUs {
                let offset = i * Int(CPU_STATE_MAX)
                let baseIndex = offset
                
                let user = infoArray[baseIndex + Int(CPU_STATE_USER)] - prevInfo[baseIndex + Int(CPU_STATE_USER)]
                let system = infoArray[baseIndex + Int(CPU_STATE_SYSTEM)] - prevInfo[baseIndex + Int(CPU_STATE_SYSTEM)]
                let nice = infoArray[baseIndex + Int(CPU_STATE_NICE)] - prevInfo[baseIndex + Int(CPU_STATE_NICE)]
                let idle = infoArray[baseIndex + Int(CPU_STATE_IDLE)] - prevInfo[baseIndex + Int(CPU_STATE_IDLE)]
                
                let coreTotal = user + system + nice + idle
                let coreUsed = user + system + nice
                
                if coreTotal > 0 {
                    coreUsages.append(Double(coreUsed) / Double(coreTotal) * 100.0)
                } else {
                    coreUsages.append(0.0)
                }
                
                totalUser += user + nice
                totalSystem += system
                totalIdle += idle
            }
            
            let prevSize = Int(previousCount) * MemoryLayout<integer_t>.size
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevInfo), vm_size_t(prevSize))
        } else {
            // First run, populate 0s
            coreUsages = Array(repeating: 0.0, count: numCPUs)
        }
        
        // Update previous
        previousInfo = info
        previousCount = count
        
        let total = totalSystem + totalUser + totalIdle
        if total == 0 { return (0.0, coreUsages) }
        
        let overall = Double(totalSystem + totalUser) / Double(total) * 100.0
        return (overall, coreUsages)
    }
    
    // MARK: - GPU
    private func getGPU() -> Double {
        var utilization: Double = 0.0
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator)
        
        if result == KERN_SUCCESS {
            var service: io_registry_entry_t = IOIteratorNext(iterator)
            var count = 0
            while service != 0 {
                if let stats = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
                    // Try different possible keys for GPU utilization
                    if let util = stats["Device Utilization %"] as? Int {
                        utilization += Double(util)
                        count += 1
                    } else if let util = stats["GPU Activity(%)"] as? Int {
                        utilization += Double(util)
                        count += 1
                    } else if let util = stats["Utilization %"] as? Int {
                        utilization += Double(util)
                        count += 1
                    }
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
            
            if count > 0 {
                return utilization / Double(count)
            }
        }
        return 0.0
    }
    // MARK: - Memory
    private func getMemory() -> (used: Double, total: Double) {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var hostInfo = vm_statistics64_data_t()
        
        let result = withUnsafeMutablePointer(to: &hostInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }
        
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        
        if result == KERN_SUCCESS {
            let pageSize = sysconf(_SC_PAGESIZE)
            // Use active + wire as reliable "used" metric for user perception, or active + wire + compressed?
            // "App Memory" usually includes wired + active + compressed.
            // "Used Memory" in Activity Monitor includes everything except cached files.
            
            // vm_statistics64 fields are in pages.
            let usedBytes = UInt64(hostInfo.active_count + hostInfo.wire_count) * UInt64(pageSize)
            // Adding compressed
            let compressedBytes = UInt64(hostInfo.compressor_page_count) * UInt64(pageSize)
            
             let totalUsed = Double(usedBytes + compressedBytes) / 1024 / 1024 / 1024
             let totalGB = Double(totalBytes) / 1024 / 1024 / 1024
             
             return (totalUsed, totalGB)
        }
        
        return (0, 0)
    }
    
    // MARK: - Disk
    private func getDisk() -> (used: Double, total: Double) {
        let fileURL = URL(fileURLWithPath: "/")
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityKey, .volumeTotalCapacityKey])
            if let capacity = values.volumeAvailableCapacity, let total = values.volumeTotalCapacity {
                let totalGB = Double(total) / 1024 / 1024 / 1024
                let freeGB = Double(capacity) / 1024 / 1024 / 1024
                let usedGB = totalGB - freeGB
                return (usedGB, totalGB)
            }
        } catch {}
        return (0.0, 0.0)
    }
    

    

}
