//
//  StreamProbeService.swift
//  CastBrowser
//

import Foundation

public struct ProbeResult: Sendable {
    public let isValidMedia: Bool
    public let format: StreamFormat
    public let contentLength: Int64?
    public let resolution: String?
    public let isDrmProtected: Bool
}

public actor StreamProbeService {
    public static let shared = StreamProbeService()

    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 8.0
        configuration.timeoutIntervalForResource = 15.0
        self.session = URLSession(configuration: configuration)
    }

    public func probe(url: URL, referer: URL? = nil) async -> ProbeResult {
        // Quick local classification first
        let quickFormat = StreamClassifier.classify(url: url)

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue("bytes=0-1024", forHTTPHeaderField: "Range")

        if let referer {
            request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
        }
        request.setValue("Mozilla/5.0 (iPad; CPU OS 17_2 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return fallbackResult(for: url, quickFormat: quickFormat)
            }

            // Check if status is successful (200, 206) or redirect (302, 301)
            let statusCode = httpResponse.statusCode
            if statusCode >= 400 {
                return fallbackResult(for: url, quickFormat: quickFormat)
            }

            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")
            let resolvedFormat = StreamClassifier.classify(url: url, contentType: contentType)

            let lengthHeader = httpResponse.value(forHTTPHeaderField: "Content-Length")
            let length = lengthHeader.flatMap { Int64($0) }

            // DRM check
            let isDrm = (contentType?.contains("drm") ?? false) ||
                        (httpResponse.value(forHTTPHeaderField: "X-Key-System") != nil)

            return ProbeResult(
                isValidMedia: true,
                format: resolvedFormat,
                contentLength: length,
                resolution: nil,
                isDrmProtected: isDrm
            )
        } catch {
            return fallbackResult(for: url, quickFormat: quickFormat)
        }
    }

    private func fallbackResult(for url: URL, quickFormat: StreamFormat) -> ProbeResult {
        // If HEAD failed due to server rejecting HEAD, still consider valid if extension was m3u8 or mp4
        let isValid = (quickFormat != .unknown)
        return ProbeResult(
            isValidMedia: isValid,
            format: quickFormat,
            contentLength: nil,
            resolution: nil,
            isDrmProtected: false
        )
    }
}
