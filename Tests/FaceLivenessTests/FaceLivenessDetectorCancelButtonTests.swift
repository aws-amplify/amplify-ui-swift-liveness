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
