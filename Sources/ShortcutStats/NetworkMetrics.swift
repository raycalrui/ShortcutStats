import Darwin
import Foundation

struct NetworkInterfaceCounters: Equatable {
    let received: UInt64
    let sent: UInt64
}

final class NetworkTracker {
    static let systemAppID = "cc.raycal.ShortcutStats.system-network"
    private var previous: [String: NetworkInterfaceCounters]?

    func reset() { previous = nil }

    func sample(enabled: Bool, eligible: Bool) -> [MetricDelta] {
        guard enabled, eligible else {
            previous = nil
            return []
        }
        let current = Self.interfaceCounters()
        defer { previous = current }
        guard let previous else { return [] }
        return Self.deltas(previous: previous, current: current)
    }

    static func deltas(previous: [String: NetworkInterfaceCounters],
                       current: [String: NetworkInterfaceCounters]) -> [MetricDelta] {
        var received: UInt64 = 0
        var sent: UInt64 = 0
        for (name, value) in current {
            guard let old = previous[name] else { continue }
            if value.received >= old.received { received &+= value.received - old.received }
            if value.sent >= old.sent { sent &+= value.sent - old.sent }
        }
        var result: [MetricDelta] = []
        if received > 0 { result.append(MetricDelta(metric: "network.download.bytes", value: Double(received))) }
        if sent > 0 { result.append(MetricDelta(metric: "network.upload.bytes", value: Double(sent))) }
        return result
    }

    private static func interfaceCounters() -> [String: NetworkInterfaceCounters] {
        var mib = [Int32(CTL_NET), Int32(PF_ROUTE), 0, 0, Int32(NET_RT_IFLIST2), 0]
        var byteCount = 0
        let sizeResult = mib.withUnsafeMutableBufferPointer {
            sysctl($0.baseAddress, UInt32($0.count), nil, &byteCount, nil, 0)
        }
        guard sizeResult == 0, byteCount > 0 else { return [:] }

        var buffer = [UInt8](repeating: 0, count: byteCount)
        let readResult = mib.withUnsafeMutableBufferPointer { mibBuffer in
            buffer.withUnsafeMutableBytes { bytes in
                sysctl(mibBuffer.baseAddress, UInt32(mibBuffer.count), bytes.baseAddress, &byteCount, nil, 0)
            }
        }
        guard readResult == 0 else { return [:] }

        var result: [String: NetworkInterfaceCounters] = [:]
        buffer.withUnsafeBytes { bytes in
            var offset = 0
            while offset + MemoryLayout<UInt16>.size <= byteCount {
                let messageLength = Int(bytes.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
                guard messageLength > 0, offset + messageLength <= byteCount else { break }
                let messageType = bytes.loadUnaligned(fromByteOffset: offset + 3, as: UInt8.self)
                if messageType == UInt8(RTM_IFINFO2), messageLength >= MemoryLayout<if_msghdr2>.size {
                    let message = bytes.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    let flags = UInt32(bitPattern: message.ifm_flags)
                    if flags & UInt32(IFF_LOOPBACK) == 0, flags & UInt32(IFF_UP) != 0 {
                        var name = [CChar](repeating: 0, count: Int(IFNAMSIZ))
                        let resolved = name.withUnsafeMutableBufferPointer {
                            if_indextoname(UInt32(message.ifm_index), $0.baseAddress)
                        }
                        if resolved != nil {
                            result[String(cString: name)] = NetworkInterfaceCounters(
                                received: message.ifm_data.ifi_ibytes,
                                sent: message.ifm_data.ifi_obytes
                            )
                        }
                    }
                }
                offset += messageLength
            }
        }
        return result
    }
}
