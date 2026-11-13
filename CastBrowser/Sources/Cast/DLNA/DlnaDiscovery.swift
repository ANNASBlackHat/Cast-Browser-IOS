//
//  DlnaDiscovery.swift
//  CastBrowser
//

import Foundation
import Network
import Darwin

public actor DlnaDiscovery {
    public static let shared = DlnaDiscovery()

    private var discoveredDevices: [String: CastDevice] = [:]
    private var isSearching: Bool = false
    private let urlSession = URLSession.shared

    private let ssdpAddress = "239.255.255.250"
    private let ssdpPort: UInt16 = 1900

    private init() {}

    public func discoverDevices(timeoutSeconds: Double = 3.0) async -> [CastDevice] {
        guard !isSearching else { return Array(discoveredDevices.values) }
        isSearching = true
        defer { isSearching = false }

        // Use BSD sockets with SO_REUSEPORT and INADDR_ANY for reliable multicast responses
        let locationUrls = await performSsdpSearch(timeoutSeconds: timeoutSeconds)

        // Fetch XML device descriptions
        for loc in locationUrls {
            if let device = await fetchDeviceDescription(from: loc) {
                discoveredDevices[device.id] = device
            }
        }

        return Array(discoveredDevices.values)
    }

    public func probeDevice(at ipOrHost: String) async -> CastDevice? {
        let cleanHost = ipOrHost.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "/", with: "")

        // Common UPnP XML description ports on smart TVs
        let commonPorts = [8080, 7676, 8008, 9197, 80, 49152, 49153, 52235]
        for port in commonPorts {
            let possibleUrl = URL(string: "http://\(cleanHost):\(port)/description.xml") ??
                              URL(string: "http://\(cleanHost):\(port)/dmr/SamsungMRDesc.xml")!
            if let device = await fetchDeviceDescription(from: possibleUrl) {
                discoveredDevices[device.id] = device
                return device
            }
        }
        return nil
    }

    private func performSsdpSearch(timeoutSeconds: Double) async -> Set<URL> {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
                guard sock >= 0 else {
                    continuation.resume(returning: [])
                    return
                }

                var reuse: Int32 = 1
                setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
                setsockopt(sock, SOL_SOCKET, SO_REUSEPORT, &reuse, socklen_t(MemoryLayout<Int32>.size))

                var bindAddr = sockaddr_in()
                bindAddr.sin_family = sa_family_t(AF_INET)
                bindAddr.sin_port = in_port_t(0) // ephemeral port for incoming unicast replies
                bindAddr.sin_addr.s_addr = in_addr_t(INADDR_ANY)

                _ = withUnsafePointer(to: &bindAddr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                        bind(sock, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }

                var tv = timeval(tv_sec: Int(timeoutSeconds), tv_usec: 0)
                setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

                var dstAddr = sockaddr_in()
                dstAddr.sin_family = sa_family_t(AF_INET)
                dstAddr.sin_port = in_port_t(1900).bigEndian
                dstAddr.sin_addr.s_addr = inet_addr("239.255.255.250")

                let searchTargets = [
                    "urn:schemas-upnp-org:service:AVTransport:1",
                    "urn:schemas-upnp-org:device:MediaRenderer:1",
                    "ssdp:all"
                ]

                for st in searchTargets {
                    let msg = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 2\r\nST: \(st)\r\n\r\n"
                    _ = withUnsafePointer(to: &dstAddr) {
                        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                            sendto(sock, msg, msg.utf8.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                        }
                    }
                }

                var locations = Set<URL>()
                var buf = [UInt8](repeating: 0, count: 4096)
                var fromAddr = sockaddr_in()
                var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                let deadline = Date().addingTimeInterval(timeoutSeconds)

                while Date() < deadline {
                    let recvd = withUnsafeMutablePointer(to: &fromAddr) {
                        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                            recvfrom(sock, &buf, buf.count, 0, sa, &fromLen)
                        }
                    }

                    if recvd > 0 {
                        let resp = String(decoding: buf.prefix(recvd), as: UTF8.self)
                        if let loc = self.extractLocationUrl(from: resp) {
                            locations.insert(loc)
                        }
                    } else {
                        break
                    }
                }

                close(sock)
                continuation.resume(returning: locations)
            }
        }
    }

    private nonisolated func extractLocationUrl(from ssdpResponse: String) -> URL? {
        let lines = ssdpResponse.components(separatedBy: "\r\n")
        for line in lines {
            if line.uppercased().hasPrefix("LOCATION:") {
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let urlStr = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    return URL(string: urlStr)
                }
            }
        }
        return nil
    }

    private func fetchDeviceDescription(from location: URL) async -> CastDevice? {
        do {
            var request = URLRequest(url: location)
            request.timeoutInterval = 4.0
            let (data, _) = try await urlSession.data(for: request)
            guard let xml = String(data: data, encoding: .utf8) else { return nil }

            let friendlyName = extractTag(from: xml, tag: "friendlyName") ?? "Smart TV"
            let modelName = extractTag(from: xml, tag: "modelName")
            let udn = extractTag(from: xml, tag: "UDN") ?? location.absoluteString
            guard let controlPath = extractAvTransportControlUrl(from: xml) else { return nil }

            let controlUrl = URL(string: controlPath, relativeTo: location)?.absoluteURL ?? location
            return CastDevice(
                id: udn,
                name: friendlyName,
                modelName: modelName,
                protocolType: .dlna,
                controlUrl: controlUrl
            )
        } catch {
            return nil
        }
    }

    private func extractTag(from xml: String, tag: String) -> String? {
        guard let start = xml.range(of: "<\(tag)>")?.upperBound,
              let end = xml[start...].range(of: "</\(tag)>")?.lowerBound else {
            return nil
        }
        return String(xml[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractAvTransportControlUrl(from xml: String) -> String? {
        guard let avTransportRange = xml.range(of: "urn:schemas-upnp-org:service:AVTransport:1") else {
            return nil
        }
        let after = xml[avTransportRange.upperBound...]
        guard let ctrlStart = after.range(of: "<controlURL>")?.upperBound,
              let ctrlEnd = after[ctrlStart...].range(of: "</controlURL>")?.lowerBound else {
            return nil
        }
        return String(after[ctrlStart..<ctrlEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
