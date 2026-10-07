//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import FaceLiveness
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

final class FaceInOvalMatchingTests: XCTestCase {
    // Oval match thresholds: 20pt wide, 30pt high. Face detection thresholds: 30pt wide, 45pt high.
    private let oval = CGRect(x: 100, y: 100, width: 200, height: 300)
    private let challenge = FaceLivenessSession.OvalMatchChallenge(
        faceDetectionThreshold: 0.7,
        face: .init(
            distanceThreshold: 0.32,
            distanceThresholdMax: 0.4,
            distanceThresholdMin: 0.1,
            iouWidthThreshold: 0.15,
            iouHeightThreshold: 0.15
        ),
        oval: .init(
            boundingBox: .init(x: 100, y: 100, width: 200, height: 300),
            heightWidthRatio: 1.618,
            iouThreshold: 0.7,
            iouWidthThreshold: 0.1,
            iouHeightThreshold: 0.1,
            ovalFitTimeout: 7000
        )
    )

    private func instruction(for face: CGRect, using matching: FaceInOvalMatching = .init()) -> Instructor.Instruction {
        matching.faceMatchState(for: face, in: oval, challengeConfig: challenge)
    }

    func testFaceFillingOvalMatches() {
        XCTAssertEqual(instruction(for: oval), .match)
    }

    /// The instruction must be reported on the first frame rather than being held back
    /// until it repeats across several frames.
    func testTooCloseIsReportedOnFirstFrame() {
        let face = CGRect(x: 70, y: 40, width: 260, height: 420)
        XCTAssertEqual(instruction(for: face), .tooClose(nearnessPercentage: 0))
    }

    func testTooCloseIsReportedOnEveryFrameWhileFlickering() {
        let matching = FaceInOvalMatching()
        let tooClose = CGRect(x: 70, y: 40, width: 260, height: 420)
        let tooFar = CGRect(x: 150, y: 200, width: 100, height: 150)

        XCTAssertEqual(instruction(for: tooClose, using: matching), .tooClose(nearnessPercentage: 0))
        XCTAssertEqual(instruction(for: tooFar, using: matching), .tooFar(nearnessPercentage: 0))
        XCTAssertEqual(instruction(for: tooClose, using: matching), .tooClose(nearnessPercentage: 0))
    }

    func testSmallCenteredFaceIsTooFar() {
        let face = CGRect(x: 150, y: 200, width: 100, height: 150)
        XCTAssertEqual(instruction(for: face), .tooFar(nearnessPercentage: 0))
    }

    func testFaceShiftedLeftIsTooFarLeft() {
        let face = CGRect(x: 40, y: 100, width: 200, height: 300)
        XCTAssertEqual(instruction(for: face), .tooFarLeft(nearnessPercentage: 0))
    }

    func testFaceShiftedRightIsTooFarRight() {
        let face = CGRect(x: 160, y: 100, width: 200, height: 300)
        XCTAssertEqual(instruction(for: face), .tooFarRight(nearnessPercentage: 0))
    }

    /// Horizontal offset is checked before closeness, so an off-center face that is
    /// also too close is reported as off to the side.
    func testTooCloseFaceShiftedLeftIsTooFarLeft() {
        let face = CGRect(x: 20, y: 40, width: 260, height: 420)
        XCTAssertEqual(instruction(for: face), .tooFarLeft(nearnessPercentage: 0))
    }

    func testOffCenterFaceShowsMoveCloser() {
        var stateMachine = LivenessStateMachine(state: .recording(ovalDisplayed: true))
        stateMachine.awaitingFaceMatch(with: .tooFarLeft(nearnessPercentage: 0.4), nearnessPercentage: 0.4)
        XCTAssertEqual(stateMachine.state, .awaitingFaceInOvalMatch(.moveFaceCloser, 0.4))

        stateMachine.awaitingFaceMatch(with: .tooFarRight(nearnessPercentage: 0.5), nearnessPercentage: 0.5)
        XCTAssertEqual(stateMachine.state, .awaitingFaceInOvalMatch(.moveFaceCloser, 0.5))
    }

    func testTooCloseFaceShowsMoveBack() {
        var stateMachine = LivenessStateMachine(state: .recording(ovalDisplayed: true))
        stateMachine.awaitingFaceMatch(with: .tooClose(nearnessPercentage: 0.3), nearnessPercentage: 0.3)
        XCTAssertEqual(stateMachine.state, .awaitingFaceInOvalMatch(.faceTooClose, 0.3))
    }
}
