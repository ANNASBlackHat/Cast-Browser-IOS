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

public enum NetworkIpHelper {
    public static func getLocalIpAddress() -> String? {
        var address: String?
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
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        socklen_t(0),
                        NI_NUMERICHOST
                    )
                    address = String(cString: hostname)
                    break
                }
            }
        }
        return address
    }
}
