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
}
