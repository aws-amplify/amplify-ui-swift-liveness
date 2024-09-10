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
            guard let sessionConfiguration = sessionConfiguration else { return }
            normalizedFace.boundingBox = normalizedFace.boundingBoxFromLandmarks(ovalRect: ovalRect,
                                                                                 ovalMatchChallenge: sessionConfiguration.ovalMatchChallenge)

            switch livenessState.state {
            case .pendingFacePreparedConfirmation:
                if face.faceDistance <= sessionConfiguration.ovalMatchChallenge.face.distanceThreshold {
                        DispatchQueue.main.async {
                            self.livenessState.awaitingRecording()
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
                let instruction = faceInOvalMatching.faceMatchState(
                    for: normalizedFace.boundingBox,
                    in: ovalRect,
                    challengeConfig: sessionConfiguration.ovalMatchChallenge
                )

                handleInstruction(
                    instruction,
                    colorSequences: sessionConfiguration.colorChallenge?.colors
                )
            case .awaitingFaceInOvalMatch:
                let instruction = faceInOvalMatching.faceMatchState(
                    for: normalizedFace.boundingBox,
                    in: ovalRect,
                    challengeConfig: sessionConfiguration.ovalMatchChallenge
                )

                handleInstruction(
                    instruction,
                    colorSequences: sessionConfiguration.colorChallenge?.colors
                )
            default: break

            }
        }
    }

    func handleNoFaceFit(instruction: Instructor.Instruction, percentage: Double) {
        self.livenessState.awaitingFaceMatch(with: instruction, nearnessPercentage: percentage)
        if noFitStartTime == nil {
            noFitStartTime = Date()
        }
        if let elapsedTime = noFitStartTime?.timeIntervalSinceNow, abs(elapsedTime) >= noFitTimeoutInterval {
            handleSessionTimedOut()
        }
    }
    
    func handleNoFaceDetected() {
        if noFitStartTime == nil {
            noFitStartTime = Date()
        }
        if let elapsedTime = noFitStartTime?.timeIntervalSinceNow, abs(elapsedTime) >= noFitTimeoutInterval {
            handleSessionTimedOut()
        }
    }

    func handleInstruction(
        _ instruction: Instructor.Instruction,
        colorSequences: [FaceLivenessSession.DisplayColor]?
    ) {
        DispatchQueue.main.async {
            switch instruction {
            case .match:
                self.livenessState.faceMatched()
                self.faceMatchedTimestamp = Date().timestampMilliseconds
                
                // next step after face match
                switch self.challengeReceived?.type {
                case .faceMovementAndLightChallenge:
                    if let colorSequences = colorSequences {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.livenessViewControllerDelegate?.displayFreshness(colorSequences: colorSequences)
                        }
                    }
                case .faceMovementChallenge:
                    self.livenessViewControllerDelegate?.completeNoLightCheck()
                default:
                    break
                }

                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                self.noFitStartTime = nil

            case .tooClose(_, let percentage),
                    .tooFar(_, let percentage),
                    .tooFarLeft(_, let percentage),
                    .tooFarRight(_, let percentage):
                self.handleNoFaceFit(instruction: instruction, percentage: percentage)
            case .none:
                self.handleNoFaceDetected()
            }
        }
    }
    
    private func handleSessionTimedOut() {
        noFitStartTime = nil
        DispatchQueue.main.async {
            self.livenessState
                .unrecoverableStateEncountered(.timedOut)
            self.captureSession?.stopRunning()
        }
    }
}
