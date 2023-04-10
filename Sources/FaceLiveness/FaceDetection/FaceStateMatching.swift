//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import UIKit
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin
import Amplify

struct FaceInOvalMatching {
    let instructor: Instructor
    private let storage = Storage()
    class Storage {
        var initialIOU: Double?
    }

    func faceMatchState(
        for face: CGRect,
        in ovalRect: CGRect?,
        challengeConfig: FaceLivenessSession.OvalMatchChallenge
    ) -> Instructor.Instruction {
        guard let oval = ovalRect else {
            return .none
        }

        let intersection = intersectionOverUnion(boxA: face, boxB: oval)
        let thresholds = Thresholds(oval: oval, challengeConfig: challengeConfig)

        if storage.initialIOU == nil {
            storage.initialIOU = intersection
        }

        let initialIOU = storage.initialIOU!

        let faceMatchPercentage = calculateFaceMatchPercentage(
            intersection: intersection,
            initialIOU: initialIOU,
            thresholds: thresholds
        )

        let update: Instructor.Instruction

        if isMatch(face: face, oval: oval, intersection: intersection, thresholds: thresholds) {
            update = .match
        } else if isTooClose(face: face, oval: oval, intersection: intersection, thresholds: thresholds) {
            update = .tooClose(nearnessPercentage: faceMatchPercentage)
        } else {
            update = .tooFar(nearnessPercentage: faceMatchPercentage)
        }

        let instruction = instructor.instruction(for: update)
        return instruction
    }

    private func isTooClose(face: CGRect, oval: CGRect, intersection: Double, thresholds: Thresholds) -> Bool {
        oval.minY - face.minY > thresholds.faceDetectionHeight
        || face.maxY - oval.maxY > thresholds.faceDetectionHeight
        || (oval.minX - face.minX > thresholds.faceDetectionWidth && face.maxX - oval.maxX > thresholds.faceDetectionWidth)
    }

    private func isMatch(face: CGRect, oval: CGRect, intersection: Double, thresholds: Thresholds) -> Bool {
        intersection > thresholds.intersection
        && abs(oval.minX - face.minX) < thresholds.ovalMatchWidth
        && abs(oval.maxX - face.maxX) < thresholds.ovalMatchWidth
        && abs(oval.maxY - face.maxY) < thresholds.ovalMatchHeight
    }

    private func calculateFaceMatchPercentage(intersection: Double, initialIOU: Double, thresholds: Thresholds) -> Double {
        var faceMatchPercentage = (0.75 * (intersection - initialIOU)) / (thresholds.intersection - initialIOU) + 0.25
        faceMatchPercentage = max(min(1, faceMatchPercentage), 0)
        return faceMatchPercentage
    }

    private func intersectionOverUnion(boxA: CGRect, boxB: CGRect) -> Double {
        let xA = max(boxA.minX, boxB.minX)
        let yA = max(boxA.minY, boxB.minY)
        let xB = min(boxA.maxX, boxB.maxX)
        let yB = min(boxA.maxY, boxB.maxY)

        let intersectionArea = abs(max(0, xB - xA) * max(0, yB - yA))
        if intersectionArea == 0 { return 0 }

        let boxAArea = (boxA.maxY - boxA.minY) * (boxA.maxX - boxA.minX)
        let boxBArea = (boxB.maxY - boxB.minY) * (boxB.maxX - boxB.minX)

        return intersectionArea / (boxAArea + boxBArea - intersectionArea)
    }
}

extension FaceInOvalMatching {
    struct Thresholds {
        let intersection: Double
        let ovalMatchWidth: Double
        let ovalMatchHeight: Double
        let faceDetectionWidth: Double
        let faceDetectionHeight: Double

        init(oval: CGRect, challengeConfig: FaceLivenessSession.OvalMatchChallenge) {
            intersection = challengeConfig.oval.iouThreshold
            ovalMatchWidth = oval.width * challengeConfig.oval.iouWidthThreshold
            ovalMatchHeight = oval.height * challengeConfig.oval.iouHeightThreshold
            faceDetectionWidth = oval.width * challengeConfig.face.iouWidthThreshold
            faceDetectionHeight = oval.height * challengeConfig.face.iouHeightThreshold
        }
    }
}
