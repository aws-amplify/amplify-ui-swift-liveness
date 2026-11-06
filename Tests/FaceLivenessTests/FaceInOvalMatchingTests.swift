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

    // MARK: - measure(face:in:challengeConfig:)

    private func measurement(of face: CGRect, using matching: FaceInOvalMatching) -> OvalMeasurement {
        matching.measure(face: face, in: oval, challengeConfig: challenge)
    }

    /// The position a correction names, and its nearness, which its `==` ignores; nil for `.match` and `.none`.
    private func correction(_ instruction: Instructor.Instruction) -> (position: FaceOvalPosition, nearness: Double)? {
        switch instruction {
        case .tooFarLeft(_, let nearness): return (.tooFarLeft, nearness)
        case .tooFarRight(_, let nearness): return (.tooFarRight, nearness)
        case .tooClose(_, let nearness): return (.tooClose, nearness)
        case .tooFar(_, let nearness): return (.tooFar, nearness)
        case .match, .none: return nil
        }
    }

    /// Given: A matcher whose first face covered a quarter of the oval
    /// When: Faces in every position are measured and matched
    /// Then: Each is measured in its instruction's position, with its overlap, and keeps its pre-`measure` nearness
    func testMeasureAgreesWithFaceMatchState() throws {
        let matching = FaceInOvalMatching()
        let quarter = CGRect(x: 150, y: 200, width: 100, height: 150)
        XCTAssertEqual(correction(instruction(for: quarter, using: matching))?.nearness, 0.25)
        XCTAssertEqual(measurement(of: oval, using: matching), OvalMeasurement(position: .matched, iou: 1))
        let rows: [(name: String, face: CGRect, position: FaceOvalPosition, iou: Double, nearness: Double)] = [
            ("small and centered", CGRect(x: 175, y: 250, width: 50, height: 75), .tooFar, 0.0625, 0),
            ("the oval's left half", CGRect(x: 100, y: 100, width: 100, height: 300), .tooFar, 0.5, 0.6667),
            ("around the oval", CGRect(x: 70, y: 40, width: 260, height: 420), .tooClose, 0.5495, 0.7491),
            ("shifted left", CGRect(x: 40, y: 100, width: 200, height: 300), .tooFarLeft, 0.5385, 0.7308),
            ("around it, shifted left", CGRect(x: 20, y: 40, width: 260, height: 420), .tooFarLeft, 0.4688, 0.6146),
            ("shifted right", CGRect(x: 125, y: 100, width: 200, height: 300), .tooFarRight, 0.7778, 1),
            ("apart from the oval", CGRect(x: 400, y: 500, width: 50, height: 50), .tooFarRight, 0, 0)
        ]

        for row in rows {
            let measured = measurement(of: row.face, using: matching)
            let corrected = try XCTUnwrap(correction(instruction(for: row.face, using: matching)), row.name)

            XCTAssertEqual(measured.position, row.position, row.name)
            XCTAssertEqual(corrected.position, row.position, row.name)
            XCTAssertEqual(measured.iou, row.iou, accuracy: 1e-4, row.name)
            XCTAssertEqual(corrected.nearness, row.nearness, accuracy: 1e-4, row.name)
        }
    }

    /// Given: A matcher that has only measured a face
    /// When: It matches another
    /// Then: The nearness is a first face's, 0.25, so measuring didn't set the initial overlap
    func testMeasuringDoesNotSetTheInitialOverlap() {
        let matching = FaceInOvalMatching()
        _ = measurement(of: CGRect(x: 175, y: 250, width: 50, height: 75), using: matching)

        let face = CGRect(x: 125, y: 150, width: 150, height: 225)
        XCTAssertEqual(correction(instruction(for: face, using: matching))?.nearness, 0.25)
    }
}
