//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import Combine
@testable import FaceLiveness

/// The detector view dismisses and fires the host's completion from a single observer of
/// `livenessState`, so the number of terminal states published is the number of completions.
@MainActor
final class FaceLivenessDetectionViewModelEndCheckTests: XCTestCase {
    private var viewModel: FaceLivenessDetectionViewModel!
    private var terminalStates: [LivenessStateMachine.State] = []
    private var cancellable: AnyCancellable?

    override func setUp() {
        viewModel = LivenessGeometryFixture.makeViewModel(presenter: MockLivenessViewControllerPresenter())
        viewModel.livenessState = .init(state: .recording(ovalDisplayed: true))
        terminalStates = []
        cancellable = viewModel.$livenessState
            .dropFirst()
            .sink { [weak self] machine in
                switch machine.state {
                case .completed, .encounteredUnrecoverableError:
                    self?.terminalStates.append(machine.state)
                default:
                    break
                }
            }
    }

    override func tearDown() {
        cancellable = nil
        viewModel = nil
    }

    /// Given: A check in progress, and a rotation interrupt scheduled for the next main turn
    /// When: The user cancels from the rotate prompt before the interrupt runs
    /// Then: Exactly one terminal state is published, and it is the cancellation
    func testCancelBeforePendingInterruptCompletesOnce() {
        let interruptRan = expectation(description: "interrupt block ran")
        DispatchQueue.main.async {
            self.viewModel.endCheck(with: .viewResignation)
            interruptRan.fulfill()
        }

        viewModel.endCheck(with: .userCancelled)

        wait(for: [interruptRan], timeout: 1)
        XCTAssertEqual(terminalStates, [.encounteredUnrecoverableError(.userCancelled)])
        XCTAssertEqual(viewModel.livenessState.state, .encounteredUnrecoverableError(.userCancelled))
    }

    /// Given: A check that has already been interrupted by a rotation
    /// When: The user cancels from the rotate prompt
    /// Then: Nothing further is published; the interruption stands
    func testCancelAfterInterruptIsIgnored() {
        viewModel.endCheck(with: .viewResignation)

        viewModel.endCheck(with: .userCancelled)

        XCTAssertEqual(terminalStates, [.encounteredUnrecoverableError(.viewResignation)])
    }

    /// Given: A check that completed successfully
    /// When: A rotation interrupt and a cancel both arrive during dismissal
    /// Then: Neither publishes; the success is the only terminal state
    func testExitsAfterCompletionAreIgnored() {
        viewModel.livenessState.complete()

        viewModel.endCheck(with: .viewResignation)
        viewModel.endCheck(with: .userCancelled)

        XCTAssertEqual(terminalStates, [.completed])
    }

    /// Given: A check in progress
    /// When: The same exit is requested twice in a row
    /// Then: The terminal state is published once, not re-published by the second call
    func testRepeatedExitPublishesOnce() {
        viewModel.endCheck(with: .userCancelled)
        viewModel.endCheck(with: .userCancelled)

        XCTAssertEqual(terminalStates.count, 1)
    }

    /// Given: A check that has not started recording
    /// When: The user cancels
    /// Then: The cancellation is published, so the prompt can be dismissed before the camera runs
    func testCancelBeforeRecordingIsPublished() {
        viewModel.livenessState = .init(state: .initial)

        viewModel.endCheck(with: .userCancelled)

        XCTAssertEqual(terminalStates, [.encounteredUnrecoverableError(.userCancelled)])
    }
}
