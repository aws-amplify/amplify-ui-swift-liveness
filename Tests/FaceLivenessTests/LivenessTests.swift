import XCTest
import Combine
@testable import FaceLiveness
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

@MainActor
final class FaceLivenessDetectionViewModelTestCase: XCTestCase {
    var videoChunker: VideoChunker!
    var viewModel: FaceLivenessDetectionViewModel!

    override func setUp() {
        let faceDetector = MockFaceDetector()
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
        viewModel.livenessService = MockLivenessService()
        XCTAssertEqual(viewModel.livenessState.state, .initial)
    }

    /// Given:  A `FaceLivenessDetectionViewModel`
    /// When: The viewModel is processes the happy path events
    /// Then: The end state of this flow is `.faceMatched`
    func testHappyPathToMatchedFace() async throws {
        viewModel.livenessService = MockLivenessService()

        viewModel.livenessState.checkIsFacePrepared()
        XCTAssertEqual(viewModel.livenessState.state, .pendingFacePreparedConfirmation(.pendingCheck))

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
    }

    /// Given:  A `FaceLivenessDetectionViewModel`
    /// When: The viewModel state `.countingDown` and receives
    /// an event from the face detector with `.noFace`
    /// Then: The flow bails with an `encounteredUnrecoverableError(.invalidFaceMovementDuringCountdown)`
    var stateChangeCancellable: Set<AnyCancellable>!
    func testInvalidFaceMovementDuringCountdown() {
        stateChangeCancellable = Set<AnyCancellable>()
        viewModel.livenessService = MockLivenessService()
        viewModel.livenessState.checkIsFacePrepared()
        viewModel.livenessState.startCountdown()
        XCTAssertEqual(viewModel.livenessState.state, .countingDown)

        let stateChangeExpectation = expectation(
            description: "waiting on state change after invalid face movement"
        )

        viewModel.$livenessState
            .drop(while: { $0.state == .countingDown })
            .sink { stateMachine in
                XCTAssertEqual(
                    stateMachine.state,
                    .encounteredUnrecoverableError(.invalidFaceMovementDuringCountdown)
                )
                stateChangeExpectation.fulfill()
            }
        .store(in: &stateChangeCancellable)

        viewModel.process(newResult: .noFace)
        wait(for: [stateChangeExpectation], timeout: 0.1)
    }
}
