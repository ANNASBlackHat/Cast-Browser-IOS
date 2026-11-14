//
//  DetectedStream.swift
//  CastBrowser
//

import Foundation

public enum StreamFormat: String, Codable, Sendable {
    case hls = "HLS"
    case mp4 = "MP4"
    case dash = "DASH"
    case unknown = "VIDEO"

    public var badgeTitle: String {
        switch self {
        case .hls: return "HLS .m3u8"
        case .mp4: return "MP4 Video"
        case .dash: return "DASH .mpd"
        case .unknown: return "Direct Stream"
        }
    }
}

public struct DetectedStream: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let pageUrl: URL
    public let title: String
    public let format: StreamFormat
    public let resolution: String?
    public let contentLength: Int64?
    public let isDrmProtected: Bool
    public let detectedAt: Date

    public var mimeType: String {
        switch format {
        case .hls:
            return "application/vnd.apple.mpegurl"
        case .mp4:
            return "video/mp4"
        case .dash:
            return "application/dash+xml"
        case .unknown:
            return url.pathExtension.lowercased() == "m3u8" || url.absoluteString.lowercased().contains(".m3u8")
                ? "application/vnd.apple.mpegurl"
                : "video/mp4"
        }
    }

    public init(
        id: UUID = UUID(),
        url: URL,
        pageUrl: URL,
        title: String,
        format: StreamFormat = .unknown,
        resolution: String? = nil,
        contentLength: Int64? = nil,
        isDrmProtected: Bool = false,
        detectedAt: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.pageUrl = pageUrl
        self.title = title
        self.format = format
        self.resolution = resolution
        self.contentLength = contentLength
        self.isDrmProtected = isDrmProtected
        self.detectedAt = detectedAt
    }
}
