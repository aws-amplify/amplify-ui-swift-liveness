//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

struct LivenessStateMachine {
    private(set) var state: State

    init(state: LivenessStateMachine.State) {
        self.state = state
    }

    mutating func checkIsFacePrepared() {
        guard case .initial = state else { return }
        state = .pendingFacePreparedConfirmation(.pendingCheck)
    }

    mutating func faceNotPrepared(reason: FaceNotPreparedReason) {
        guard case .pendingFacePreparedConfirmation = state else { return }
        state = .pendingFacePreparedConfirmation(reason)
    }

    mutating func awaitingFaceMatch(with instruction: Instructor.Instruction, nearnessPercentage: Double) {
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
        guard case .pendingFacePreparedConfirmation = state else { return }
        state = .waitForRecording
    }
    
    mutating func unrecoverableStateEncountered(_ error: LivenessError) {
        switch state {
        case .encounteredUnrecoverableError, .completed:
            return
        default:
            state = .encounteredUnrecoverableError(error)
        }
    }

    mutating func beginRecording() {
        state = .recording(ovalDisplayed: false)
    }

    mutating func ovalDisplayed() {
        state = .recording(ovalDisplayed: true)
    }

    mutating func faceMatched() {
        state = .faceMatched
    }

    mutating func completedDisplayingFreshness() {
        state = .completedDisplayingFreshness
    }
    
    mutating func completedNoLightCheck() {
        state = .completedNoLightCheck
    }

    mutating func displayingFreshness() {
        state = .displayingFreshness
    }

    mutating func complete() {
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
        case awaitingChallengeType
        case pendingFacePreparedConfirmation(FaceNotPreparedReason)
        case recording(ovalDisplayed: Bool)
        case awaitingFaceInOvalMatch(FaceNotPreparedReason, Double)
        case faceMatched
        case initialClientInfoEventSent
        case displayingFreshness
        case completedDisplayingFreshness
        case completedNoLightCheck
        case completed
        case awaitingDisconnectEvent
        case disconnectEventReceived
        case encounteredUnrecoverableError(LivenessError)
        case waitForRecording
    }

    enum FaceNotPreparedReason {
        case pendingCheck
        case notInOval
        case moveFaceCloser
        case moveFaceRight
        case moveFaceLeft
        case moveToDimmerArea
        case moveToBrighterArea
        case noFace
        case multipleFaces
        case faceTooClose
        
        var localizedValue: String {
            switch self {
            case .pendingCheck:
                return LocalizedStrings.amplify_ui_liveness_face_not_prepared_reason_pendingCheck
            case .notInOval:
                return LocalizedStrings.amplify_ui_liveness_face_not_prepared_reason_not_in_oval
            case .moveFaceCloser:
                return LocalizedStrings.amplify_ui_liveness_face_not_prepared_reason_move_face_closer
            case .moveFaceRight:
                return LocalizedStrings.amplify_ui_liveness_face_not_prepared_reason_move_face_right
            case .moveFaceLeft:
                return LocalizedStrings.amplify_ui_liveness_face_not_prepared_reason_move_face_left
            case .moveToDimmerArea:
                return LocalizedStrings.amplify_ui_liveness_face_not_prepared_reason_move_to_dimmer_area
            case .moveToBrighterArea:
                return LocalizedStrings.amplify_ui_liveness_face_not_prepared_reason_move_to_brighter_area
            case .noFace:
                return LocalizedStrings.amplify_ui_liveness_face_not_prepared_reason_no_face
            case .multipleFaces:
                return LocalizedStrings.challenge_instruction_multiple_faces_detected
            case .faceTooClose:
                return LocalizedStrings.amplify_ui_liveness_face_not_prepared_reason_face_too_close
            }
        }
    }

    struct LivenessError: Error, Equatable {
        let code: UInt8
        let webSocketCloseCode: URLSessionWebSocketTask.CloseCode?
        
        static let unknown = LivenessError(code: 0, webSocketCloseCode: .unexpectedRuntimeError)
        static let missingVideoPermission = LivenessError(code: 1, webSocketCloseCode: .missingVideoPermission)
        static let errorWithUnderlyingOSFramework = LivenessError(code: 2, webSocketCloseCode: .unexpectedRuntimeError)
        static let userCancelled = LivenessError(code: 3, webSocketCloseCode: .ovalFitUserClosedSession)
        static let timedOut = LivenessError(code: 4, webSocketCloseCode: .ovalFitMatchTimeout)
        static let couldNotOpenStream = LivenessError(code: 5, webSocketCloseCode: .unexpectedRuntimeError)
        static let socketClosed = LivenessError(code: 6, webSocketCloseCode: .normalClosure)
        static let viewResignation = LivenessError(code: 8, webSocketCloseCode: .viewClosure)
        static let cameraNotAvailable = LivenessError(code: 9, webSocketCloseCode: .unexpectedRuntimeError)

        static func == (lhs: LivenessError, rhs: LivenessError) -> Bool {
            lhs.code == rhs.code
        }
    }
}

extension URLSessionWebSocketTask.CloseCode {
    static let ovalFitMatchTimeout = URLSessionWebSocketTask.CloseCode(rawValue: 4001)
    static let ovalFitTimeOutNoFaceDetected = URLSessionWebSocketTask.CloseCode(rawValue: 4002)
    static let ovalFitUserClosedSession = URLSessionWebSocketTask.CloseCode(rawValue: 4003)
    static let viewClosure = URLSessionWebSocketTask.CloseCode(rawValue: 4004)
    static let unexpectedRuntimeError = URLSessionWebSocketTask.CloseCode(rawValue: 4005)
    static let missingVideoPermission = URLSessionWebSocketTask.CloseCode(rawValue: 4006)
}
