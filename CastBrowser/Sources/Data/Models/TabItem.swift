//
//  TabItem.swift
//  CastBrowser
//

import Foundation
import SwiftData

@Model
public final class TabItem {
    @Attribute(.unique) public var id: UUID
    public var urlString: String
    public var title: String
    public var orderIndex: Int
    public var isActive: Bool
    public var lastAccessedAt: Date
    public var scrollPositionX: Double
    public var scrollPositionY: Double

    public init(
        id: UUID = UUID(),
        urlString: String = "https://www.google.com",
        title: String = "New Tab",
        orderIndex: Int = 0,
        isActive: Bool = true,
        lastAccessedAt: Date = Date(),
        scrollPositionX: Double = 0.0,
        scrollPositionY: Double = 0.0
    ) {
        self.id = id
        self.urlString = urlString
        self.title = title
        self.orderIndex = orderIndex
        self.isActive = isActive
        self.lastAccessedAt = lastAccessedAt
        self.scrollPositionX = scrollPositionX
        self.scrollPositionY = scrollPositionY
    }
}
