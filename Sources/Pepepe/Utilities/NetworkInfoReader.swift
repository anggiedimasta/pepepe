import Foundation
import SystemConfiguration

enum NetworkInfoReader {
    static func read(for interfaceName: String) -> (ipv4: String?, ipv6: String?, gateway: String?, dns: String?) {
        let ipv4 = primaryAddress(family: AF_INET, interfaceName: interfaceName)
        let ipv6 = primaryAddress(family: AF_INET6, interfaceName: interfaceName)
        let gateway = defaultGateway()
        let dns = dnsServers()
        return (ipv4, ipv6, gateway, dns)
    }
    
    private static func primaryAddress(family: Int32, interfaceName: String) -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        
        var candidate: String?
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }
            
            guard let addr = current.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(family),
                  let name = current.pointee.ifa_name,
                  String(cString: name) == interfaceName else { continue }
            
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                addr,
                socklen_t(addr.pointee.sa_len),
                &host,
                socklen_t(host.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard result == 0 else { continue }
            
            let address = String(decoding: host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            if family == AF_INET6 {
                if address.hasPrefix("fe80:") { continue }
            }
            candidate = address
            break
        }
        return candidate
    }
    
    private static func defaultGateway() -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/sbin/route")
        process.arguments = ["-n", "get", "default"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            for line in output.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("gateway:") {
                    return trimmed.replacingOccurrences(of: "gateway:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                }
            }
        } catch {
            return nil
        }
        return nil
    }
    
    private static func dnsServers() -> String? {
        guard let store = SCDynamicStoreCreate(nil, "Pepepe" as CFString, nil, nil) else { return nil }
        guard let dnsInfo = SCDynamicStoreCopyValue(store, "State:/Network/Global/DNS" as CFString) as? [String: Any],
              let servers = dnsInfo["ServerAddresses"] as? [String],
              !servers.isEmpty else { return nil }
        return servers.joined(separator: "; ")
    }
}
