//
//  CastDevice.swift
//  CastBrowser
//

import Foundation

public enum CastProtocol: String, Codable, Sendable {
    case airplay = "AirPlay"
    case dlna = "DLNA"
}

public struct CastDevice: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let modelName: String?
    public let protocolType: CastProtocol
    public let controlUrl: URL?

    public init(
        id: String,
        name: String,
        modelName: String? = nil,
        protocolType: CastProtocol,
        controlUrl: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.modelName = modelName
        self.protocolType = protocolType
        self.controlUrl = controlUrl
    }
}
