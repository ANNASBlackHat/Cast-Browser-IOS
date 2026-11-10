//
//  EpisodeTitleParser.swift
//  CastBrowser
//

import Foundation

public struct ParsedMediaInfo: Equatable {
    public let title: String
    public let seriesKey: String?
    public let season: Int?
    public let episode: Int?

    public init(
        title: String,
        seriesKey: String? = nil,
        season: Int? = nil,
        episode: Int? = nil
    ) {
        self.title = title
        self.seriesKey = seriesKey
        self.season = season
        self.episode = episode
    }
}

public enum EpisodeTitleParser {
    // S02E05, S2E5, S02.E05, S2-E5
    private static let seRegex = try! NSRegularExpression(
        pattern: #"(?i)\bS(\d{1,2})[\s._-]*E(\d{1,3})\b"#
    )
    // 2x05, 02x05
    private static let xRegex = try! NSRegularExpression(
        pattern: #"(?i)\b(\d{1,2})x(\d{1,3})\b"#
    )
    // Season 2 Episode 5, Season 02, Episode 05
    private static let seasonEpisodeTextRegex = try! NSRegularExpression(
        pattern: #"(?i)\bSeason\s*(\d{1,2})\s*[,._-]?\s*Episode\s*(\d{1,3})\b"#
    )
    // Episode 5, Ep. 5, Ep 05, /episode-5/
    private static let episodeOnlyRegex = try! NSRegularExpression(
        pattern: #"(?i)(?:\b(?:Episode|Ep\.?)\s*(\d{1,3})\b|/episode-(\d{1,3})(?:/|\.|$))"#
    )

    // Common junk site suffixes
    private static let junkSuffixes = [
        try! NSRegularExpression(pattern: #"(?i)\s*[-|–—]\s*(?:Watch\s+(?:Online|Free)|Watch\s+.*|Free\s+Streaming|Full\s+Movie|Stream|HD|1080p|720p|Putlocker|Fmovies|123movies|Goku).*$"#),
        try! NSRegularExpression(pattern: #"(?i)\s*\|\s*.*$"#),
        try! NSRegularExpression(pattern: #"(?i)\s*\[(?:1080p|720p|4k|HDR|WEBRip|BluRay|HD)\]"#),
        try! NSRegularExpression(pattern: #"(?i)\s*[-–—]\s*Official\s+Site.*$"#)
    ]

    public static func parse(rawTitle: String, url: String = "") -> ParsedMediaInfo {
        var cleanTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        for pattern in junkSuffixes {
            let range = NSRange(location: 0, length: (cleanTitle as NSString).length)
            cleanTitle = pattern.stringByReplacingMatches(
                in: cleanTitle,
                range: range,
                withTemplate: ""
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let nsTitle = cleanTitle as NSString
        let fullRange = NSRange(location: 0, length: nsTitle.length)

        // 1. Try S02E05
        if let match = seRegex.firstMatch(in: cleanTitle, range: fullRange) {
            let season = Int(nsTitle.substring(with: match.range(at: 1)))
            let episode = Int(nsTitle.substring(with: match.range(at: 2)))
            let seriesKey = extractSeriesTitle(from: cleanTitle, matchRange: match.range)
            return ParsedMediaInfo(
                title: cleanTitle,
                seriesKey: seriesKey.isEmpty ? nil : seriesKey,
                season: season,
                episode: episode
            )
        }

        // 2. Try 2x05
        if let match = xRegex.firstMatch(in: cleanTitle, range: fullRange) {
            let season = Int(nsTitle.substring(with: match.range(at: 1)))
            let episode = Int(nsTitle.substring(with: match.range(at: 2)))
            let seriesKey = extractSeriesTitle(from: cleanTitle, matchRange: match.range)
            return ParsedMediaInfo(
                title: cleanTitle,
                seriesKey: seriesKey.isEmpty ? nil : seriesKey,
                season: season,
                episode: episode
            )
        }

        // 3. Try Season X Episode Y
        if let match = seasonEpisodeTextRegex.firstMatch(in: cleanTitle, range: fullRange) {
            let season = Int(nsTitle.substring(with: match.range(at: 1)))
            let episode = Int(nsTitle.substring(with: match.range(at: 2)))
            let seriesKey = extractSeriesTitle(from: cleanTitle, matchRange: match.range)
            return ParsedMediaInfo(
                title: cleanTitle,
                seriesKey: seriesKey.isEmpty ? nil : seriesKey,
                season: season,
                episode: episode
            )
        }

        // 4. Try Episode only in Title
        if let match = episodeOnlyRegex.firstMatch(in: cleanTitle, range: fullRange) {
            let ep1 = match.range(at: 1).location != NSNotFound ? nsTitle.substring(with: match.range(at: 1)) : ""
            let ep2 = match.range(at: 2).location != NSNotFound ? nsTitle.substring(with: match.range(at: 2)) : ""
            let epStr = ep1.isEmpty ? ep2 : ep1
            let episode = Int(epStr)
            let seriesKey = extractSeriesTitle(from: cleanTitle, matchRange: match.range)
            return ParsedMediaInfo(
                title: cleanTitle,
                seriesKey: seriesKey.isEmpty ? nil : seriesKey,
                season: 1, // Default to Season 1
                episode: episode
            )
        }

        // 5. Try Episode only in URL if available
        if !url.isEmpty {
            let nsUrl = url as NSString
            let urlRange = NSRange(location: 0, length: nsUrl.length)
            if let match = episodeOnlyRegex.firstMatch(in: url, range: urlRange) {
                let ep1 = match.range(at: 1).location != NSNotFound ? nsUrl.substring(with: match.range(at: 1)) : ""
                let ep2 = match.range(at: 2).location != NSNotFound ? nsUrl.substring(with: match.range(at: 2)) : ""
                let epStr = ep1.isEmpty ? ep2 : ep1
                let episode = Int(epStr)
                return ParsedMediaInfo(
                    title: cleanTitle,
                    seriesKey: cleanTitle.isEmpty ? nil : cleanTitle,
                    season: 1,
                    episode: episode
                )
            }
        }

        // 6. Standalone Movie or Single Video
        return ParsedMediaInfo(
            title: cleanTitle.isEmpty ? "Untitled Video" : cleanTitle,
            seriesKey: nil,
            season: nil,
            episode: nil
        )
    }

    private static func extractSeriesTitle(from fullTitle: String, matchRange: NSRange) -> String {
        let nsTitle = fullTitle as NSString
        let prefix = nsTitle.substring(to: matchRange.location)
        var cleaned = prefix.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip trailing separators like - : _
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " -:_|,/"))
        return cleaned
    }
}
