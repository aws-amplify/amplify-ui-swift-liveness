//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import AVFoundation
@testable import FaceLiveness

/// Regression tests for #275: a frame appended while `finish(...)` was running crashed the writer.
final class VideoChunkerConcurrencyTests: XCTestCase {
    private var videoChunker: VideoChunker!

    override func setUp() {
        videoChunker = VideoChunker(
            assetWriter: LivenessAVAssetWriter(),
            assetWriterDelegate: VideoChunker.AssetWriterDelegate(),
            assetWriterInput: LivenessAVAssetWriterInput()
        )
    }

    override func tearDown() {
        videoChunker = nil
    }

    /// Given: A frame that passed every check and is about to be appended
    /// When: `finish(...)` is called on another thread
    /// Then: `finish(...)` waits until the append has returned
    func testFinishWaitsForInFlightAppend() throws {
        videoChunker.prepare()
        videoChunker.start()
        videoChunker.consume(try makeFrame(at: 0))
        waitForWriter(of: videoChunker, toReach: .writing)
        waitUntilInputReady()

        let reachedAppend = DispatchSemaphore(value: 0)
        let allowAppend = DispatchSemaphore(value: 0)
        let finishReturned = DispatchSemaphore(value: 0)
        let appendRecorded = DispatchSemaphore(value: 0)
        let finishRecorded = DispatchSemaphore(value: 0)
        let order = EventLog<String>()

        // hold the frame right before the append until released
        videoChunker.onAppendWillStart = { [weak self] in
            self?.videoChunker.onAppendWillStart = nil
            reachedAppend.signal()
            _ = allowAppend.wait(timeout: .now() + 5)
        }

        let lateFrame = try makeFrame(at: 1.0 / 30.0)
        DispatchQueue(label: "test.capture").async {
            self.videoChunker.consume(lateFrame)
            order.append("append")
            appendRecorded.signal()
        }

        XCTAssertEqual(
            reachedAppend.wait(timeout: .now() + 5), .success,
            "the late consume never reached the append point"
        )

        DispatchQueue.global().async {
            self.videoChunker.finish(singleFrame: { _ in }, onFinished: {})
            order.append("finish")
            finishRecorded.signal()
            finishReturned.signal()
        }

        let finishReturnedWhileAppendInFlight = finishReturned.wait(timeout: .now() + 1) == .success
        XCTAssertFalse(
            finishReturnedWhileAppendInFlight,
            "finish() must wait for the in-flight append (serialization fix for #275)"
        )

        allowAppend.signal()

        // the wait above already consumed the signal if `finish` returned
        if !finishReturnedWhileAppendInFlight {
            XCTAssertEqual(
                finishReturned.wait(timeout: .now() + 5), .success,
                "finish() should complete once the append released the lock"
            )
        }

        XCTAssertEqual(appendRecorded.wait(timeout: .now() + 5), .success, "append never returned")
        XCTAssertEqual(finishRecorded.wait(timeout: .now() + 5), .success, "finish never returned")
        XCTAssertEqual(
            order.events, ["append", "finish"],
            "the in-flight append must return before finish() returns (serialized by writerLock)"
        )
    }

    /// Given: A chunker that finished recording
    /// When: More frames arrive
    /// Then: The first becomes the single frame, the rest are dropped, and nothing is appended
    func testFramesConsumedAfterFinishAreDropped() throws {
        videoChunker.start()
        try recordFrames(into: videoChunker)

        let finished = expectation(description: "onFinished")
        videoChunker.finish(singleFrame: { _ in }, onFinished: { finished.fulfill() })
        wait(for: [finished], timeout: 5)

        videoChunker.consume(try makeFrame(at: 1.0))
        videoChunker.consume(try makeFrame(at: 2.0))

        XCTAssertNotEqual(videoChunker.assetWriter.status, .failed)
        XCTAssertEqual(videoChunker.state, .complete)
    }

    /// Given: A chunker that recorded some video
    /// When: It finishes and one more frame arrives
    /// Then: That frame is delivered as the single frame
    func testSingleFramePathStillDeliversFrame() throws {
        videoChunker.start()
        try recordFrames(into: videoChunker)

        let delivered = expectation(description: "single frame delivered")
        let finished = expectation(description: "onFinished")
        videoChunker.finish(
            singleFrame: { _ in delivered.fulfill() },
            onFinished: { finished.fulfill() }
        )
        wait(for: [finished], timeout: 5)

        videoChunker.consume(try makeFrame(at: 1.0))

        wait(for: [delivered], timeout: 5)
        XCTAssertEqual(videoChunker.state, .complete)
    }

    // MARK: - Helpers

    private func waitUntilInputReady(file: StaticString = #filePath, line: UInt = #line) {
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                self.videoChunker.assetWriterInput.isReadyForMoreMediaData
            },
            object: nil
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [ready], timeout: 5), .completed,
            "writer input never became ready", file: file, line: line
        )
    }
}
