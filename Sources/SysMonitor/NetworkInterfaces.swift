import Foundation
import Darwin

enum NetworkInterfaces {
    static func readCounters() -> [String: NetworkCounters]? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var size = 0
        guard sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, u_int(mib.count), &buffer, &size, nil, 0) == 0, size <= buffer.count else { return nil }
        return buffer.withUnsafeBytes { bytes in
            var counters: [String: NetworkCounters] = [:]
            var offset = 0
            while offset < size {
                guard offset + 4 <= size else { return nil }
                let length = Int(bytes.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
                guard length >= 4, offset + length <= size else { return nil }
                defer { offset += length }
                guard bytes[offset + 3] == UInt8(RTM_IFINFO2) else { continue }
                guard length >= MemoryLayout<if_msghdr2>.size else { return nil }
                let message = bytes.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                guard message.ifm_flags & IFF_UP != 0, message.ifm_flags & IFF_LOOPBACK == 0 else { continue }
                var nameBuffer = [CChar](repeating: 0, count: Int(IFNAMSIZ))
                guard if_indextoname(UInt32(message.ifm_index), &nameBuffer) != nil else { continue }
                let name = String(decoding: nameBuffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
                // Physical Wi-Fi/Ethernet only: including utun/bridge/awdl would count the same traffic twice.
                guard name.hasPrefix("en") else { continue }
                counters[name] = NetworkCounters(received: message.ifm_data.ifi_ibytes,
                                                  sent: message.ifm_data.ifi_obytes)
            }
            return counters
        }
    }
}
