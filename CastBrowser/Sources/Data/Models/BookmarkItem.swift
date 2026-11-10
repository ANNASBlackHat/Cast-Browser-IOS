//
//  BookmarkItem.swift
//  CastBrowser
//

import Foundation
import SwiftData

@Model
public final class BookmarkItem {
    @Attribute(.unique) public var id: UUID
    public var urlString: String
    public var title: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        urlString: String,
        title: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.urlString = urlString
        self.title = title
        self.createdAt = createdAt
    }
}
