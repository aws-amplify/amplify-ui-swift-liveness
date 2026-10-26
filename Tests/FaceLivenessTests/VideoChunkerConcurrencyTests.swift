//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import AVFoundation
@testable import FaceLiveness

/// Regression test for #275: appending a frame while `finish(...)` ran crashed the app.
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

    /// Verifies that `finish(...)` waits for a frame already on its way to the writer.
    func testFinishWaitsForInFlightAppend() throws {
        videoChunker.prepare()
        videoChunker.start()
        videoChunker.consume(try makeFrame(at: 0))
        waitForWriter(of: videoChunker, toReach: .writing)
        waitUntilInputReady()

        let reachedAppend = DispatchSemaphore(value: 0)
        let allowAppend = DispatchSemaphore(value: 0)
        let finishReturned = DispatchSemaphore(value: 0)

        videoChunker.onAppendWillStart = { [weak self] in
            self?.videoChunker.onAppendWillStart = nil
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

        DispatchQueue.global().async {
            self.videoChunker.finish(singleFrame: { _ in }, onFinished: {})
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
