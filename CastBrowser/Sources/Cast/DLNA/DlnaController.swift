//
//  DlnaController.swift
//  CastBrowser
//

import Foundation

@MainActor
public protocol DlnaControllerDelegate: AnyObject {
    func dlnaPlaybackStateChanged(_ state: CastPlaybackState)
}

public actor DlnaController {
    public static let shared = DlnaController()

    private let session = URLSession.shared
    private var activeDevice: CastDevice?
    private var pollingTask: Task<Void, Never>?

    private init() {}

    public func setAvTransportUri(device: CastDevice, streamUrl: URL, title: String, mimeType: String = "video/mp4") async -> Bool {
        self.activeDevice = device
        guard let controlUrl = device.controlUrl else { return false }

        let body = DlnaSoapHelper.buildSetAvTransportUriXml(streamUrl: streamUrl.absoluteString, title: title, mimeType: mimeType)
        let success = await sendSoapAction(controlUrl: controlUrl, action: "SetAVTransportURI", body: body)

        if success {
            _ = await play(device: device)
            startPositionPolling(device: device)
        }
        return success
    }

    public func play(device: CastDevice) async -> Bool {
        guard let controlUrl = device.controlUrl else { return false }
        let body = DlnaSoapHelper.buildPlayXml()
        return await sendSoapAction(controlUrl: controlUrl, action: "Play", body: body)
    }

    public func pause(device: CastDevice) async -> Bool {
        guard let controlUrl = device.controlUrl else { return false }
        let body = DlnaSoapHelper.buildPauseXml()
        return await sendSoapAction(controlUrl: controlUrl, action: "Pause", body: body)
    }

    public func stop(device: CastDevice) async -> Bool {
        pollingTask?.cancel()
        pollingTask = nil

        guard let controlUrl = device.controlUrl else { return false }
        let body = DlnaSoapHelper.buildStopXml()
        return await sendSoapAction(controlUrl: controlUrl, action: "Stop", body: body)
    }

    public func seek(device: CastDevice, to seconds: Double) async -> Bool {
        guard let controlUrl = device.controlUrl else { return false }
        let body = DlnaSoapHelper.buildSeekXml(targetSeconds: seconds)
        return await sendSoapAction(controlUrl: controlUrl, action: "Seek", body: body)
    }

    public func getPositionInfo(device: CastDevice) async -> (position: Double, duration: Double)? {
        guard let controlUrl = device.controlUrl else { return nil }
        let body = DlnaSoapHelper.buildGetPositionInfoXml()

        guard let responseXml = await sendSoapActionWithResponse(controlUrl: controlUrl, action: "GetPositionInfo", body: body) else {
            return nil
        }

        let relTime = extractTag(from: responseXml, tag: "RelTime") ?? "00:00:00"
        let trackDuration = extractTag(from: responseXml, tag: "TrackDuration") ?? "00:00:00"

        let position = DlnaSoapHelper.parseUpnpTimeToSeconds(relTime)
        let duration = DlnaSoapHelper.parseUpnpTimeToSeconds(trackDuration)
        return (position, duration)
    }

    private func startPositionPolling(device: CastDevice) {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { break }
                _ = await getPositionInfo(device: device)
            }
        }
    }

    private func sendSoapAction(controlUrl: URL, action: String, body: String) async -> Bool {
        return (await sendSoapActionWithResponse(controlUrl: controlUrl, action: action, body: body)) != nil
    }

    private func sendSoapActionWithResponse(controlUrl: URL, action: String, body: String) async -> String? {
        var request = URLRequest(url: controlUrl)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue("\"urn:schemas-upnp-org:service:AVTransport:1#\(action)\"", forHTTPHeaderField: "SOAPACTION")
        request.httpBody = body.data(using: .utf8)
        request.timeoutInterval = 6.0

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            return String(data: data, encoding: .utf8)
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
}
