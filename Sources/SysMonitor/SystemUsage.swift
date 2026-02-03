import Foundation
import Darwin

struct UsageMetrics {
    var cpuUsage: Double
    var memoryUsedGB: Double
    var memoryTotalGB: Double
    var diskFreeGB: Double
    var networkDownKBps: Double
    var networkUpKBps: Double
}

@MainActor
class SystemUsage {
    static let shared = SystemUsage()
    
    // CPU State
    private var previousInfo = processor_info_array_t(bitPattern: 0)
    private var previousCount = mach_msg_type_number_t(0)
    
    // Network State
    private var previousBytesIn: UInt64 = 0
    private var previousBytesOut: UInt64 = 0
    private var lastNetworkCheckTime: TimeInterval = 0
    
    init() {
        // Initialize CPU baseline
        let _ = getCPU()
        // Initialize Network baseline
        let _ = getNetwork()
    }
    
    func currentUsage() -> UsageMetrics {
        return UsageMetrics(
            cpuUsage: getCPU(),
            memoryUsedGB: getMemory().used,
            memoryTotalGB: getMemory().total,
            diskFreeGB: getDisk(),
            networkDownKBps: getNetwork().down,
            networkUpKBps: getNetwork().up
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
    private func getDisk() -> Double {
        let fileURL = URL(fileURLWithPath: "/")
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            if let capacity = values.volumeAvailableCapacity {
                return Double(capacity) / 1024 / 1024 / 1024
            }
        } catch {}
        return 0.0
    }
    
    // MARK: - Network
    // This part requires checking getifaddrs which is C API.
    private func getNetwork() -> (down: Double, up: Double) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }
        
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        
        var ptr = ifaddr
        while ptr != nil {
            let name = String(cString: ptr!.pointee.ifa_name)
            // Filter likely primary interfaces: en0, en1
             if (name == "en0" || name == "en1") && ptr!.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                 let data = unsafeBitCast(ptr!.pointee.ifa_data, to: UnsafeMutablePointer<if_data>.self)
                 totalIn += UInt64(data.pointee.ifi_ibytes)
                 totalOut += UInt64(data.pointee.ifi_obytes)
             }
            ptr = ptr!.pointee.ifa_next
        }
        
        let now = Date().timeIntervalSince1970
        var downRate = 0.0
        var upRate = 0.0
        
        if lastNetworkCheckTime > 0 {
            let dt = now - lastNetworkCheckTime
            if dt > 0 {
                // Bytes per second -> KBps
                if totalIn >= previousBytesIn {
                    downRate = Double(totalIn - previousBytesIn) / dt / 1024.0
                }
                if totalOut >= previousBytesOut {
                    upRate = Double(totalOut - previousBytesOut) / dt / 1024.0
                }
            }
        }
        
        previousBytesIn = totalIn
        previousBytesOut = totalOut
        lastNetworkCheckTime = now
        
        return (downRate, upRate)
    }
}
