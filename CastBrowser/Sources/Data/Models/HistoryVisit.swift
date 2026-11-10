//
//  HistoryVisit.swift
//  CastBrowser
//

import Foundation
import SwiftData

@Model
public final class HistoryVisit {
    @Attribute(.unique) public var id: UUID
    public var urlString: String
    public var title: String
    public var host: String
    public var visitedAt: Date

    public init(
        id: UUID = UUID(),
        urlString: String,
        title: String,
        host: String = "",
        visitedAt: Date = Date()
    ) {
        self.id = id
        self.urlString = urlString
        self.title = title
        if host.isEmpty, let hostFromUrl = URL(string: urlString)?.host {
            self.host = hostFromUrl
        } else {
            self.host = host
        }
        self.visitedAt = visitedAt
    }
}
