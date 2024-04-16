//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import AVFoundation
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

protocol FaceDetector {
    func detectFaces(from buffer: CVPixelBuffer)
    func setResultHandler(detectionResultHandler: FaceDetectionResultHandler)
}

protocol FaceDetectionResultHandler: AnyObject {
    func process(newResult: FaceDetectionResult)
}

protocol FaceDetectionSessionConfiguration: AnyObject {
    func getFaceDetectionSessionConfiguration() 
        -> FaceLivenessSession.SessionConfiguration?
}

enum FaceDetectionResult {
    case noFace
    case singleFace(DetectedFace)
    case multipleFaces
}
