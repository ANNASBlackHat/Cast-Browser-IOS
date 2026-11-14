//
//  SavedDeviceManager.swift
//  CastBrowser
//

import Foundation

public struct SavedDeviceModel: Codable, Sendable {
    public let id: String
    public let name: String
    public let modelName: String?
    public let controlUrlString: String?
    public let hostOrIp: String?
    public let lastConnectedAt: Date
}

public enum SavedDeviceManager {
    private static let key = "castbrowser_last_dlna_device"

    public static func saveDevice(_ device: CastDevice) {
        let host = device.controlUrl?.host
        let model = SavedDeviceModel(
            id: device.id,
            name: device.name,
            modelName: device.modelName,
            controlUrlString: device.controlUrl?.absoluteString,
            hostOrIp: host,
            lastConnectedAt: Date()
        )
        if let data = try? JSONEncoder().encode(model) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    public static func getLastDevice() -> CastDevice? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let model = try? JSONDecoder().decode(SavedDeviceModel.self, from: data) else {
            return nil
        }
        let controlUrl = model.controlUrlString.flatMap { URL(string: $0) }
        return CastDevice(
            id: model.id,
            name: model.name,
            modelName: model.modelName,
            protocolType: .dlna,
            controlUrl: controlUrl
        )
    }

    public static func getLastDeviceHostOrIp() -> String? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let model = try? JSONDecoder().decode(SavedDeviceModel.self, from: data) else {
            return nil
        }
        return model.hostOrIp
    }
}
