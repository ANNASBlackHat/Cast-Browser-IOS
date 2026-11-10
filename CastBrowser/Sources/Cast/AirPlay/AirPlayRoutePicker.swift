//
//  AirPlayRoutePicker.swift
//  CastBrowser
//

import SwiftUI
import AVKit

public struct AirPlayRoutePicker: UIViewRepresentable {
    public init() {}

    public func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.backgroundColor = .clear
        picker.activeTintColor = .systemBlue
        picker.tintColor = .secondaryLabel
        picker.prioritizesVideoDevices = true
        return picker
    }

    public func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
