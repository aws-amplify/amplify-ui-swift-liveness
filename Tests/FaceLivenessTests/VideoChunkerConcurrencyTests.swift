//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import AVFoundation
@testable import FaceLiveness

/// Regression tests for #275: `VideoChunker.consume(_:)` appended a pixel buffer guarded only by
/// its own `state` flag and input readiness, never serialized with `finish(_:)`. A frame that
/// passed the guards on the capture queue could reach `pixelBufferAdaptor.append(...)` while
/// `finishWriting(...)` was in flight on the main actor, and AVFoundation raised
/// `NSInternalInconsistencyException`, crashing the app.
///
/// These tests drive the real `VideoChunker`. `_reproHookAfterGuards` is the nil-by-default
/// test-only seam that parks a frame after every guard passed (inside the fix's critical section),
/// so the late-frame-vs-finish ordering is deterministic rather than a probabilistic field race.
final class VideoChunkerConcurrencyTests: XCTestCase {
    private var videoChunker: VideoChunker!

    override func setUp() {
        VideoChunker._reproHookAfterGuards = nil
        videoChunker = VideoChunker(
            assetWriter: LivenessAVAssetWriter(),
            assetWriterDelegate: VideoChunker.AssetWriterDelegate(),
            assetWriterInput: LivenessAVAssetWriterInput()
        )
    }

    override func tearDown() {
        VideoChunker._reproHookAfterGuards = nil
        videoChunker = nil
    }

    /// Given: a frame that passed every guard and is about to append on the capture queue
    /// When: `finish(_:)` runs concurrently on another thread
    /// Then: `finish(_:)` waits for the in-flight append (serialized), and the append never runs
    ///       against an ended session — no `NSInternalInconsistencyException`.
    ///
    /// Against unfixed 1.5.2 this fails: `finish(_:)` does not wait, so it calls `finishWriting`
    /// while the parked append is still pending, and releasing the append crashes with the #275
    /// signature.
    func testFinishWaitsForInFlightAppendAndDoesNotCrash() throws {
        videoChunker.prepare()
        videoChunker.start()
        // Prime: first append establishes the writer session.
        videoChunker.consume(try makeFrame(at: 0))
        waitForWriter(of: videoChunker, toReach: .writing)
        waitUntilInputReady()

        let reachedAppend = DispatchSemaphore(value: 0)
        let allowAppend = DispatchSemaphore(value: 0)

        // One-shot: park the late frame after it passed every guard, before the append. On the
        // fixed code this runs inside the critical section, holding `writerLock`.
        VideoChunker._reproHookAfterGuards = {
            VideoChunker._reproHookAfterGuards = nil
            reachedAppend.signal()
            _ = allowAppend.wait(timeout: .now() + 5)
        }

        let lateFrame = try makeFrame(at: 1.0 / 30.0)
        DispatchQueue(label: "test.capture").async {
            self.videoChunker.consume(lateFrame)
        }

        XCTAssertEqual(
            reachedAppend.wait(timeout: .now() + 5), .success,
            "the late consume never reached the append point"
        )

        // Call finish() off the test thread so we can observe whether it blocks.
        let finishReturned = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            self.videoChunker.finish(singleFrame: { _ in }, onFinished: {})
            finishReturned.signal()
        }

        // Fixed: finish() blocks on `writerLock` until the in-flight append returns.
        // Unfixed: finish() does not wait, so this fails — and the released append then crashes.
        XCTAssertEqual(
            finishReturned.wait(timeout: .now() + 1), .timedOut,
            "finish() must wait for the in-flight append (serialization fix for #275)"
        )

        // Release the parked append. On fixed code the writer is still writing (finish is blocked,
        // has not set finishInitiated or called finishWriting), so the append succeeds; no crash.
        allowAppend.signal()

        XCTAssertEqual(
            finishReturned.wait(timeout: .now() + 5), .success,
            "finish() should complete once the append released the lock"
        )
    }

    /// Given: a chunker that finished recording
    /// When: more frames arrive afterwards
    /// Then: they are dropped without appending and without crashing.
    func testFramesConsumedAfterFinishAreDropped() throws {
        videoChunker.start()
        try recordFrames(into: videoChunker)

        let finished = expectation(description: "onFinished")
        videoChunker.finish(singleFrame: { _ in }, onFinished: { finished.fulfill() })
        wait(for: [finished], timeout: 5)

        // First post-finish frame is taken as the single still frame; the next is dropped. Neither
        // is appended to the finished writer, and neither crashes.
        videoChunker.consume(try makeFrame(at: 1.0))
        videoChunker.consume(try makeFrame(at: 2.0))

        XCTAssertNotEqual(videoChunker.assetWriter.status, .failed)
        XCTAssertEqual(videoChunker.state, .complete)
    }

    /// Given: a chunker that recorded some video
    /// When: it finishes and one more frame arrives
    /// Then: that frame is delivered as the single still frame and the chunker completes.
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
