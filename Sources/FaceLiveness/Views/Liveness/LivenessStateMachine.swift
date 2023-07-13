//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Amplify
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

struct LivenessStateMachine {
    private(set) var state: State
    private let log = Amplify.Logging.logger(forCategory: "LivenessStateMachine")

    init(state: LivenessStateMachine.State) {
        self.state = state
    }

    mutating func checkIsFacePrepared() {
        log.verbose(#function)
        guard case .initial = state else { return }
        state = .pendingFacePreparedConfirmation(.pendingCheck)
    }

    mutating func faceNotPrepared(reason: FaceNotPreparedReason) {
        log.verbose("\(#function) - reason: \(reason)")
        guard case .pendingFacePreparedConfirmation = state else { return }
        state = .pendingFacePreparedConfirmation(reason)
    }

    mutating func awaitingFaceMatch(
        with instruction: Instructor.Instruction,
        nearnessPercentage: Double
    ) {
        log.verbose("\(#function) - instruction: \(instruction)")
        let reason: FaceNotPreparedReason
        let percentage: Double
        switch instruction {
        case .tooFar(_, let nearnessPercentage):
            reason = .moveFaceCloser
            percentage = nearnessPercentage
        case .tooFarLeft(_, let nearnessPercentage):
            reason = .moveFaceLeft
            percentage = nearnessPercentage
        case .tooFarRight(_, let nearnessPercentage):
            reason = .moveFaceRight
            percentage = nearnessPercentage
        case .tooClose(_, let nearnessPercentage):
            reason = .faceTooClose
            percentage = nearnessPercentage
        default: return
        }

        state = .awaitingFaceInOvalMatch(reason, percentage)
    }

    mutating func awaitingRecording() {
        log.verbose(#function)
        guard case .pendingFacePreparedConfirmation = state else { return }
        state = .waitForRecording
    }
    
    mutating func unrecoverableStateEncountered(_ error: LivenessError) {
        log.verbose("\(#function) error: \(error)")
        switch state {
        case .encounteredUnrecoverableError, .completed:
            return
        default:
            state = .encounteredUnrecoverableError(error)
        }
    }

    mutating func beginRecording() {
        log.verbose(#function)
        state = .recording(ovalDisplayed: false)
    }

    mutating func ovalDisplayed() {
        log.verbose(#function)
        state = .recording(ovalDisplayed: true)
    }

    mutating func faceMatched() {
        log.verbose(#function)
        state = .faceMatched
    }

    mutating func completedDisplayingFreshness() {
        log.verbose(#function)
        state = .completedDisplayingFreshness
    }

    mutating func displayingFreshness() {
        log.verbose(#function)
        state = .displayingFreshness
    }

    mutating func complete() {
        log.verbose(#function)
        state = .completed
    }

    var shouldDisplayRecordingIcon: Bool {
        switch state {
        case .initial, .pendingFacePreparedConfirmation, .encounteredUnrecoverableError:
            return false
        default: return true
        }
    }

    enum State: Equatable {
        case initial
        case pendingFacePreparedConfirmation(FaceNotPreparedReason)
        case recording(ovalDisplayed: Bool)
        case awaitingFaceInOvalMatch(FaceNotPreparedReason, Double)
        case faceMatched
        case initialClientInfoEventSent
        case displayingFreshness
        case completedDisplayingFreshness
        case completed
        case awaitingDisconnectEvent
        case disconnectEventReceived
        case encounteredUnrecoverableError(LivenessError)
        case waitForRecording
    }

    enum FaceNotPreparedReason: String, Equatable {
        case pendingCheck = ""
        case notInOval = "Move face to fit in oval"
        case moveFaceCloser = "Move closer"
        case moveFaceRight = "Move face right"
        case moveFaceLeft = "Move face left"
        case moveToDimmerArea = "Move to dimmer area"
        case moveToBrighterArea = "Move to brighter area"
        case noFace = "Move face in front of camera"
        case multipleFaces = "Ensure only one face is in front of camera"
        case faceTooClose = "Move face farther away"
    }

    struct LivenessError: Error, Equatable {
        let code: UInt8

        static let unknown = LivenessError(code: 0)
        static let missingVideoPermission = LivenessError(code: 1)
        static let errorWithUnderlyingOSFramework = LivenessError(code: 2)
        static let userCancelled = LivenessError(code: 3)
        static let timedOut = LivenessError(code: 4)
        static let couldNotOpenStream = LivenessError(code: 5)
        static let socketClosed = LivenessError(code: 6)
        static let invalidFaceMovementDuringCountdown = LivenessError(code: 7)

        static func == (lhs: LivenessError, rhs: LivenessError) -> Bool {
            lhs.code == rhs.code
        }
    }
}
