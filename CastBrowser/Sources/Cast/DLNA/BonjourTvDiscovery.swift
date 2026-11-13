//
//  BonjourTvDiscovery.swift
//  CastBrowser
//

import Foundation
import Network

public actor BonjourTvDiscovery {
    public static let shared = BonjourTvDiscovery()

    private var browsers: [NWBrowser] = []
    private var discoveredEndpoints: [String: NWEndpoint] = [:]

    private init() {}

    /// Starts Bonjour browsing for TV services. Calling this triggers Apple's Local Network Permission dialog.
    public func startBrowsing() {
        stopBrowsing()

        let serviceTypes = [
            "_dial-multiscreen-org._tcp",
            "_roku-rcp._tcp"
        ]

        for serviceType in serviceTypes {
            let descriptor = NWBrowser.Descriptor.bonjour(type: serviceType, domain: nil)
            let params = NWParameters()
            let browser = NWBrowser(for: descriptor, using: params)

            browser.browseResultsChangedHandler = { [weak self] results, changes in
                guard let self else { return }
                Task {
                    await self.handleBrowseResults(results)
                }
            }

            browser.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("[BonjourTvDiscovery] Browser ready for \(serviceType)")
                case .failed(let error):
                    print("[BonjourTvDiscovery] Browser failed for \(serviceType): \(error)")
                default:
                    break
                }
            }

            browser.start(queue: .global(qos: .userInitiated))
            browsers.append(browser)
        }
    }

    public func stopBrowsing() {
        for browser in browsers {
            browser.cancel()
        }
        browsers.removeAll()
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            switch result.endpoint {
            case .service(let name, let type, let domain, _):
                let key = "\(name).\(type).\(domain)"
                discoveredEndpoints[key] = result.endpoint
            default:
                break
            }
        }
    }

    /// Resolves discovered Bonjour endpoints into candidate IP addresses and port numbers
    public func resolveEndpoints(timeoutSeconds: Double = 2.0) async -> [(name: String, host: String, port: UInt16)] {
        var resolved: [(name: String, host: String, port: UInt16)] = []
        let endpoints = Array(discoveredEndpoints.values)

        await withTaskGroup(of: (String, String, UInt16)?.self) { group in
            for endpoint in endpoints {
                guard case .service(let name, _, _, _) = endpoint else { continue }
                group.addTask {
                    await self.resolveSingleEndpoint(endpoint: endpoint, name: name, timeout: timeoutSeconds)
                }
            }

            for await item in group {
                if let item {
                    resolved.append(item)
                }
            }
        }

        return resolved
    }

    private func resolveSingleEndpoint(endpoint: NWEndpoint, name: String, timeout: Double) async -> (String, String, UInt16)? {
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            let resumeOnce: ((String, String, UInt16)?) -> Void = { result in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: result)
            }

            let params = NWParameters.tcp
            let connection = NWConnection(to: endpoint, using: params)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if let remote = connection.currentPath?.remoteEndpoint,
                       case .hostPort(let host, let port) = remote {
                        let hostStr: String
                        switch host {
                        case .ipv4(let ipv4):
                            hostStr = "\(ipv4)"
                        case .name(let n, _):
                            hostStr = n
                        default:
                            hostStr = ""
                        }
                        connection.cancel()
                        resumeOnce((name, hostStr, port.rawValue))
                    } else {
                        connection.cancel()
                        resumeOnce(nil)
                    }
                case .failed, .cancelled:
                    resumeOnce(nil)
                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .userInitiated))

            // Timeout guard
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                connection.cancel()
                resumeOnce(nil)
            }
        }
    }
}
