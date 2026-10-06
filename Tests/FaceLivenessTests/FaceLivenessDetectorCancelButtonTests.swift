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
final class FaceLivenessDetectorCancelButtonTests: XCTestCase {
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

    /// Given: A detector with no cancel button options set
    /// When: Its close button is resolved
    /// Then: It's the standard close button
    func testTheStandardCloseButtonShowsByDefault() {
        XCTAssertEqual(makeDetector().cancelButtonOptions.resolved, .standard)
    }

    /// Given: A detector
    /// When: `hidesCancelButton` is set to `true`, then back to `false`
    /// Then: The close button is hidden, then standard again
    func testHidesCancelButtonHidesTheCloseButton() {
        let hidden = makeDetector().hidesCancelButton()
        XCTAssertEqual(hidden.cancelButtonOptions.resolved, .hidden)

        let shown = hidden.hidesCancelButton(false)
        XCTAssertEqual(shown.cancelButtonOptions.resolved, .standard)
    }

    /// Given: A detector with a replacement close button
    /// When: The replacement is built and calls the action it's given
    /// Then: The action is the one that cancels the check
    func testTheReplacementIsGivenTheCancelAction() {
        var givenCancel: (() -> Void)?
        let detector = makeDetector().cancelButton { cancel -> EmptyView in
            givenCancel = cancel
            return EmptyView()
        }
        XCTAssertEqual(detector.cancelButtonOptions.resolved, .custom)

        var cancelled = false
        _ = detector.cancelButtonOptions.content?({ cancelled = true })
        givenCancel?()

        XCTAssertTrue(cancelled)
    }

    /// Given: A detector with both a replacement close button and `hidesCancelButton`
    /// When: They're set in either order
    /// Then: The close button is hidden
    func testHidingWinsOverAReplacementWhicheverIsSetFirst() {
        let replacedThenHidden = makeDetector()
            .cancelButton { _ in Text("Leave") }
            .hidesCancelButton()
        let hiddenThenReplaced = makeDetector()
            .hidesCancelButton()
            .cancelButton { _ in Text("Leave") }

        XCTAssertEqual(replacedThenHidden.cancelButtonOptions.resolved, .hidden)
        XCTAssertEqual(hiddenThenReplaced.cancelButtonOptions.resolved, .hidden)
    }
}

@MainActor
final class FaceLivenessDetectionViewModelDismissalTests: XCTestCase {
    private var viewModel: FaceLivenessDetectionViewModel!
    private var livenessService: MockLivenessService!

    override func setUp() {
        reset()
    }

    /// A fresh view model and service, for tests that check several states.
    private func reset() {
        livenessService = MockLivenessService()
        viewModel = FaceLivenessDetectionViewModel(
            faceDetector: MockFaceDetector(),
            faceInOvalMatching: .init(),
            videoChunker: VideoChunker(
                assetWriter: LivenessAVAssetWriter(),
                assetWriterDelegate: VideoChunker.AssetWriterDelegate(),
                assetWriterInput: LivenessAVAssetWriterInput()
            ),
            closeButtonAction: {},
            sessionID: UUID().uuidString,
            isPreviewScreenEnabled: false,
            challengeOptions: .init(
                faceMovementChallengeOption: .init(camera: .front),
                faceMovementAndLightChallengeOption: .init()
            )
        )
        viewModel.livenessService = livenessService
    }

    override func tearDown() {
        viewModel = nil
        livenessService = nil
    }

    /// Given: A check that's under way
    /// When: The app removes the view
    /// Then: The session is closed with `viewClosure` (4004), and no result is published
    func testDismissingDuringTheCheckClosesTheSession() {
        let inProgress: [LivenessStateMachine.State] = [
            .pendingFacePreparedConfirmation(.pendingCheck),
            .recording(ovalDisplayed: true),
            .awaitingFaceInOvalMatch(.moveFaceCloser, 0.5),
            .displayingFreshness,
            .completedDisplayingFreshness
        ]
        for state in inProgress {
            reset()
            var closeCodes: [Int] = []
            livenessService.onCloseSocket = { closeCodes.append($0.rawValue) }
            viewModel.livenessState = LivenessStateMachine(state: state)

            viewModel.closeSessionOnDismissal()

            XCTAssertEqual(closeCodes, [4004], "\(state)")
            XCTAssertEqual(viewModel.livenessState.state, state, "no result should be published for \(state)")
        }
    }

    /// Given: A check that has already ended
    /// When: The view leaves the screen
    /// Then: The session isn't closed again
    func testDismissingAfterTheCheckEndsLeavesTheSessionAlone() {
        let ended: [LivenessStateMachine.State] = [
            .completed,
            .encounteredUnrecoverableError(.userCancelled)
        ]
        for state in ended {
            reset()
            viewModel.livenessState = LivenessStateMachine(state: state)

            viewModel.closeSessionOnDismissal()

            XCTAssertFalse(livenessService.interactions.contains("closeSocket(with:)"), "\(state)")
        }
    }

    /// Given: A view removed while its session was still starting
    /// When: The session finishes starting
    /// Then: Its stream isn't opened
    func testASessionThatFinishesStartingAfterDismissalDoesNotOpenItsStream() {
        viewModel.livenessService = nil
        viewModel.closeSessionOnDismissal()

        viewModel.livenessService = livenessService
        viewModel.initializeLivenessStream()

        XCTAssertFalse(livenessService.interactions.contains("initializeLivenessStream(withSessionID:userAgent:challenges:options:)"))
    }
}
