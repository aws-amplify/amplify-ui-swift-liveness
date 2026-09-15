//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import UIKit
@testable import FaceLiveness

/// Stands in for the `UIWindowScene` hosting the detector.
private final class StubScene: InterfaceOrientationProviding {
    var interfaceOrientation: UIInterfaceOrientation
    init(_ interfaceOrientation: UIInterfaceOrientation) { self.interfaceOrientation = interfaceOrientation }
}

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
    /// Then: It matches the app's foreground scene, the seed used before the reader attaches
    func testObserverDefaultsToForegroundSceneOrientation() {
        let observer = InterfaceOrientationObserver()
        XCTAssertEqual(observer.orientation, LivenessOrientation.currentInterfaceOrientation)
    }

    /// Given: An observer seeded with an orientation that may not match the foreground scene
    /// When: It refreshes before any host scene is known
    /// Then: It publishes the foreground scene's orientation and the matching decision
    func testRefreshWithoutAHostSceneFallsBackToTheForegroundScene() {
        let observer = InterfaceOrientationObserver(orientation: .landscapeLeft)

        observer.refresh()

        let current = LivenessOrientation.currentInterfaceOrientation
        XCTAssertEqual(observer.orientation, current)
        XCTAssertEqual(observer.decision, LivenessOrientation.decision(for: current))
    }

    // MARK: - The scene the detector is hosted in

    /// Given: A host scene in landscape while the foreground scene lookup reports portrait
    /// When: The reader settles in that scene
    /// Then: The host scene's orientation is published, not the foreground scene's
    func testSettlingInAHostSceneReadsThatScene() {
        let observer = InterfaceOrientationObserver(orientation: .portrait)
        let hostScene = StubScene(.landscapeRight)
        XCTAssertEqual(LivenessOrientation.currentInterfaceOrientation, .portrait, "test needs no live scene")

        observer.settle(in: hostScene)

        XCTAssertEqual(observer.orientation, .landscapeRight)
        XCTAssertEqual(observer.decision, .blockUntilPortrait)
        XCTAssertTrue(observer.hostScene === hostScene)
    }

    /// Given: An observer that has settled in a host scene
    /// When: That scene's orientation changes and the observer refreshes, from any signal
    /// Then: The host scene is read again, not the foreground scene
    func testRefreshKeepsReadingTheHostScene() {
        let observer = InterfaceOrientationObserver(orientation: .portrait)
        let hostScene = StubScene(.portrait)
        observer.settle(in: hostScene)

        hostScene.interfaceOrientation = .landscapeLeft
        observer.refresh()

        XCTAssertEqual(observer.orientation, .landscapeLeft)
    }

    /// Given: An observer that has settled in a host scene
    /// When: The reader settles again without a window
    /// Then: The known host scene is kept rather than dropped
    func testSettlingWithoutASceneKeepsTheKnownHostScene() {
        let observer = InterfaceOrientationObserver(orientation: .portrait)
        let hostScene = StubScene(.landscapeLeft)
        observer.settle(in: hostScene)

        observer.settle(in: nil)

        XCTAssertTrue(observer.hostScene === hostScene)
        XCTAssertEqual(observer.orientation, .landscapeLeft)
    }

    // MARK: - Deriving the target orientation from a transition

    // `coordinator.targetTransform` values as UIKit reported them on iOS 17.5 (iPad 10th gen and
    // iPhone 15 simulators; fullScreenCover, sheet and navigation push agreed), keyed by the
    // orientation pair that produced them. Not synthesized from an assumed angle.
    private enum Measured {
        /// portrait -> landscapeLeft, landscapeRight -> portrait
        static let quarterTurnNegative = CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: 0)
        /// portrait -> landscapeRight, landscapeLeft -> portrait, landscapeRight -> upsideDown
        static let quarterTurnPositive = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 0, ty: 0)
        /// landscapeLeft -> landscapeRight
        static let halfTurn = CGAffineTransform(a: -1, b: 0, c: -0, d: -1, tx: 0, ty: 0)
        /// upsideDown -> portrait
        static let halfTurnNegative = CGAffineTransform(a: -1, b: -0, c: 0, d: -1, tx: 0, ty: 0)
    }

    /// Given: A portrait interface and the transforms UIKit reported leaving it
    /// When: The target orientation is derived
    /// Then: Each lands on the orientation that was requested
    func testTurnsFromPortraitMatchMeasuredTransforms() {
        XCTAssertEqual(LivenessOrientation.orientation(.portrait, rotatedBy: Measured.quarterTurnNegative), .landscapeLeft)
        XCTAssertEqual(LivenessOrientation.orientation(.portrait, rotatedBy: Measured.quarterTurnPositive), .landscapeRight)
        XCTAssertEqual(LivenessOrientation.orientation(.portrait, rotatedBy: .identity), .portrait)
    }

    /// Given: A landscape or upside-down interface and the transforms UIKit reported returning it
    /// When: The target orientation is derived
    /// Then: Each lands on portrait
    func testTurnsBackToPortraitMatchMeasuredTransforms() {
        XCTAssertEqual(LivenessOrientation.orientation(.landscapeLeft, rotatedBy: Measured.quarterTurnPositive), .portrait)
        XCTAssertEqual(LivenessOrientation.orientation(.landscapeRight, rotatedBy: Measured.quarterTurnNegative), .portrait)
        XCTAssertEqual(LivenessOrientation.orientation(.portraitUpsideDown, rotatedBy: Measured.halfTurnNegative), .portrait)
    }

    /// Given: The transforms UIKit reported between the two non-portrait pairs
    /// When: The target orientation is derived
    /// Then: landscapeRight turns to upside down and landscapeLeft to landscapeRight
    func testTurnsBetweenBlockedOrientationsMatchMeasuredTransforms() {
        XCTAssertEqual(LivenessOrientation.orientation(.landscapeRight, rotatedBy: Measured.quarterTurnPositive), .portraitUpsideDown)
        XCTAssertEqual(LivenessOrientation.orientation(.landscapeLeft, rotatedBy: Measured.halfTurn), .landscapeRight)
    }

    /// Given: A portrait interface and a quarter turn of either sign
    /// When: The decision is made for the derived orientation
    /// Then: Both block, so the gate leaving portrait does not depend on the sign convention
    func testEitherQuarterTurnFromPortraitBlocks() {
        for transform in [Measured.quarterTurnNegative, Measured.quarterTurnPositive] {
            let derived = LivenessOrientation.orientation(.portrait, rotatedBy: transform)
            XCTAssertEqual(LivenessOrientation.decision(for: derived), .blockUntilPortrait)
        }
    }

    /// Given: An unknown interface orientation
    /// When: The target orientation is derived
    /// Then: It stays unknown rather than guessing
    func testUnknownOrientationIsNotRotated() {
        XCTAssertEqual(LivenessOrientation.orientation(.unknown, rotatedBy: Measured.quarterTurnPositive), .unknown)
    }

    /// Given: An observer in portrait
    /// When: A transition to landscape begins
    /// Then: The blocked decision is published before the scene reports the new orientation
    func testBeginTransitionPublishesABlockingOrientationEarly() {
        let observer = InterfaceOrientationObserver(orientation: .portrait)

        observer.beginTransition(with: Measured.quarterTurnNegative)

        XCTAssertEqual(observer.orientation, .landscapeLeft)
        XCTAssertEqual(observer.decision, .blockUntilPortrait)
    }

    /// Given: An observer in landscape
    /// When: A transition back to portrait begins, then the reader settles in a portrait scene
    /// Then: The prompt holds through the transition and lifts on the settled scene read
    func testBeginTransitionBackToPortraitWaitsForTheSettledScene() {
        let observer = InterfaceOrientationObserver(orientation: .landscapeRight)

        observer.beginTransition(with: Measured.quarterTurnNegative)
        XCTAssertEqual(observer.orientation, .landscapeRight, "a derived portrait must not unblock early")
        XCTAssertEqual(observer.decision, .blockUntilPortrait)

        observer.settle(in: StubScene(.portrait))
        XCTAssertEqual(observer.orientation, .portrait)
        XCTAssertEqual(observer.decision, .proceed)
    }
}
