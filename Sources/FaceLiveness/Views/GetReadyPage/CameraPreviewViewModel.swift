//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import CoreImage
import Combine
import AVFoundation
import Amplify

class CameraPreviewViewModel: NSObject, ObservableObject {
    @Published var currentImageFrame: CGImage?
    @Published var buffer: CVPixelBuffer?
    
    var previewCaptureSession: LivenessCaptureSession?
    let cameraPosition: LivenessCamera
    
    init(cameraPosition: LivenessCamera) {
        self.cameraPosition = cameraPosition
        
        super.init()
        setupSubscriptions()
        
        let avCaptureDevice = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: cameraPosition == .front ? .front : .back
        ).devices.first

        let outputDelegate = CameraPreviewOutputSampleBufferDelegate { [weak self] buffer in
            self?.updateBuffer(buffer)
        }

        self.previewCaptureSession = LivenessCaptureSession(
            captureDevice: .init(avCaptureDevice: avCaptureDevice),
            outputDelegate: outputDelegate
        )
        
        do {
            try previewCaptureSession?.configureCamera()
            previewCaptureSession?.startSession()
        } catch {
            Amplify.Logging.default.error("Error starting preview capture session with error: \(error)")
        }
    }

    func setupSubscriptions() {
        self.$buffer
            .receive(on: RunLoop.main)
            .compactMap {
                return CGImage.convert(from: $0)
            }
            .assign(to: &$currentImageFrame)
    }

    func stopSession() {
        previewCaptureSession?.stopRunning()
    }

    func updateBuffer(_ buffer: CVImageBuffer) {
        DispatchQueue.main.async {
            self.buffer = buffer
        }
    }
}
