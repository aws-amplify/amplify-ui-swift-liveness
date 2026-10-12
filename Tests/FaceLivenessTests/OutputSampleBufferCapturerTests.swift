//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import AVFoundation
@testable import FaceLiveness

final class OutputSampleBufferCapturerTests: XCTestCase {
    private var faceDetector: MockFaceDetector!
    private var videoChunker: VideoChunker!
    private var capturer: OutputSampleBufferCapturer!

    override func setUp() {
        faceDetector = MockFaceDetector()
        videoChunker = VideoChunker(
            assetWriter: LivenessAVAssetWriter(),
            assetWriterDelegate: VideoChunker.AssetWriterDelegate(),
            assetWriterInput: LivenessAVAssetWriterInput()
        )
        capturer = OutputSampleBufferCapturer(faceDetector: faceDetector, videoChunker: videoChunker)
    }

    override func tearDown() {
        faceDetector = nil
        videoChunker = nil
        capturer = nil
    }

    /// Given: The get ready screen showing the check's camera
    /// When: A frame arrives
    /// Then: It goes to the preview, not to face detection or the video
    func testFramesGoToThePreviewWhileItShows() throws {
        let previewed = EventLog<String>()
        capturer.previewFrameHandler.value = { _ in previewed.append("frame") }
        videoChunker.start()

        capturer.handle(try makeFrame(at: 0))

        XCTAssertEqual(previewed.events, ["frame"])
        XCTAssertEqual(faceDetector.interactions, [])
        XCTAssertNil(videoChunker.startTimeSeconds, "the frame was recorded")
    }

    /// Given: The check has taken over the camera from the get ready screen
    /// When: A frame arrives
    /// Then: It goes to face detection and the video again
    func testFramesGoToTheCheckOnceThePreviewStops() throws {
        let previewed = EventLog<String>()
        capturer.previewFrameHandler.value = { _ in previewed.append("frame") }
        videoChunker.start()

        capturer.previewFrameHandler.value = nil
        capturer.handle(try makeFrame(at: 0))

        XCTAssertEqual(previewed.events, [])
        XCTAssertEqual(faceDetector.interactions, ["detectFaces(from:)"])
        XCTAssertNotNil(videoChunker.startTimeSeconds, "the frame wasn't recorded")
    }

    /// Given: The get ready screen starting the check's camera
    /// When: Configuring the camera fails
    /// Then: No session is left for the check to reuse, and frames go to the check again, so
    ///       the check configures the camera itself and reports the error if it fails again
    func testFailedPreviewLeavesNoSessionForTheCheck() {
        let captureSession = LivenessCaptureSession(
            captureDevice: .init(avCaptureDevice: nil),
            outputDelegate: capturer
        )

        XCTAssertThrowsError(try captureSession.startPreview { _ in })

        XCTAssertNil(captureSession.captureSession)
        XCTAssertNil(capturer.previewFrameHandler.value)
    }
}
