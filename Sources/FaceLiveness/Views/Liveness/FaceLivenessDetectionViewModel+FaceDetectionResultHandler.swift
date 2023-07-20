//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SwiftUI
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

fileprivate let initialFaceDistanceThreshold: CGFloat = 0.32

extension FaceLivenessDetectionViewModel: FaceDetectionResultHandler {
    func process(newResult: FaceDetectionResult) {
        switch newResult {
        case .noFace:
            if case .pendingFacePreparedConfirmation = livenessState.state {
                DispatchQueue.main.async {
                    self.livenessState.faceNotPrepared(reason: .noFace)
                }
            }
        case .multipleFaces:
            if case .pendingFacePreparedConfirmation = livenessState.state {
                DispatchQueue.main.async {
                    self.livenessState.faceNotPrepared(reason: .multipleFaces)
                }
            }
        case .singleFace(let face):
            var normalizedFace = normalizeFace(face)
            normalizedFace.boundingBox = normalizedFace.boundingBoxFromLandmarks()

            switch livenessState.state {
            case .pendingFacePreparedConfirmation:
                if face.faceDistance <= initialFaceDistanceThreshold {
                        DispatchQueue.main.async {
                            self.livenessState.awaitingRecording()
                            self.initializeLivenessStream()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.livenessState.beginRecording()
                        }
                    return
                } else {
                    DispatchQueue.main.async {
                        self.livenessState.faceNotPrepared(reason: .faceTooClose)
                    }
                    return
                }
            case .recording(ovalDisplayed: false):
                drawOval(onComplete: {
                    self.sendInitialFaceDetectedEvent(
                        initialFace: normalizedFace.boundingBox,
                        videoStartTime: Date().timestampMilliseconds
                    )
                })
            case .recording(ovalDisplayed: true):
                guard let sessionConfiguration = sessionConfiguration else { return }
                let instruction = faceInOvalMatching.faceMatchState(
                    for: normalizedFace.boundingBox,
                    in: ovalRect,
                    challengeConfig: sessionConfiguration.ovalMatchChallenge
                )

                handleInstruction(
                    instruction,
                    colorSequences: sessionConfiguration.colorChallenge.colors
                )
            case .awaitingFaceInOvalMatch:
                guard let sessionConfiguration = sessionConfiguration else { return }
                let instruction = faceInOvalMatching.faceMatchState(
                    for: normalizedFace.boundingBox,
                    in: ovalRect,
                    challengeConfig: sessionConfiguration.ovalMatchChallenge
                )
                handleInstruction(
                    instruction,
                    colorSequences: sessionConfiguration.colorChallenge.colors
                )
            default: break

            }
        }
    }

    func handleNoMatch(instruction: Instructor.Instruction, percentage: Double) {
        let noMatchTimeoutInterval: TimeInterval = 7
        self.livenessState.awaitingFaceMatch(with: instruction, nearnessPercentage: percentage)
        if noMatchStartTime == nil {
            noMatchStartTime = Date()
        }
        if let elapsedTime = noMatchStartTime?.timeIntervalSinceNow, abs(elapsedTime) >= noMatchTimeoutInterval {
            self.livenessState
                .unrecoverableStateEncountered(.timedOut)
            self.captureSession.stopRunning()
            return
        }
    }

    func handleInstruction(
        _ instruction: Instructor.Instruction,
        colorSequences: [FaceLivenessSession.DisplayColor]
    ) {
        DispatchQueue.main.async {
            switch instruction {
            case .match:
                self.livenessState.faceMatched()
                self.faceMatchedTimestamp = Date().timestampMilliseconds
                self.livenessViewControllerDelegate?.displayFreshness(colorSequences: colorSequences)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                self.noMatchStartTime = nil

            case .tooClose(_, let percentage),
                    .tooFar(_, let percentage),
                    .tooFarLeft(_, let percentage),
                    .tooFarRight(_, let percentage):
                self.handleNoMatch(instruction: instruction, percentage: percentage)
            default: break
            }
        }
    }
}
