//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import AVFoundation
@testable import FaceLiveness
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

final class MockFaceDetector {
    var interactions: [String] = []
    var detectionResultHandler: FaceDetectionResultHandler = MockFaceDetectionResultHandler()
}

extension MockFaceDetector: FaceDetector {

    func detectFaces(from buffer: CVPixelBuffer) {
        interactions.append(#function)
    }

    func setResultHandler(detectionResultHandler: FaceDetectionResultHandler) {
        interactions.append("\(#function) (\(type(of: detectionResultHandler)))")
        self.detectionResultHandler = detectionResultHandler
    }
}
