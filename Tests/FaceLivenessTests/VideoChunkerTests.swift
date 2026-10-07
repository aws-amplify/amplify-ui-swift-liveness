//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import AVFoundation
@testable import FaceLiveness

final class VideoChunkerTests: XCTestCase {
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

    /// Given: A chunker that hasn't started recording
    /// When: It's prepared
    /// Then: The writer starts in the background, and recording still waits for `start()`
    func testPrepareStartsTheWriterBeforeRecording() {
        videoChunker.prepare()

        waitForWriter(of: videoChunker, toReach: .writing)
        XCTAssertEqual(videoChunker.state, .pending)
    }

    /// Given: A chunker prepared more than once
    /// When: Recording starts
    /// Then: It records on the writer that's already started, without starting it again
    func testStartAfterPrepareRecords() {
        videoChunker.prepare()
        videoChunker.prepare()

        videoChunker.start()

        XCTAssertEqual(videoChunker.assetWriter.status, .writing)
        XCTAssertEqual(videoChunker.state, .writing)
    }

    /// Given: A chunker that was never prepared
    /// When: Recording starts
    /// Then: `start()` starts the writer itself
    func testStartWithoutPrepareStartsTheWriter() {
        videoChunker.start()

        XCTAssertEqual(videoChunker.assetWriter.status, .writing)
        XCTAssertEqual(videoChunker.state, .writing)
    }

    /// Given: A chunker that has recorded less than one segment's worth of video
    /// When: It's finished
    /// Then: The partial segment reaches the delegate before `onFinished` runs
    func testFinishDeliversTheLastSegmentBeforeOnFinished() throws {
        let log = EventLog<String>()
        let segmentLogger = SegmentLogger(log: log)
        self.segmentLogger = segmentLogger
        videoChunker.assetWriterDelegate.set(segmentProcessor: segmentLogger)
        videoChunker.start()
        try recordFrames(into: videoChunker)
        XCTAssertEqual(log.events, [], "a segment isn't due until a second of video")

        let finished = expectation(description: "onFinished")
        videoChunker.finish(singleFrame: { _ in }, onFinished: {
            log.append("finished")
            finished.fulfill()
        })

        wait(for: [finished], timeout: 5)
        XCTAssertEqual(log.events, ["segment", "finished"])
    }

    /// Given: A chunker that never started recording
    /// When: It's finished
    /// Then: `onFinished` runs straight away, so the check can still end
    func testFinishBeforeRecordingCallsOnFinished() {
        let log = EventLog<String>()

        videoChunker.finish(singleFrame: { _ in }, onFinished: { log.append("finished") })

        XCTAssertEqual(log.events, ["finished"])
    }

    /// Given: A chunker whose writer was prepared, but which never recorded
    /// When: It's finished
    /// Then: `onFinished` still runs
    func testFinishAfterPrepareCallsOnFinished() {
        videoChunker.prepare()
        waitForWriter(of: videoChunker, toReach: .writing)

        let finished = expectation(description: "onFinished")
        videoChunker.finish(singleFrame: { _ in }, onFinished: { finished.fulfill() })

        wait(for: [finished], timeout: 5)
    }

    // the writer's delegate holds its segment processor weakly
    private var segmentLogger: SegmentLogger?
}

/// Logs each segment the writer delivers.
private final class SegmentLogger: VideoSegmentProcessor {
    let log: EventLog<String>

    init(log: EventLog<String>) {
        self.log = log
    }

    func process(initalSegment: Data, currentSeparableSegment: Data) {
        log.append("segment")
    }
}
