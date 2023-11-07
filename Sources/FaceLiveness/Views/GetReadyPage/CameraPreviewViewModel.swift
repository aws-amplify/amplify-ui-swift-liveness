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

class CameraPreviewViewModel: NSObject, ObservableObject {
    @Published var currentImageFrame: CGImage?
    @Published var buffer: CVPixelBuffer?
    
    var previewCaptureSession: LivenessCaptureSession?
    
    override init() {
        super.init()
        setupSubscriptions()
        
        let avCpatureDevice = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front
        ).devices.first

        self.previewCaptureSession = LivenessCaptureSession(
            captureDevice: .init(avCaptureDevice: avCpatureDevice),
            outputDelegate: self
        )
        
        do {
            try self.previewCaptureSession?.startSession()
        } catch {
            print("Error starting preview camera session: \(error)")
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
}

extension CameraPreviewViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if let buffer = sampleBuffer.imageBuffer {
            DispatchQueue.main.async {
                self.buffer = buffer
            }
        }
    }
}
