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
    let diagnostics: LivenessSessionDiagnostics?
    /// Set while the get ready screen shows this session's camera; its frames go there instead
    /// of to the check.
    let previewFrameHandler = Synchronized<((CVImageBuffer) -> Void)?>(nil)

    init(faceDetector: FaceDetector, videoChunker: VideoChunker, diagnostics: LivenessSessionDiagnostics? = nil) {
        self.faceDetector = faceDetector
        self.videoChunker = videoChunker
        self.diagnostics = diagnostics
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        handle(sampleBuffer)
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard previewFrameHandler.value == nil else { return }
        diagnostics?.onFrameDropped()
    }

    func handle(_ sampleBuffer: CMSampleBuffer) {
        if let diagnostics, let imageBuffer = sampleBuffer.imageBuffer {
            diagnostics.onCameraFrame(imageBuffer)
        }

        if let previewFrameHandler = previewFrameHandler.value {
            if let imageBuffer = sampleBuffer.imageBuffer {
                previewFrameHandler(imageBuffer)
            }
            return
        }

        diagnostics?.onCheckFrameDelivered()
        videoChunker.consume(sampleBuffer)

        guard let imageBuffer = sampleBuffer.imageBuffer
        else {
            diagnostics?.onAnalyzeError(FrameAnalysisFailure(stage: .noImageBuffer, cause: nil))
            return
        }

        faceDetector.detectFaces(from: imageBuffer)
    }
}
