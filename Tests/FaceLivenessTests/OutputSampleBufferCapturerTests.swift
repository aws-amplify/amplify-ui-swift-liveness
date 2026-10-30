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

    // MARK: - Diagnostics

    /// Tells `capturer` the camera dropped a frame, as AVFoundation does.
    private func dropFrame(on capturer: OutputSampleBufferCapturer) throws {
        let output = AVCaptureVideoDataOutput()
        let connection = AVCaptureConnection(inputPorts: [], output: output)
        capturer.captureOutput(output, didDrop: try makeFrame(at: 0), from: connection)
    }

    /// A sample buffer that carries no image.
    private func makeSampleBufferWithoutImage() throws -> CMSampleBuffer {
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreate(
            allocator: nil, dataBuffer: nil, dataReady: true, makeDataReadyCallback: nil, refcon: nil,
            formatDescription: nil, sampleCount: 0, sampleTimingEntryCount: 0, sampleTimingArray: nil,
            sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sampleBuffer
        )
        return try XCTUnwrap(sampleBuffer)
    }

    /// Given: A capturer with diagnostics, and the get ready screen showing its camera
    /// When: A frame, a buffer without an image and a drop arrive, then again once the check has the camera
    /// Then: FirstFrame is logged during the preview; only the check's buffers count, one as a noImageBuffer failure
    func testDiagnosticsCountOnlyTheChecksFrames() throws {
        let logger = MockLogger()
        let diagnostics = LivenessDiagnosticsFixture.makeDiagnostics(logger: logger)
        capturer = OutputSampleBufferCapturer(
            faceDetector: faceDetector,
            videoChunker: videoChunker,
            diagnostics: diagnostics
        )
        let previewed = EventLog<String>()
        capturer.previewFrameHandler.value = { _ in previewed.append("frame") }
        func deliver() throws {
            capturer.handle(try makeFrame(at: 0))
            capturer.handle(try makeSampleBufferWithoutImage())
            try dropFrame(on: capturer)
        }

        try deliver()
        let linesDuringPreview = logger.messages
        capturer.previewFrameHandler.value = nil
        diagnostics.onCheckStarted()
        try deliver()
        diagnostics.emitWatchdogSnapshot()
        diagnostics.onTeardown()

        XCTAssertEqual(linesDuringPreview.map { line in line.prefix { $0 != "(" } }, ["Liveness FirstFrame"])
        XCTAssertEqual(logger.lines(named: "AnalyzeFailed"), [
            "Liveness AnalyzeFailed(sessionId=session-1, stage=noImageBuffer, cause=null)"
        ])
        XCTAssertEqual(logger.lines(named: "FaceDetectionWatchdog").first.map(fields(of:))?["framesDelivered"], "2")
        let sessionEnded = logger.lines(named: "SessionEnded").first.map(fields(of:)) ?? [:]
        XCTAssertEqual(sessionEnded["framesDropped"], "1")
        XCTAssertEqual(sessionEnded["analyzeErrors"], "1")
        XCTAssertEqual(previewed.events, ["frame"])
        XCTAssertEqual(faceDetector.interactions, ["detectFaces(from:)"])
    }
}
