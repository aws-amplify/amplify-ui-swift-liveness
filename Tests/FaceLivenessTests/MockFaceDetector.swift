//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import AVFoundation
@testable import FaceLiveness
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

class MockFaceDetector: FaceDetector {
    func detectFaces(from buffer: CVPixelBuffer) {}
    func setResultHandler(detectionResultHandler: FaceLiveness.FaceDetectionResultHandler) {}
    init() {}
}
