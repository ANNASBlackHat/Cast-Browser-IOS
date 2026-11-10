//
//  DetectedSubtitle.swift
//  CastBrowser
//

import Foundation

public struct DetectedSubtitle: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let label: String
    public let language: String

    public init(
        id: UUID = UUID(),
        url: URL,
        label: String = "Subtitle",
        language: String = ""
    ) {
        self.id = id
        self.url = url
        self.label = label
        self.language = language
    }
}
