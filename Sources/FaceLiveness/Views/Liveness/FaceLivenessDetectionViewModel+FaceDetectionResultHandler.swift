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
fileprivate let countdownFaceDistanceThreshold: CGFloat = 0.37

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
                        self.livenessState.startCountdown()
                        self.initializeLivenessStream()
                    }
                    return
                } else {
                    DispatchQueue.main.async {
                        self.livenessState.faceNotPrepared(reason: .faceTooClose)
                    }
                    return
                }
            case .countingDown:
                if face.faceDistance >= countdownFaceDistanceThreshold {
                    DispatchQueue.main.async {
                        self.livenessState.unrecoverableStateEncountered(
                            .invalidFaceMovementDuringCountdown
                        )
                    }
                }
            case .recording(ovalDisplayed: false):
                drawOval()
                sendInitialFaceDetectedEvent(
                    initialFace: normalizedFace.boundingBox,
                    videoStartTime: Date().timestampMilliseconds
                )
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
        self.livenessState.awaitingFaceMatch(with: instruction, nearnessPercentage: percentage)
        noMatchCount += 1
        if noMatchCount >= 210 {
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
                self.noMatchCount = 0

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
