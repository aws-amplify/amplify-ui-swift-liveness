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

    mutating func checkIsFacePrepared() throws {
        try transitionState(
            validFromStates: .initial,
            to: .pendingFacePreparedConfirmation(.pendingCheck)
        )
    }

    mutating func faceNotPrepared(reason: FaceNotPreparedReason) throws {
        switch state {
        case .pendingFacePreparedConfirmation:
            state = .pendingFacePreparedConfirmation(reason)
        default:
            throw StateError.invalidTransition(
                from: state,
                to: .pendingFacePreparedConfirmation(reason)
            )
        }
    }

    mutating func openSocket() throws {
        switch state {
        case .pendingFacePreparedConfirmation, .countingDown:
            state = .socketOpened
        default:
            throw StateError.invalidTransition(
                from: state,
                to: .socketOpened
            )
        }
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

    mutating func awaitingServerInfoEvent() throws {
        try transitionState(
            validFromStates: .socketOpened,
            to: .awaitingServerInfoEvent
        )
    }

    mutating func receivedServerInfoEvent() throws {
        try transitionState(
            validFromStates: .awaitingServerInfoEvent,
            to: .serverInfoEventReceived
        )
    }

    mutating func unrecoverableStateEncountered(_ error: LivenessError) {
        switch state {
        case .encounteredUnrecoverableError, .completed:
            return
        default: break
        }
        state = .encounteredUnrecoverableError(error)
    }

    mutating func beginRecording() {
        state = .recording(ovalDisplayed: false)
    }

    mutating func ovalDisplayed() {
        state = .recording(ovalDisplayed: true)
    }

    mutating func startCountdown() throws {
        guard case .pendingFacePreparedConfirmation = state
        else {
            return
        }
        state = .countingDown
    }

    mutating func faceMatched() {
        state = .faceMatched
    }

    mutating func completedDisplayingFreshness() {
        state = .completedDisplayingFreshness
    }

    mutating func displayingFreshness() {
        state = .displayingFreshness
    }

    mutating func complete() {
        state = .completed
    }

    mutating func sentClientInformationEvent() {

    }

    var shouldDisplayRecordingIcon: Bool {
        switch state {
        case .initial, .pendingFacePreparedConfirmation, .encounteredUnrecoverableError, .countingDown:
            return false
        default: return true
        }
    }

    enum State: Equatable {
        case initial
        case pendingFacePreparedConfirmation(FaceNotPreparedReason)

        case socketOpened

        case awaitingServerInfoEvent
        case serverInfoEventReceived

        case countingDown
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

    private mutating func transitionState(validFromStates: State..., to newState: State) throws {
        guard validFromStates.contains(state) else {
            throw StateError.invalidTransition(from: state, to: newState)
        }
        state = newState
    }

    struct LivenessError: Error, Equatable {
        let code: UInt8
        let description: String

        static let unknown = LivenessError(
            code: 0,
            description: "An unknown error was encountered"
        )

        static let missingVideoPermission = LivenessError(
            code: 1,
            description: "..."
        )

        static let errorWithUnderlyingOSFramework = LivenessError(
            code: 2,
            description: "..."
        )

        static let userCancelled = LivenessError(
            code: 3,
            description: "User cancelled"
        )

        static let timedOut = LivenessError(
            code: 4,
            description: "User cancelled"
        )

        static let couldNotOpenStream = LivenessError(
            code: 5,
            description: "Could not open stream"
        )

        static let socketClosed = LivenessError(
            code: 6,
            description: "Websocket connection closed unexpectedly"
        )

        static let invalidFaceMovementDuringCountdown = LivenessError(
            code: 7,
            description: ""
        )

        static func == (lhs: LivenessError, rhs: LivenessError) -> Bool {
            lhs.code == rhs.code
        }
    }

    struct StateError: Swift.Error {
        let code: UInt8
        let fromState: State
        let toState: State

        var description: String {
            "Invalid transition from: \(fromState) to: \(toState)"
        }

        static func invalidTransition(from: State, to: State) -> Self {
            .init(
                code: 1,
                fromState: from,
                toState: to
            )
        }
    }
}


/*
 var stateChangeCount = 0

 struct LivenessWorkflow {
     private(set) var state: State

     struct SideEffect {

     }

     enum Event {

     }

     struct Transition {

     }

     enum State {
         case initial
         case awaitingFace(FaceUnpreparedReason)
         case hasSingleFace
         case faceInPositionBeforeRecording
         case awaitingServerSessionInformation
         case hasServerSessionInformation(FaceLivenessSession.SessionConfiguration)
         case countingDown(CountingDownState)
         case recording(RecordingState)
         case doneRecording
         case awaitingDisconnentEvent
         case success
         case unrecoverableError(UnrecoverableError)

         struct UnrecoverableError: Error {}

         enum RecordingState {
             case initial, faceInPosition, flashingFreshnessColors
         }


         enum CountingDownState {
             case initial, notEnoughDistance, validDistance
         }

         struct FaceUnpreparedReason {
             let message: String

             static let noFace = FaceUnpreparedReason(
                 message: "Move face in front of camera"
             )

             static let multipleFaces = FaceUnpreparedReason(
                 message: "Ensure only one face is in front of camera"
             )
         }
     }
 }

 */
