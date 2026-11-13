//
//  AirPlayRoutePicker.swift
//  CastBrowser
//

import SwiftUI
import AVKit

public struct AirPlayRoutePicker: UIViewRepresentable {
    public var tintColor: UIColor = .systemBlue
    public var activeTintColor: UIColor = .systemBlue

    public init(tintColor: UIColor = .systemBlue, activeTintColor: UIColor = .systemBlue) {
        self.tintColor = tintColor
        self.activeTintColor = activeTintColor
    }

    public func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.backgroundColor = .clear
        picker.activeTintColor = activeTintColor
        picker.tintColor = tintColor
        picker.prioritizesVideoDevices = true
        return picker
    }

    public func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = tintColor
        uiView.activeTintColor = activeTintColor
    }
}
