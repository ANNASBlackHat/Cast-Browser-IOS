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
    private let urlSession: URLSession

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2.5
        config.timeoutIntervalForResource = 3.5
        self.urlSession = URLSession(configuration: config)
    }

    /// Discovers DLNA/UPnP Smart TVs using multi-channel strategy:
    /// 1. Bonjour / DIAL mDNS discovery (triggers Apple Local Network prompt)
    /// 2. BSD socket SSDP with SO_BROADCAST (255.255.255.255 and subnet broadcast)
    /// 3. Subnet HTTP candidate sweep
    public func discoverDevices(timeoutSeconds: Double = 3.5) async -> [CastDevice] {
        guard !isSearching else { return Array(discoveredDevices.values) }
        isSearching = true
        defer { isSearching = false }

        // Start Bonjour discovery (officially prompts for Local Network Permission)
        await BonjourTvDiscovery.shared.startBrowsing()

        // Run SSDP broadcast and Bonjour resolution concurrently
        async let ssdpLocations = performSsdpSearch(timeoutSeconds: timeoutSeconds)
        async let bonjourEndpoints = BonjourTvDiscovery.shared.resolveEndpoints(timeoutSeconds: 2.0)

        let locations = await ssdpLocations
        for loc in locations {
            if let device = await fetchDeviceDescription(from: loc) {
                discoveredDevices[device.id] = device
            }
        }

        let endpoints = await bonjourEndpoints
        for ep in endpoints {
            if let device = await probeDevice(at: ep.host, preferredPort: ep.port) {
                discoveredDevices[device.id] = device
            }
        }

        // If no devices discovered yet, sweep prioritized candidate IPs on local subnet
        if discoveredDevices.isEmpty {
            let sweptDevices = await sweepSubnetCandidates(timeoutSeconds: 2.0)
            for device in sweptDevices {
                discoveredDevices[device.id] = device
            }
        }

        return Array(discoveredDevices.values)
    }

    /// Explicit deep scan of the local /24 subnet for Smart TVs
    public func deepScanSubnet() async -> [CastDevice] {
        guard !isSearching else { return Array(discoveredDevices.values) }
        isSearching = true
        defer { isSearching = false }

        let sweptDevices = await sweepSubnetCandidates(timeoutSeconds: 3.0)
        for device in sweptDevices {
            discoveredDevices[device.id] = device
        }
        return Array(discoveredDevices.values)
    }

    /// Concurrent fast probe of a single IP or host across all known Smart TV UPnP ports (< 1.5s)
    public func probeDevice(at ipOrHost: String, preferredPort: UInt16? = nil) async -> CastDevice? {
        let cleanHost = ipOrHost.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .components(separatedBy: "/").first ?? ipOrHost

        // Common UPnP XML description ports and paths across Samsung, LG, Sony, Roku, Philips
        var ports: [Int] = []
        if let preferredPort {
            ports.append(Int(preferredPort))
        }
        let commonPorts = [8080, 7676, 8008, 9197, 8060, 49152, 49153, 52235, 80]
        for p in commonPorts where !ports.contains(p) {
            ports.append(p)
        }

        let endpoints = [
            "/description.xml",
            "/dmr/SamsungMRDesc.xml",
            "/smp_4_",
            "/ssdp/device-desc.xml",
            "/device-desc.xml",
            "/dial/dd.xml",
            "/dd.xml",
            "/upnp/control/description.xml"
        ]

        let discovered = await withTaskGroup(of: CastDevice?.self, returning: CastDevice?.self) { group in
            for port in ports {
                for ep in endpoints {
                    if let url = URL(string: "http://\(cleanHost):\(port)\(ep)") {
                        group.addTask {
                            return await self.fetchDeviceDescription(from: url)
                        }
                    }
                }
            }

            for await result in group {
                if let device = result {
                    group.cancelAll()
                    return device
                }
            }
            return nil
        }

        if let discovered {
            self.discoveredDevices[discovered.id] = discovered
            return discovered
        }
        return nil
    }

    private func sweepSubnetCandidates(timeoutSeconds: Double) async -> [CastDevice] {
        let candidates = NetworkIpHelper.generateSubnetCandidates()
        guard !candidates.isEmpty else { return [] }

        // Test in parallel batches of 25 to respect socket limits
        let batchSize = 25
        var found: [CastDevice] = []

        for i in stride(from: 0, to: min(candidates.count, 75), by: batchSize) {
            let chunk = Array(candidates[i..<min(i + batchSize, candidates.count)])
            let batchResults = await withTaskGroup(of: CastDevice?.self) { group in
                for ip in chunk {
                    group.addTask {
                        // Quick probe primary UPnP ports
                        return await self.quickProbe(ip: ip)
                    }
                }

                var chunkDevices: [CastDevice] = []
                for await result in group {
                    if let d = result {
                        chunkDevices.append(d)
                    }
                }
                return chunkDevices
            }
            found.append(contentsOf: batchResults)
            if !found.isEmpty {
                break // Found device(s), finish early
            }
        }

        return found
    }

    private func quickProbe(ip: String) async -> CastDevice? {
        let primaryUrls = [
            "http://\(ip):8080/description.xml",
            "http://\(ip):7676/smp_4_",
            "http://\(ip):8008/ssdp/device-desc.xml",
            "http://\(ip):9197/dmr/SamsungMRDesc.xml",
            "http://\(ip):8060/",
            "http://\(ip):49152/description.xml"
        ]

        for urlString in primaryUrls {
            guard let url = URL(string: urlString) else { continue }
            if let device = await fetchDeviceDescription(from: url) {
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

                // Enable SO_BROADCAST for subnet broadcast packets
                var broadcastEnable: Int32 = 1
                setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, socklen_t(MemoryLayout<Int32>.size))

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

                // Target addresses: global broadcast, subnet directed broadcast, and multicast
                var targetIps = ["255.255.255.255", "239.255.255.250"]
                if let netInfo = NetworkIpHelper.getWifiNetworkInfo() {
                    targetIps.insert(netInfo.broadcastIp, at: 0)
                }

                let searchTargets = [
                    "urn:schemas-upnp-org:service:AVTransport:1",
                    "urn:schemas-upnp-org:device:MediaRenderer:1",
                    "ssdp:all"
                ]

                for targetIp in targetIps {
                    var dstAddr = sockaddr_in()
                    dstAddr.sin_family = sa_family_t(AF_INET)
                    dstAddr.sin_port = in_port_t(1900).bigEndian
                    dstAddr.sin_addr.s_addr = inet_addr(targetIp)

                    for st in searchTargets {
                        let msg = "M-SEARCH * HTTP/1.1\r\nHOST: \(targetIp):1900\r\nMAN: \"ssdp:discover\"\r\nMX: 2\r\nST: \(st)\r\n\r\n"
                        _ = withUnsafePointer(to: &dstAddr) {
                            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                                sendto(sock, msg, msg.utf8.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                            }
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
            request.timeoutInterval = 1.8
            let (data, _) = try await urlSession.data(for: request)
            guard let xml = String(data: data, encoding: .utf8) else { return nil }

            return parseDeviceXml(xml: xml, location: location)
        } catch {
            return nil
        }
    }

    private nonisolated func parseDeviceXml(xml: String, location: URL) -> CastDevice? {
        let friendlyName = extractTag(from: xml, tag: "friendlyName") ?? "Smart TV"
        let modelName = extractTag(from: xml, tag: "modelName")
        let udn = extractTag(from: xml, tag: "UDN") ?? location.absoluteString

        guard let controlPath = extractAvTransportControlUrl(from: xml) else {
            // If device is a MediaRenderer or Roku, use location as fallback control
            if xml.localizedCaseInsensitiveContains("MediaRenderer") || xml.localizedCaseInsensitiveContains("Roku") {
                return CastDevice(
                    id: udn,
                    name: friendlyName,
                    modelName: modelName,
                    protocolType: .dlna,
                    controlUrl: location
                )
            }
            return nil
        }

        let controlUrl = URL(string: controlPath, relativeTo: location)?.absoluteURL ?? location
        return CastDevice(
            id: udn,
            name: friendlyName,
            modelName: modelName,
            protocolType: .dlna,
            controlUrl: controlUrl
        )
    }

    private nonisolated func extractTag(from xml: String, tag: String) -> String? {
        guard let start = xml.range(of: "<\(tag)>", options: .caseInsensitive)?.upperBound,
              let end = xml[start...].range(of: "</\(tag)>", options: .caseInsensitive)?.lowerBound else {
            return nil
        }
        return String(xml[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated func extractAvTransportControlUrl(from xml: String) -> String? {
        // Regex to search each <service>...</service> block
        let servicePattern = "<service[\\s>](.*?)</service>"
        if let regex = try? NSRegularExpression(pattern: servicePattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
            let nsString = xml as NSString
            let matches = regex.matches(in: xml, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                let block = nsString.substring(with: match.range)
                if block.localizedCaseInsensitiveContains("AVTransport") {
                    if let ctrl = extractTag(from: block, tag: "controlURL") {
                        return ctrl
                    }
                }
            }
        }

        // Direct fallback: find AVTransport then search for controlURL
        if let avTransportRange = xml.range(of: "AVTransport", options: .caseInsensitive) {
            let after = xml[avTransportRange.upperBound...]
            if let ctrlStart = after.range(of: "<controlURL>", options: .caseInsensitive)?.upperBound,
               let ctrlEnd = after[ctrlStart...].range(of: "</controlURL>", options: .caseInsensitive)?.lowerBound {
                return String(after[ctrlStart..<ctrlEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
}
