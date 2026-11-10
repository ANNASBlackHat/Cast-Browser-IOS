//
//  DlnaDiscovery.swift
//  CastBrowser
//

import Foundation
import Network

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

        let searchMsg = """
        M-SEARCH * HTTP/1.1\r
        HOST: 239.255.255.250:1900\r
        MAN: "ssdp:discover"\r
        MX: 2\r
        ST: urn:schemas-upnp-org:service:AVTransport:1\r
        \r\n
        """

        guard let data = searchMsg.data(using: .utf8) else { return [] }

        // Send SSDP UDP multicast
        let host = NWEndpoint.Host(ssdpAddress)
        let port = NWEndpoint.Port(rawValue: ssdpPort)!
        let connection = NWConnection(host: host, port: port, using: .udp)

        connection.start(queue: .global())
        connection.send(content: data, completion: .contentProcessed { _ in })

        // Receive responses
        var locationUrls = Set<URL>()
        let endTime = Date().addingTimeInterval(timeoutSeconds)

        while Date() < endTime {
            if let responseData = await receivePacket(on: connection),
               let responseText = String(data: responseData, encoding: .utf8) {
                if let loc = extractLocationUrl(from: responseText) {
                    locationUrls.insert(loc)
                }
            } else {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }

        connection.cancel()

        // Fetch XML device descriptions
        for loc in locationUrls {
            if let device = await fetchDeviceDescription(from: loc) {
                discoveredDevices[device.id] = device
            }
        }

        return Array(discoveredDevices.values)
    }

    private func receivePacket(on connection: NWConnection) async -> Data? {
        return await withCheckedContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private func extractLocationUrl(from ssdpResponse: String) -> URL? {
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
            let (data, _) = try await urlSession.data(from: location)
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
        // Look for serviceType urn:schemas-upnp-org:service:AVTransport:1
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
