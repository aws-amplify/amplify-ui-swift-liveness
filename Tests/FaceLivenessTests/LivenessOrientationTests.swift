//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import UIKit
@testable import FaceLiveness

final class LivenessOrientationTestCase: XCTestCase {

    /// Given: A portrait interface orientation
    /// When: The orientation decision is made
    /// Then: The liveness flow proceeds
    func testPortraitProceeds() {
        XCTAssertEqual(LivenessOrientation.decision(for: .portrait), .proceed)
    }

    /// Given: A landscape interface orientation, left or right
    /// When: The orientation decision is made
    /// Then: The flow is blocked until the interface returns to portrait
    func testLandscapeIsBlocked() {
        XCTAssertEqual(LivenessOrientation.decision(for: .landscapeLeft), .blockUntilPortrait)
        XCTAssertEqual(LivenessOrientation.decision(for: .landscapeRight), .blockUntilPortrait)
    }

    /// Given: An upside down interface orientation
    /// When: The orientation decision is made
    /// Then: The flow is blocked
    func testPortraitUpsideDownIsBlocked() {
        XCTAssertEqual(LivenessOrientation.decision(for: .portraitUpsideDown), .blockUntilPortrait)
    }

    /// Given: An interface orientation that cannot be read
    /// When: The orientation decision is made
    /// Then: The flow proceeds
    func testUnknownOrientationProceeds() {
        XCTAssertEqual(LivenessOrientation.decision(for: .unknown), .proceed)
    }

    /// Given: An observer seeded with a landscape orientation
    /// When: Its decision is read
    /// Then: It reports the blocked decision for that orientation
    func testObserverReportsDecisionForItsOrientation() {
        let observer = InterfaceOrientationObserver(orientation: .landscapeRight)
        XCTAssertEqual(observer.orientation, .landscapeRight)
        XCTAssertEqual(observer.decision, .blockUntilPortrait)
    }

    /// Given: An observer created without a seeded orientation
    /// When: Its orientation is read
    /// Then: It matches the host scene's orientation
    func testObserverDefaultsToHostSceneOrientation() {
        let observer = InterfaceOrientationObserver()
        XCTAssertEqual(observer.orientation, LivenessOrientation.currentInterfaceOrientation)
    }

    /// Given: An observer seeded with an orientation that may not match the host scene
    /// When: It refreshes
    /// Then: It publishes the host scene's orientation and the matching decision
    func testRefreshPublishesCurrentOrientation() {
        let observer = InterfaceOrientationObserver(orientation: .landscapeLeft)

        observer.refresh()

        let current = LivenessOrientation.currentInterfaceOrientation
        XCTAssertEqual(observer.orientation, current)
        XCTAssertEqual(observer.decision, LivenessOrientation.decision(for: current))
    }

    // MARK: - Deriving the target orientation from a transition

    private func rotation(degrees: CGFloat) -> CGAffineTransform {
        CGAffineTransform(rotationAngle: degrees * .pi / 180)
    }

    /// Given: A portrait interface and the transforms a rotation coordinator reports
    /// When: The target orientation is derived
    /// Then: A quarter turn each way lands on the matching landscape; a half turn is upside down
    func testQuarterAndHalfTurnsFromPortrait() {
        XCTAssertEqual(LivenessOrientation.orientation(.portrait, rotatedBy: rotation(degrees: -90)), .landscapeLeft)
        XCTAssertEqual(LivenessOrientation.orientation(.portrait, rotatedBy: rotation(degrees: 90)), .landscapeRight)
        XCTAssertEqual(LivenessOrientation.orientation(.portrait, rotatedBy: rotation(degrees: 180)), .portraitUpsideDown)
        XCTAssertEqual(LivenessOrientation.orientation(.portrait, rotatedBy: rotation(degrees: -180)), .portraitUpsideDown)
        XCTAssertEqual(LivenessOrientation.orientation(.portrait, rotatedBy: .identity), .portrait)
    }

    /// Given: A landscape or upside-down interface
    /// When: The target orientation is derived for the transforms that return it to portrait
    /// Then: Each lands on portrait
    func testTurnsBackToPortrait() {
        XCTAssertEqual(LivenessOrientation.orientation(.landscapeLeft, rotatedBy: rotation(degrees: 90)), .portrait)
        XCTAssertEqual(LivenessOrientation.orientation(.landscapeRight, rotatedBy: rotation(degrees: -90)), .portrait)
        XCTAssertEqual(LivenessOrientation.orientation(.portraitUpsideDown, rotatedBy: rotation(degrees: 180)), .portrait)
    }

    /// Given: A landscape interface
    /// When: The device is turned a half turn to the other landscape
    /// Then: The target is the opposite landscape, and the decision stays blocked
    func testHalfTurnBetweenLandscapes() {
        XCTAssertEqual(LivenessOrientation.orientation(.landscapeLeft, rotatedBy: rotation(degrees: 180)), .landscapeRight)
        XCTAssertEqual(LivenessOrientation.orientation(.landscapeRight, rotatedBy: rotation(degrees: 180)), .landscapeLeft)
    }

    /// Given: An unknown interface orientation
    /// When: The target orientation is derived
    /// Then: It stays unknown rather than guessing
    func testUnknownOrientationIsNotRotated() {
        XCTAssertEqual(LivenessOrientation.orientation(.unknown, rotatedBy: rotation(degrees: 90)), .unknown)
    }

    /// Given: An observer in portrait
    /// When: A transition to landscape begins
    /// Then: The blocked decision is published before the scene reports the new orientation
    func testBeginTransitionPublishesTargetOrientation() {
        let observer = InterfaceOrientationObserver(orientation: .portrait)

        observer.beginTransition(with: rotation(degrees: -90))

        XCTAssertEqual(observer.orientation, .landscapeLeft)
        XCTAssertEqual(observer.decision, .blockUntilPortrait)
    }

    /// Given: An observer in landscape
    /// When: A transition back to portrait begins
    /// Then: The proceed decision is published
    func testBeginTransitionBackToPortraitProceeds() {
        let observer = InterfaceOrientationObserver(orientation: .landscapeRight)

        observer.beginTransition(with: rotation(degrees: -90))

        XCTAssertEqual(observer.orientation, .portrait)
        XCTAssertEqual(observer.decision, .proceed)
    }
}
