//
//  StreamClassifier.swift
//  CastBrowser
//

import Foundation

public enum StreamClassifier {
    public static func classify(url: URL, contentType: String? = nil) -> StreamFormat {
        let pathLower = url.path.lowercased()
        let queryLower = url.query?.lowercased() ?? ""
        let fullString = url.absoluteString.lowercased()

        // 1. Content-Type inspection
        if let contentType = contentType?.lowercased() {
            if contentType.contains("application/vnd.apple.mpegurl") ||
                contentType.contains("application/x-mpegurl") ||
                contentType.contains("vnd.apple.mpegurl") {
                return .hls
            }
            if contentType.contains("video/mp4") || contentType.contains("video/m4v") {
                return .mp4
            }
            if contentType.contains("application/dash+xml") {
                return .dash
            }
        }

        // 2. URL Extension and Query pattern matching
        if pathLower.contains(".m3u8") || queryLower.contains(".m3u8") || fullString.contains(".m3u8") {
            return .hls
        }

        if pathLower.contains(".mpd") || queryLower.contains(".mpd") || fullString.contains("/manifest") {
            return .dash
        }

        if pathLower.contains(".mp4") || pathLower.contains(".m4v") || queryLower.contains(".mp4") {
            return .mp4
        }

        // Generic stream indicators
        if fullString.contains("videoplayback") || fullString.contains("playlist.m3u8") {
            return .hls
        }

        return .unknown
    }

    public static func isMasterPlaylist(url: URL) -> Bool {
        let string = url.absoluteString.lowercased()
        return string.contains("master") || string.contains("playlist") || !string.contains("chunk")
    }

    public static func isLikelyAdUrl(url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        let string = url.absoluteString.lowercased()

        return host.contains("doubleclick") ||
               host.contains("googleads") ||
               string.contains("/ad/") ||
               string.contains("/ads/") ||
               string.contains("ad_tag") ||
               string.contains("preroll")
    }
}
