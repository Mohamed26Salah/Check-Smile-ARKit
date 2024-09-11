//
//  FaceDetectionViewModel.swift
//  CheckSmile
//
//  Created by Mohamed Salah on 11/09/2024.
//

import Foundation
import RealityKit
import ARKit
import Vision
import SwiftUI

enum IsSmiling {
    case angry, noSmile, simpleSmile, smiling
    
    var currentSmileCase: String {
        switch self {
        case .angry:
            return "😠 Angry"
        case .noSmile:
            return "😐 Not Smilling"
        case .simpleSmile:
            return "🙂 Simple Smile"
        case .smiling:
            return "😁 Smilling"
        }
    }
}

class FaceDetectionViewModel: UIViewController, ObservableObject {
    @Published var smileRight: Float = 0
    @Published var smileLeft: Float = 0
    @Published var numberOfFaces: Int = 0
    @Published var faceDetected: Bool = false
    
    private var isSessionRunning: Bool = false
    private var faceDetectionRequest: VNRequest?
    private(set) var arView: ARView
    
    var isSmiling: IsSmiling {
        let smileValue = (smileLeft + smileRight) / 2.0
        switch smileValue {
        case _ where smileValue > 0.5: return .smiling
        case _ where smileValue > 0.2: return .simpleSmile
        case _ where smileValue > 0.0: return .noSmile
        default: return .angry
        }
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        arView = ARView(frame: .zero)
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setupFaceDetection()
        setupNotifications()
        startSessionDelegate()
        startSession()
    }
    
    required init?(coder: NSCoder) {
        arView = ARView(frame: .zero)
        super.init(coder: coder)
        setupFaceDetection()
        setupNotifications()
        startSessionDelegate()
        startSession()
    }
    
    deinit {
        stopSession()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    @objc private func handleAppDidBecomeActive() {
        resumeSession()
    }
    
    @objc private func handleAppWillResignActive() {
        pauseSession()
    }
    
    @objc private func handleAppDidEnterBackground() {
        pauseSession()
    }
    
    func startSessionDelegate() {
        arView.session.delegate = self
    }
    
    func startSession() {
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isSessionRunning = true
    }
    
    func pauseSession() {
        arView.session.pause()
        isSessionRunning = false
    }
    
    func resumeSession() {
        if !isSessionRunning {
            startSession()
        }
    }
    
    func stopSession() {
        arView.session.pause()
        arView.session.delegate = nil
        arView.scene.anchors.removeAll()
        isSessionRunning = false
    }
    
    func captureImage(completion: @escaping (UIImage?) -> Void) {
        guard let currentFrame = arView.session.currentFrame else {
            print("Failed to get current frame")
            return
        }
        let pixelBuffer = currentFrame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("Failed to create CGImage")
            return
        }
        let uiImage = UIImage(cgImage: cgImage)
        completion(uiImage)
    }
    
    private func setupFaceDetection() {
        faceDetectionRequest = VNDetectFaceRectanglesRequest { [weak self] (request, error) in
            guard let self = self else { return }
            if let results = request.results as? [VNFaceObservation], !results.isEmpty {
                self.handleFaceDetectionResults(observedFaces: results)
            } else {
                DispatchQueue.main.async {
                    self.numberOfFaces = 0
                    self.faceDetected = false
                }
            }
        }
    }
    
    private func handleFaceDetectionResults(observedFaces: [VNFaceObservation]) {
        DispatchQueue.main.async {
            let validFaceCount = observedFaces.filter { faceObservation in
                let faceBoundingBox = self.convertToScreenCoordinates(faceObservation.boundingBox)
                let isFaceSufficientlyLarge = faceBoundingBox.size.width > self.arView.bounds.width * 0.2 &&
                faceBoundingBox.size.height > self.arView.bounds.height * 0.2
                let faceCenter = CGPoint(x: faceBoundingBox.midX, y: faceBoundingBox.midY)
                let frameCenter = CGPoint(x: self.arView.bounds.width / 2, y: self.arView.bounds.height / 2)
                let isFaceCentered = hypot(faceCenter.x - frameCenter.x, faceCenter.y - frameCenter.y) < self.arView.bounds.width * 0.3
                let isFaceStraight = abs(faceObservation.yaw?.floatValue ?? 0.0) < 0.2
                let isFaceInBounds = self.arView.bounds.contains(faceBoundingBox)
                return isFaceSufficientlyLarge && isFaceCentered && isFaceStraight && isFaceInBounds
            }.count
            
            self.numberOfFaces = validFaceCount
            self.faceDetected = validFaceCount > 0
        }
    }
    
    private func convertToScreenCoordinates(_ boundingBox: CGRect) -> CGRect {
        let x = boundingBox.origin.x * arView.bounds.width
        let y = (1 - boundingBox.origin.y - boundingBox.size.height) * arView.bounds.height
        let width = boundingBox.size.width * arView.bounds.width
        let height = boundingBox.size.height * arView.bounds.height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

extension FaceDetectionViewModel: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let faceDetectionRequest = faceDetectionRequest else { return }
        let pixelBuffer = frame.capturedImage
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? requestHandler.perform([faceDetectionRequest])
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        if let faceAnchor = anchors.first as? ARFaceAnchor {
            smileRight = Float(truncating: faceAnchor.blendShapes[.mouthSmileRight] ?? 0)
            smileLeft = Float(truncating: faceAnchor.blendShapes[.mouthSmileLeft] ?? 0)
        }
    }
}
