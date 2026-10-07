//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import SwiftUI
@testable import FaceLiveness

@MainActor
final class FaceLivenessDetectorVerifyingViewTests: XCTestCase {
    private func makeDetector() -> FaceLivenessDetectorView {
        FaceLivenessDetectorView(
            sessionID: UUID().uuidString,
            credentialsProvider: MockCredentialsProvider {
                MockAWSCredentials(accessKeyId: "accessKey", secretAccessKey: "secretKey")
            },
            region: "us-east-1",
            isPresented: .constant(true),
            onCompletion: { _ in }
        )
    }

    /// Given: A detector with no verifying view set
    /// When: The check is being verified
    /// Then: The default verifying screen shows
    func testTheDefaultVerifyingScreenShowsByDefault() {
        let options = makeDetector().verifyingViewOptions

        XCTAssertNil(options.content(for: .completedDisplayingFreshness))
        XCTAssertNil(options.content(for: .completedNoLightCheck))
    }

    /// Given: A detector with a verifying view
    /// When: The check is being verified after either challenge
    /// Then: The app's view is built
    func testTheVerifyingViewShowsWhileTheCheckIsBeingVerified() {
        var builtCount = 0
        let options = makeDetector().verifyingView { () -> EmptyView in
            builtCount += 1
            return EmptyView()
        }.verifyingViewOptions

        XCTAssertNotNil(options.content(for: .completedDisplayingFreshness))
        XCTAssertNotNil(options.content(for: .completedNoLightCheck))
        XCTAssertEqual(builtCount, 2)
    }

    /// Given: A detector with a verifying view
    /// When: The check is in any state other than being verified
    /// Then: The app's view isn't built
    func testTheVerifyingViewDoesNotShowOutsideVerifying() {
        var built = false
        let options = makeDetector().verifyingView { () -> EmptyView in
            built = true
            return EmptyView()
        }.verifyingViewOptions

        let states: [LivenessStateMachine.State] = [
            .initial,
            .pendingFacePreparedConfirmation(.pendingCheck),
            .recording(ovalDisplayed: true),
            .awaitingFaceInOvalMatch(.moveFaceCloser, 0.5),
            .faceMatched,
            .displayingFreshness,
            .completed,
            .encounteredUnrecoverableError(.userCancelled)
        ]
        for state in states {
            XCTAssertNil(options.content(for: state), "\(state)")
        }
        XCTAssertFalse(built)
    }
}
