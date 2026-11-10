//
//  CastDeviceItem.swift
//  CastBrowser
//

import Foundation
import SwiftData

@Model
public final class CastDeviceItem {
    @Attribute(.unique) public var id: String
    public var friendlyName: String
    public var modelName: String?
    public var locationUrl: String?
    public var protocolType: String
    public var lastSeenAt: Date

    public init(
        id: String,
        friendlyName: String,
        modelName: String? = nil,
        locationUrl: String? = nil,
        protocolType: String = "airplay",
        lastSeenAt: Date = Date()
    ) {
        self.id = id
        self.friendlyName = friendlyName
        self.modelName = modelName
        self.locationUrl = locationUrl
        self.protocolType = protocolType
        self.lastSeenAt = lastSeenAt
    }
}
