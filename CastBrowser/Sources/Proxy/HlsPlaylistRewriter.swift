//
//  HlsPlaylistRewriter.swift
//  CastBrowser
//

import Foundation

public enum HlsPlaylistRewriter {
    public static func rewrite(
        playlistContent: String,
        originalBaseUrl: URL,
        proxyEndpointBase: URL,
        sessionToken: String
    ) -> String {
        let lines = playlistContent.components(separatedBy: .newlines)
        var rewrittenLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                rewrittenLines.append(line)
                continue
            }

            // Keep comments and non-URI tags untouched
            if trimmed.hasPrefix("#") {
                // If line contains URI="...", rewrite inside tag (e.g. #EXT-X-KEY or #EXT-X-MAP)
                if trimmed.contains("URI=\"") {
                    let rewrittenTag = rewriteUriInTag(tag: trimmed, baseUrl: originalBaseUrl, proxyBase: proxyEndpointBase, token: sessionToken)
                    rewrittenLines.append(rewrittenTag)
                } else {
                    rewrittenLines.append(line)
                }
                continue
            }

            // This is a segment or sub-playlist URI line
            let resolvedUrl = URL(string: trimmed, relativeTo: originalBaseUrl)?.absoluteURL ?? originalBaseUrl
            let proxyUrl = proxyEndpointBase
                .appendingPathComponent("segment")
                .appendingPathComponent(sessionToken)
            var components = URLComponents(url: proxyUrl, resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "upstream", value: resolvedUrl.absoluteString)]

            if let rewrittenUri = components?.url?.absoluteString {
                rewrittenLines.append(rewrittenUri)
            } else {
                rewrittenLines.append(line)
            }
        }

        return rewrittenLines.joined(separator: "\n")
    }

    private static func rewriteUriInTag(tag: String, baseUrl: URL, proxyBase: URL, token: String) -> String {
        guard let rangeStart = tag.range(of: "URI=\"")?.upperBound,
              let rangeEnd = tag[rangeStart...].range(of: "\"")?.lowerBound else {
            return tag
        }

        let rawUri = String(tag[rangeStart..<rangeEnd])
        let resolved = URL(string: rawUri, relativeTo: baseUrl)?.absoluteURL ?? baseUrl

        let proxyUrl = proxyBase
            .appendingPathComponent("segment")
            .appendingPathComponent(token)
        var components = URLComponents(url: proxyUrl, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "upstream", value: resolved.absoluteString)]

        guard let replacement = components?.url?.absoluteString else { return tag }
        return tag.replacingOccurrences(of: "URI=\"\(rawUri)\"", with: "URI=\"\(replacement)\"")
    }
}
