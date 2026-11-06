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
    /// What the detector measured on a frame, delivered before the frame's result.
    func process(frameReport: FaceDetectionFrameReport)
}

extension FaceDetectionResultHandler {
    func process(frameReport: FaceDetectionFrameReport) {}
}

protocol FaceDetectionSessionConfigurationWrapper: AnyObject {
    var sessionConfiguration: FaceLivenessSession.SessionConfiguration? { get }
}

enum FaceDetectionResult {
    case noFace
    case singleFace(DetectedFace)
    case multipleFaces
}

/// What the detector measured on one frame, for diagnostics.
struct FaceDetectionFrameReport {
    var faceCount = 0
    /// The highest detection score on the frame, including scores below the threshold.
    var topScore: Float = 0
    /// Whether the session's detection threshold was used, rather than the fallback.
    var usedSessionThreshold = false
    var failure: FrameAnalysisFailure?
}

/// Why a frame couldn't be analyzed.
struct FrameAnalysisFailure {
    enum Stage: String {
        case noImageBuffer, imageConversion, inputCreation, prediction, missingLandmarks, missingScores
    }

    let stage: Stage
    let cause: Error?
}
