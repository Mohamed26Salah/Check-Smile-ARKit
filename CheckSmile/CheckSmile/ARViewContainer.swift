//
//  ARViewContainer.swift
//  CheckSmile
//
//  Created by Mohamed Salah on 11/09/2024.
//

import Foundation
import SwiftUI
import RealityKit

public struct ARViewContainer: UIViewRepresentable {
    var arViewModel: FaceDetectionViewModel

    public func makeUIView(context: Context) -> ARView {
        return arViewModel.arView
    }

    public func updateUIView(_ uiView: ARView, context: Context) {}
}
