import XCTest
import Combine
@testable import FaceLiveness
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

@MainActor
final class FaceLivenessDetectionViewModelTestCase: XCTestCase {
    var videoChunker: VideoChunker!
    var viewModel: FaceLivenessDetectionViewModel!
    var faceDetector: MockFaceDetector!
    var livenessService: MockLivenessService!

    override func setUp() {
        faceDetector = MockFaceDetector()
        livenessService = MockLivenessService()
        let videoChunker = VideoChunker(
            assetWriter: LivenessAVAssetWriter(),
            assetWriterDelegate: VideoChunker.AssetWriterDelegate(),
            assetWriterInput: LivenessAVAssetWriterInput()
        )
        let captureSession = LivenessCaptureSession(
            captureDevice: .init(avCaptureDevice: nil),
            outputDelegate: OutputSampleBufferCapturer(
                faceDetector: faceDetector,
                videoChunker: videoChunker
            )
        )

        let viewModel = FaceLivenessDetectionViewModel(
            faceDetector: faceDetector,
            faceInOvalMatching: .init(instructor: .init()),
            captureSession: captureSession,
            videoChunker: videoChunker,
            closeButtonAction: {},
            sessionID: UUID().uuidString
        )

        self.videoChunker = videoChunker
        self.viewModel = viewModel
    }

    /// Given:  A `FaceLivenessDetectionViewModel`
    /// When: The viewModel is first initialized
    /// Then: The state is `.intitial`
    func testInitialState() {
        // This first call comes from the FaceLivenessDetectionViewModel's initializer
        XCTAssertEqual(faceDetector.interactions, [
            "setResultHandler(detectionResultHandler:) (FaceLivenessDetectionViewModel)"
        ])
        XCTAssertEqual(livenessService.interactions, [])

        viewModel.livenessService = self.livenessService
        XCTAssertEqual(viewModel.livenessState.state, .initial)
        XCTAssertEqual(faceDetector.interactions, [
            "setResultHandler(detectionResultHandler:) (FaceLivenessDetectionViewModel)"
        ])
        XCTAssertEqual(livenessService.interactions, [])
    }

    /// Given:  A `FaceLivenessDetectionViewModel`
    /// When: The viewModel is processes the happy path events
    /// Then: The end state of this flow is `.faceMatched`
    func testHappyPathToMatchedFace() async throws {
        viewModel.livenessService = self.livenessService

        viewModel.livenessState.checkIsFacePrepared()
        XCTAssertEqual(viewModel.livenessState.state, .pendingFacePreparedConfirmation(.pendingCheck))
        XCTAssertEqual(faceDetector.interactions, [
            "setResultHandler(detectionResultHandler:) (FaceLivenessDetectionViewModel)"
        ])
        XCTAssertEqual(livenessService.interactions, [])

        viewModel.initializeLivenessStream()
        viewModel.process(newResult: .noFace)
        XCTAssertEqual(videoChunker.state, .pending)

        viewModel.sendInitialFaceDetectedEvent(
            initialFace: .zero,
            videoStartTime: Date().timestampMilliseconds
        )
        XCTAssertEqual(videoChunker.state, .writing)

        let initialSegment = Data([0, 1])
        var currentSegment = Data([25, 42])
        XCTAssertFalse(viewModel.hasSentFirstVideo)
        let chunk = viewModel.chunk(initial: initialSegment, current: currentSegment)
        XCTAssertEqual(chunk, initialSegment + currentSegment)
        XCTAssertTrue(viewModel.hasSentFirstVideo)

        currentSegment = Data([42, 25])
        let subsequentChunk = viewModel.chunk(initial: initialSegment, current: currentSegment)
        XCTAssertEqual(subsequentChunk, currentSegment)

        viewModel.livenessState.faceMatched()
        XCTAssertEqual(viewModel.livenessState.state, .faceMatched)
        XCTAssertEqual(faceDetector.interactions, [
            "setResultHandler(detectionResultHandler:) (FaceLivenessDetectionViewModel)"
        ])
        XCTAssertEqual(livenessService.interactions, [
            "initializeLivenessStream(withSessionID:userAgent:)"
        ])
    }
    
    /// Given:  A `FaceLivenessDetectionViewModel`
    /// When: The viewModel is processes a single face result with a face distance less than the inital face distance
    /// Then: The end state of this flow is `.recording(ovalDisplayed: false)` and initializeLivenessStream(withSessionID:userAgent:) is called
    func testTransitionToRecordingState() async throws {
        viewModel.livenessService = self.livenessService

        viewModel.livenessState.checkIsFacePrepared()
        viewModel.process(newResult: .noFace)
        try await Task.sleep(seconds: 1)

        XCTAssertEqual(viewModel.livenessState.state, .recording(ovalDisplayed: false))
        XCTAssertEqual(faceDetector.interactions, [
            "setResultHandler(detectionResultHandler:) (FaceLivenessDetectionViewModel)"
        ])
        XCTAssertEqual(livenessService.interactions, [
            "initializeLivenessStream(withSessionID:userAgent:)"
        ])
    }
    
    /// Given:  A `FaceLivenessDetectionViewModel`
    /// When: The viewModel handles a no match event over a duration of 7 seconds
    /// Then: The end state is `.encounteredUnrecoverableError(.timedOut)`
    func testNoMatchTimeoutCheck() async throws {
        viewModel.livenessService = self.livenessService
        self.viewModel.handleNoMatch(instruction: .tooFar(nearnessPercentage: 0.2), percentage: 0.2)
        
        XCTAssertNotEqual(self.viewModel.livenessState.state, .encounteredUnrecoverableError(.timedOut))
        try await Task.sleep(seconds: 6)
        self.viewModel.handleNoMatch(instruction: .tooFar(nearnessPercentage: 0.2), percentage: 0.2)
        XCTAssertNotEqual(self.viewModel.livenessState.state,  .encounteredUnrecoverableError(.timedOut))
        try await Task.sleep(seconds: 1)
        self.viewModel.handleNoMatch(instruction: .tooFar(nearnessPercentage: 0.2), percentage: 0.2)
        XCTAssertEqual(self.viewModel.livenessState.state,  .encounteredUnrecoverableError(.timedOut))
    }
}
