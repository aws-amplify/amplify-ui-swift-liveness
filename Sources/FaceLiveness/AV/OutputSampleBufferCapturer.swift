//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import AVFoundation
import CoreImage

class OutputSampleBufferCapturer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let faceDetector: FaceDetector
    let videoChunker: VideoChunker
    /// Set while the get ready screen shows this session's camera; its frames go there instead
    /// of to the check.
    let previewFrameHandler = Synchronized<((CVImageBuffer) -> Void)?>(nil)

    init(faceDetector: FaceDetector, videoChunker: VideoChunker) {
        self.faceDetector = faceDetector
        self.videoChunker = videoChunker
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        handle(sampleBuffer)
    }

    func handle(_ sampleBuffer: CMSampleBuffer) {
        if let previewFrameHandler = previewFrameHandler.value {
            if let imageBuffer = sampleBuffer.imageBuffer {
                previewFrameHandler(imageBuffer)
            }
            return
        }

        videoChunker.consume(sampleBuffer)

        guard let imageBuffer = sampleBuffer.imageBuffer
        else { return }

        faceDetector.detectFaces(from: imageBuffer)
    }
}
