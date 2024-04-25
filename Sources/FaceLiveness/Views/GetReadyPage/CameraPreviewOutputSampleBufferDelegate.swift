//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import AVFoundation
import CoreImage

class CameraPreviewOutputSampleBufferDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    let updateBufferHandler: ((CVImageBuffer) -> Void)

    init(_ updateBufferHandler: @escaping (CVImageBuffer) -> Void) {
        self.updateBufferHandler = updateBufferHandler
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if let buffer = sampleBuffer.imageBuffer {
            updateBufferHandler(buffer)
        }
    }
}
