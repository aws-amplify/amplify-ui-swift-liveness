//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import FaceLiveness
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

/// How a check ends once its challenge is over: the last of the video, then the final event,
/// then the empty video event that closes the stream.
@MainActor
final class FaceLivenessDetectionViewModelFinalEventTests: XCTestCase {
    private enum Sent: Equatable {
        case video
        case final
        case endOfVideo
    }

    private var viewModel: FaceLivenessDetectionViewModel!
    private var presenter: MockLivenessViewControllerPresenter!
    private var livenessService: MockLivenessService!
    private var sent: EventLog<Sent>!
    private var finalEvents: EventLog<[String: Any]>!

    override func tearDown() {
        viewModel = nil
        presenter = nil
        livenessService = nil
        sent = nil
        finalEvents = nil
    }

    /// Given: A light challenge check whose colors have just finished
    /// When: The freshness check completes
    /// Then: The partial last segment is sent, then the final event with the colors' end as the
    ///       end of the face match, then the end of the video, without waiting for more video
    func testFreshnessCompleteEndsTheCheckAfterTheLastOfTheVideo() throws {
        try startRecording(.faceMovementAndLight)
        try recordFrames(into: viewModel.videoChunker)
        viewModel.livenessState = .init(state: .displayingFreshness)

        let completed = Date().timestampMilliseconds
        viewModel.handleFreshnessComplete()
        let returned = Date().timestampMilliseconds

        wait(until: { self.sent.events.contains(.endOfVideo) })
        XCTAssertEqual(sent.events, [.video, .final, .endOfVideo])
        let faceMatchEnd = try sentTimestamp("FaceDetectedInTargetPositionEndTimestamp")
        XCTAssertTrue((completed...returned).contains(faceMatchEnd), "\(faceMatchEnd) not in \(completed)...\(returned)")
    }

    /// Given: A light challenge check whose colors have finished
    /// When: The end of the challenge is reported more than once
    /// Then: One final event is sent
    func testFinalEventIsSentOnce() throws {
        try startRecording(.faceMovementAndLight)
        try recordFrames(into: viewModel.videoChunker)
        viewModel.livenessState = .init(state: .displayingFreshness)

        viewModel.handleFreshnessComplete()
        viewModel.handleFreshnessComplete()
        viewModel.finishVideo()

        wait(until: { self.sent.events.contains(.endOfVideo) })
        waitForAnythingElse()
        XCTAssertEqual(sent.events, [.video, .final, .endOfVideo])
    }

    /// Given: A check whose challenge has finished
    /// When: More video segments arrive
    /// Then: They're sent as video, and none of them sends a final event
    func testVideoAfterTheChallengeDoesNotSendTheFinalEvent() throws {
        try startRecording(.faceMovementAndLight)
        viewModel.livenessState = .init(state: .completedDisplayingFreshness)

        viewModel.process(initalSegment: Data([0, 1]), currentSeparableSegment: Data([2, 3]))
        viewModel.process(initalSegment: Data([0, 1]), currentSeparableSegment: Data([4, 5]))

        waitForAnythingElse(timeout: 1.5)
        XCTAssertEqual(sent.events, [.video, .video])
    }

    /// Given: A check without the light challenge whose face has just matched the oval
    /// When: The check completes
    /// Then: The face guide stays up and recording goes on for a second, then the final event
    ///       reports a face match of that long
    func testNoLightCheckEndsASecondAfterTheFaceMatches() throws {
        try startRecording(.faceMovement)
        try recordFrames(into: viewModel.videoChunker)
        viewModel.livenessState = .init(state: .faceMatched)
        // as `handleInstruction` does, right before completing the check
        let faceMatchStart = Date().timestampMilliseconds
        viewModel.faceMatchedTimestamp = faceMatchStart

        viewModel.completeNoLightCheck()

        waitForAnythingElse()
        XCTAssertEqual(sent.events, [])
        XCTAssertEqual(viewModel.livenessState.state, .faceMatched)
        wait(until: { self.sent.events.contains(.endOfVideo) })
        XCTAssertEqual(sent.events, [.video, .final, .endOfVideo])
        XCTAssertEqual(viewModel.livenessState.state, .completedNoLightCheck)
        XCTAssertEqual(try sentTimestamp("FaceDetectedInTargetPositionStartTimestamp"), faceMatchStart)
        let faceMatchEnd = try sentTimestamp("FaceDetectedInTargetPositionEndTimestamp")
        // a full second, less at most a millisecond from truncating both times
        XCTAssertGreaterThanOrEqual(faceMatchEnd - faceMatchStart, 999)
    }

    /// Given: A check without the light challenge whose face has just matched the oval
    /// When: The user cancels during the second that's still being recorded
    /// Then: The cancellation stands and nothing more is sent
    func testNoLightCheckCancelledDuringTheLastSecondSendsNothing() throws {
        try startRecording(.faceMovement)
        try recordFrames(into: viewModel.videoChunker)
        viewModel.livenessState = .init(state: .faceMatched)

        viewModel.completeNoLightCheck()
        viewModel.endCheck(with: .userCancelled)

        waitForAnythingElse(timeout: 1.5)
        XCTAssertEqual(sent.events, [])
        XCTAssertEqual(viewModel.livenessState.state, .encounteredUnrecoverableError(.userCancelled))
    }

    /// Given: A light challenge check the user cancelled as the colors finished
    /// When: The freshness check completes
    /// Then: Nothing more is sent
    func testCheckThatHasEndedSendsNoFinalEvent() throws {
        try startRecording(.faceMovementAndLight)
        try recordFrames(into: viewModel.videoChunker)
        viewModel.endCheck(with: .userCancelled)

        viewModel.handleFreshnessComplete()

        waitForAnythingElse()
        XCTAssertEqual(sent.events, [])
        XCTAssertEqual(viewModel.livenessState.state, .encounteredUnrecoverableError(.userCancelled))
    }

    /// Sets up a check of `kind` that's recording, with the face matched in the oval.
    private func startRecording(_ kind: LivenessGeometryFixture.ChallengeKind) throws {
        presenter = MockLivenessViewControllerPresenter()
        viewModel = LivenessGeometryFixture.makeViewModel(presenter: presenter, kind: kind)
        viewModel.cameraViewRect = CGRect(origin: .zero, size: LivenessGeometryFixture.videoSize)

        let sent = EventLog<Sent>()
        let finalEvents = EventLog<[String: Any]>()
        livenessService = MockLivenessService()
        livenessService.onVideoEvent = { event, _ in
            let chunk = (try? sentJSON(event))?["VideoChunk"] as? String
            sent.append(chunk?.isEmpty == false ? .video : .endOfVideo)
        }
        livenessService.onFinalClientEvent = { event, _ in
            sent.append(.final)
            if let json = try? sentJSON(event) {
                finalEvents.append(json)
            }
        }
        self.sent = sent
        self.finalEvents = finalEvents
        viewModel.livenessService = livenessService

        viewModel.sendInitialFaceDetectedEvent(initialFace: CGRect(x: 120, y: 160, width: 240, height: 320))
        XCTAssertNotNil(viewModel.initialClientEvent)
        viewModel.faceMatchedTimestamp = Date().timestampMilliseconds
    }

    /// `key`'s value in the final event sent to the service.
    private func sentTimestamp(_ key: String) throws -> UInt64 {
        let finalEvent = try XCTUnwrap(finalEvents.events.first)
        let value = try XCTUnwrap(firstValue(forKey: key, in: finalEvent) as? NSNumber)
        return value.uint64Value
    }

    /// Waits for `condition`, which the writer and the service make true off the main thread.
    private func wait(until condition: @escaping () -> Bool) {
        let met = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        wait(for: [met], timeout: 5)
    }

    /// Lets anything still on its way arrive, so a test can check that nothing more was sent.
    private func waitForAnythingElse(timeout: TimeInterval = 0.5) {
        let nothing = expectation(description: "nothing")
        nothing.isInverted = true
        wait(for: [nothing], timeout: timeout)
    }
}
