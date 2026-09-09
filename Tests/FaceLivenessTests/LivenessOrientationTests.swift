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
    /// Then: The flow is blocked, because the capture connections are pinned to `.portrait`
    ///       and would produce a feed rotated by 180 degrees
    func testPortraitUpsideDownIsBlocked() {
        XCTAssertEqual(LivenessOrientation.decision(for: .portraitUpsideDown), .blockUntilPortrait)
    }

    /// Given: An interface orientation that cannot be read
    /// When: The orientation decision is made
    /// Then: The flow proceeds, so an unreadable orientation never blocks a check that
    ///       works today
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
    /// Then: It matches the orientation of the host scene, falling back to portrait when no
    ///       scene can be resolved
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
}
