//
//  ProxyStreamManager.swift
//  CastBrowser
//

import Foundation

public struct ProxySession: Sendable {
    public let originalUrl: URL
    public let referer: URL?
    public let userAgent: String
    public let cookies: String?

    public init(originalUrl: URL, referer: URL? = nil, userAgent: String = "Mozilla/5.0", cookies: String? = nil) {
        self.originalUrl = originalUrl
        self.referer = referer
        self.userAgent = userAgent
        self.cookies = cookies
    }
}

public actor ProxyStreamManager {
    public static let shared = ProxyStreamManager()

    private var sessions: [String: ProxySession] = [:]
    private var proxyPort: UInt16 = 8888

    private init() {}

    public func setProxyPort(_ port: UInt16) {
        self.proxyPort = port
    }

    public func registerSession(
        streamUrl: URL,
        referer: URL?,
        userAgent: String = "Mozilla/5.0 (iPad; CPU OS 17_2 like Mac OS X)",
        cookies: String? = nil
    ) -> (token: String, proxyUrl: URL) {
        let token = UUID().uuidString
        let session = ProxySession(originalUrl: streamUrl, referer: referer, userAgent: userAgent, cookies: cookies)
        sessions[token] = session

        let localIp = NetworkIpHelper.getLocalIpAddress() ?? "127.0.0.1"
        let proxyUrl = URL(string: "http://\(localIp):\(proxyPort)/stream/\(token)/master.m3u8")!
        return (token, proxyUrl)
    }

    public func getSession(token: String) -> ProxySession? {
        return sessions[token]
    }

    public func unregisterSession(token: String) {
        sessions.removeValue(forKey: token)
    }
}

public struct WifiNetworkInfo: Sendable {
    public let ip: String
    public let netmask: String
    public let broadcastIp: String
    public let prefix: String // e.g. "192.168.1"
}

public enum NetworkIpHelper {
    public static func getLocalIpAddress() -> String? {
        return getWifiNetworkInfo()?.ip
    }

    public static func getWifiNetworkInfo() -> WifiNetworkInfo? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                // en0 is Wi-Fi on iOS
                if name == "en0" {
                    var ipHost = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &ipHost,
                        socklen_t(ipHost.count),
                        nil,
                        socklen_t(0),
                        NI_NUMERICHOST
                    )
                    let ipStr = String(cString: ipHost)

                    var maskHost = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_netmask,
                        socklen_t(interface.ifa_netmask.pointee.sa_len),
                        &maskHost,
                        socklen_t(maskHost.count),
                        nil,
                        socklen_t(0),
                        NI_NUMERICHOST
                    )
                    let maskStr = String(cString: maskHost)

                    let ipParts = ipStr.split(separator: ".").compactMap { UInt32($0) }
                    let maskParts = maskStr.split(separator: ".").compactMap { UInt32($0) }

                    var broadcastIp = "255.255.255.255"
                    if ipParts.count == 4 && maskParts.count == 4 {
                        let b0 = (ipParts[0] & maskParts[0]) | (~maskParts[0] & 0xFF)
                        let b1 = (ipParts[1] & maskParts[1]) | (~maskParts[1] & 0xFF)
                        let b2 = (ipParts[2] & maskParts[2]) | (~maskParts[2] & 0xFF)
                        let b3 = (ipParts[3] & maskParts[3]) | (~maskParts[3] & 0xFF)
                        broadcastIp = "\(b0).\(b1).\(b2).\(b3)"
                    }

                    let prefix = ipParts.count >= 3 ? "\(ipParts[0]).\(ipParts[1]).\(ipParts[2])" : "192.168.1"
                    return WifiNetworkInfo(ip: ipStr, netmask: maskStr, broadcastIp: broadcastIp, prefix: prefix)
                }
            }
        }
        return nil
    }

    /// Generates candidate host IPs on the /24 subnet, prioritized for smart TV DHCP patterns
    public static func generateSubnetCandidates() -> [String] {
        guard let info = getWifiNetworkInfo() else { return [] }
        let currentLastOctet = info.ip.split(separator: ".").last.flatMap { Int($0) } ?? -1

        // Order of highest probability for smart TVs:
        // 1. Common static/low IPs: 2...40
        // 2. Common DHCP upper pool: 100...150
        // 3. Mid DHCP pool: 50...99
        // 4. Remaining: 151...254 and 41...49
        var order: [Int] = []
        order.append(contentsOf: 2...40)
        order.append(contentsOf: 100...150)
        order.append(contentsOf: 50...99)
        order.append(contentsOf: 151...254)
        order.append(contentsOf: 41...49)

        var result: [String] = []
        var seen = Set<Int>()
        for octet in order {
            if octet != currentLastOctet && octet != 1 && !seen.contains(octet) {
                seen.insert(octet)
                result.append("\(info.prefix).\(octet)")
            }
        }
        return result
    }
}
