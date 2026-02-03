import Foundation
import Darwin
import IOKit

struct UsageMetrics {
    var cpuUsage: Double
    var memoryUsedGB: Double
    var memoryTotalGB: Double
    var diskUsedGB: Double
    var diskTotalGB: Double
}

@MainActor
class SystemUsage {
    static let shared = SystemUsage()
    
    // CPU State
    private var previousInfo = processor_info_array_t(bitPattern: 0)
    private var previousCount = mach_msg_type_number_t(0)
    

    
    init() {
        // Initialize CPU baseline
        let _ = getCPU()
    }
    
    func currentUsage() -> UsageMetrics {
        let (diskUsed, diskTotal) = getDisk()
        return UsageMetrics(
            cpuUsage: getCPU(),
            memoryUsedGB: getMemory().used,
            memoryTotalGB: getMemory().total,
            diskUsedGB: diskUsed,
            diskTotalGB: diskTotal
        )
    }
    
    // MARK: - CPU
    private func getCPU() -> Double {
        var count = mach_msg_type_number_t(0)
        var info = processor_info_array_t(bitPattern: 0)
        let host = mach_host_self()
        
        var msgCount = count
        let result = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &count, &info, &msgCount)
        
        guard result == KERN_SUCCESS, let infoArray = info else {
            return 0.0
        }
        
        var totalSystem: Int32 = 0
        var totalUser: Int32 = 0
        var totalIdle: Int32 = 0
        
        let numCPUs = Int(count) / Int(CPU_STATE_MAX)
        
        // Safe pointer arithmetic
        // info is UnsafeMutablePointer<integer_t> aka Int32
        
        if let prevInfo = previousInfo {
             for i in 0..<numCPUs {
                 let offset = i * Int(CPU_STATE_MAX)
                 let baseIndex = offset
                 
                 // Indices in CPU_STATE_* are:
                 // USER, SYSTEM, IDLE, NICE
                 
                 let user = infoArray[baseIndex + Int(CPU_STATE_USER)] - prevInfo[baseIndex + Int(CPU_STATE_USER)]
                 let system = infoArray[baseIndex + Int(CPU_STATE_SYSTEM)] - prevInfo[baseIndex + Int(CPU_STATE_SYSTEM)]
                 let nice = infoArray[baseIndex + Int(CPU_STATE_NICE)] - prevInfo[baseIndex + Int(CPU_STATE_NICE)]
                 let idle = infoArray[baseIndex + Int(CPU_STATE_IDLE)] - prevInfo[baseIndex + Int(CPU_STATE_IDLE)]
                 
                 totalUser += user + nice
                 totalSystem += system
                 totalIdle += idle
             }
             
             // Deallocate previous
             let prevSize = Int(previousCount) * MemoryLayout<integer_t>.size
             vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevInfo), vm_size_t(prevSize))
        }
        
        // Update previous
        previousInfo = info
        previousCount = count
        
        let total = totalSystem + totalUser + totalIdle
        if total == 0 { return 0.0 }
        
        return Double(totalSystem + totalUser) / Double(total) * 100.0
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
