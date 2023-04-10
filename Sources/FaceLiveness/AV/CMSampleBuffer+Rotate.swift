//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import AVFoundation
import CoreImage

extension CMSampleBuffer {
    func rotateRightUpMirrored() -> CVPixelBuffer? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(self) else {
            return nil
        }

        var cvPixelBufferPtr: CVPixelBuffer?

        let error = CVPixelBufferCreate(
            kCFAllocatorDefault,
            CVPixelBufferGetHeight(pixelBuffer),
            CVPixelBufferGetWidth(pixelBuffer),
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            nil,
            &cvPixelBufferPtr
        )

        guard error == kCVReturnSuccess,
              let cvPixelBuffer = cvPixelBufferPtr
        else {
            return nil
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            .oriented(.right)
            .oriented(.upMirrored)

        let context = CIContext(options: nil)
        context.render(ciImage, to: cvPixelBuffer)
        return cvPixelBuffer
    }
}
