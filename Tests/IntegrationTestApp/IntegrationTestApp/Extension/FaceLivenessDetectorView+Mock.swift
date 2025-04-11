//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
import protocol AWSPluginsCore.AWSCredentialsProvider
import AVFoundation
@testable import FaceLiveness

extension FaceLivenessDetectorView {
    static func getMockFaceLivenessDetectorView (
        sessionID: String,
        credentialsProvider: AWSCredentialsProvider? = nil,
        region: String,
        isPresented: Binding<Bool>,
        onCompletion: @escaping (Result<Void, FaceLivenessDetectionError>) -> Void
    ) -> FaceLivenessDetectorView {

        let avCaptureDevice = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front
        ).devices.first
        let captureDevice = LivenessCaptureDevice(avCaptureDevice: avCaptureDevice)
        
        let faceDetector = try! FaceDetectorShortRange.Model()

        let videoChunker = VideoChunker(
            assetWriter: LivenessAVAssetWriter(),
            assetWriterDelegate: VideoChunker.AssetWriterDelegate(),
            assetWriterInput: LivenessAVAssetWriterInput()
        )
        
        let outputDelegate = OutputSampleBufferCapturer(faceDetector: faceDetector, videoChunker: videoChunker
        )
        let inputUrl = Bundle.main.url(forResource: "mock", withExtension: "mov")!
        let captureSession = MockLivenessCaptureSession(captureDevice: captureDevice, outputDelegate: outputDelegate, inputFile: inputUrl)
        let detectorView = FaceLivenessDetectorView(sessionID: sessionID, region: region, isPresented: isPresented, onCompletion: onCompletion, captureSession: captureSession)
        
        return detectorView
    }
}
