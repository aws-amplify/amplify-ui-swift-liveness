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
            videoChunker: videoChunker,
            closeButtonAction: {},
            sessionID: UUID().uuidString,
            isPreviewScreenEnabled: false,
            challengeOptions: .init(faceMovementChallengeOption: .init(camera: .front),
                                    faceMovementAndLightChallengeOption: .init())
        )

        self.videoChunker = videoChunker
        self.viewModel = viewModel
    }
    
    override func tearDown() {
        self.faceDetector = nil
        self.livenessService = nil
        self.videoChunker = nil
        self.viewModel = nil
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
        viewModel.challengeReceived = Challenge(version: "2.0.0", type: .faceMovementAndLightChallenge)
        viewModel.challengeReceived = Challenge(version: "2.0.0", type: .faceMovementAndLightChallenge)

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
                    "initializeLivenessStream(withSessionID:userAgent:challenges:options:)"
        ])
    }
    
    /// Given:  A `FaceLivenessDetectionViewModel`
    /// When: The viewModel is processes a single face result with a face distance less than the inital face distance
    /// Then: The end state of this flow is `.recording(ovalDisplayed: false)`
    func testTransitionToRecordingState() async throws {
        viewModel.livenessService = self.livenessService
        viewModel.challengeReceived = Challenge(version: "2.0.0", type: .faceMovementAndLightChallenge)
        
        let face = FaceLivenessSession.OvalMatchChallenge.Face(
            distanceThreshold: 0.32,
            distanceThresholdMax: 0.1,
            distanceThresholdMin: 0.1,
            iouWidthThreshold: 0.1,
            iouHeightThreshold: 0.1
        )
        
        let oval = FaceLivenessSession.OvalMatchChallenge.Oval(boundingBox: .init(x: 0.1,
                                                                                  y: 0.1,
                                                                                  width: 0.1,
                                                                                  height: 0.1),
                                                               heightWidthRatio: 1.618,
                                                               iouThreshold: 0.1,
                                                               iouWidthThreshold: 0.1,
                                                               iouHeightThreshold: 0.1,
                                                               ovalFitTimeout: 1)
        
        viewModel.sessionConfiguration = .init(ovalMatchChallenge: .init(faceDetectionThreshold: 0.7,
                                                                         face: face,
                                                                         oval: oval))

        viewModel.livenessState.checkIsFacePrepared()
        XCTAssertEqual(viewModel.livenessState.state, .pendingFacePreparedConfirmation(.pendingCheck))
        XCTAssertEqual(faceDetector.interactions, [
            "setResultHandler(detectionResultHandler:) (FaceLivenessDetectionViewModel)"
        ])
        XCTAssertEqual(livenessService.interactions, [])

        let boundingBox = CGRect(x: 0.26788579725878847, y: 0.40317180752754211, width: 0.45549795395626447, height: 0.34162446856498718)
        let leftEye = CGPoint(x: 0.61124476128552629, y: 0.4918237030506134)
        let rightEye = CGPoint(x: 0.38036393762719456, y: 0.48050540685653687)
        let nose = CGPoint(x: 0.48489856674964926, y: 0.54713362455368042)
        let mouth = CGPoint(x: 0.47411978167652435, y: 0.63170802593231201)
        let leftEar = CGPoint(x: 0.7898947484263203, y: 0.5973731875419617)
        let rightEar = CGPoint(x: 0.1658528943614037, y: 0.5668278932571411)
        let detectedFace = DetectedFace(boundingBox: boundingBox, leftEye: leftEye, rightEye: rightEye, nose: nose, mouth: mouth, rightEar: rightEar, leftEar: leftEar, confidence: 0.971859633)
        viewModel.process(newResult: .singleFace(detectedFace))
        try await Task.sleep(seconds: 1)

        XCTAssertEqual(viewModel.livenessState.state, .recording(ovalDisplayed: false))
        XCTAssertEqual(faceDetector.interactions, [
            "setResultHandler(detectionResultHandler:) (FaceLivenessDetectionViewModel)"
        ])
    }
    
    /// Given:  A `FaceLivenessDetectionViewModel`
    /// When: The viewModel handles a no fit event over a client default time limit of 7 seconds
    /// Then: The end state is `.encounteredUnrecoverableError(.timedOut)`
    func testNoFitTimeoutCheck() async throws {
        viewModel.livenessService = self.livenessService
        self.viewModel.handleNoFaceFit(instruction: .tooFar(nearnessPercentage: 0.2), percentage: 0.2)
        
        XCTAssertNotEqual(self.viewModel.livenessState.state, .encounteredUnrecoverableError(.timedOut))
        try await Task.sleep(seconds: 6)
        self.viewModel.handleNoFaceFit(instruction: .tooFar(nearnessPercentage: 0.2), percentage: 0.2)
        XCTAssertNotEqual(self.viewModel.livenessState.state,  .encounteredUnrecoverableError(.timedOut))
        try await Task.sleep(seconds: 1)
        self.viewModel.handleNoFaceFit(instruction: .tooFar(nearnessPercentage: 0.2), percentage: 0.2)
        try await Task.sleep(seconds: 1)
        XCTAssertEqual(self.viewModel.livenessState.state,  .encounteredUnrecoverableError(.timedOut))
    }
    
    /// Given:  A `FaceLivenessDetectionViewModel`
    /// When: The viewModel handles a no face detected event over a duration of 7 seconds
    /// Then: The end state is `.encounteredUnrecoverableError(.timedOut)`
    func testNoFaceDetectedTimeoutCheck() async throws {
        viewModel.livenessService = self.livenessService
        self.viewModel.handleNoFaceDetected()
        
        XCTAssertNotEqual(self.viewModel.livenessState.state, .encounteredUnrecoverableError(.timedOut))
        try await Task.sleep(seconds: 6)
        self.viewModel.handleNoFaceFit(instruction: .tooFar(nearnessPercentage: 0.2), percentage: 0.2)
        XCTAssertNotEqual(self.viewModel.livenessState.state,  .encounteredUnrecoverableError(.timedOut))
        try await Task.sleep(seconds: 1)
        self.viewModel.handleNoFaceDetected()
        try await Task.sleep(seconds: 1)
        XCTAssertEqual(self.viewModel.livenessState.state,  .encounteredUnrecoverableError(.timedOut))
    }
    
    /// Given:  A `FaceLivenessDetectionViewModel`
    /// When: The initializeLivenessStream() is called for the first time and then called again after 3 seconds
    /// Then: The attempt count is incremented
    func testAttemptCountIncrementFirstTime() async throws {
        viewModel.livenessService = self.livenessService
        self.viewModel.initializeLivenessStream()
        XCTAssertEqual(livenessService.interactions, [
                    "initializeLivenessStream(withSessionID:userAgent:challenges:options:)"
        ])
        
        XCTAssertEqual(FaceLivenessDetectionViewModel.attemptCount, 1)
        try await Task.sleep(seconds: 3)
        
        self.viewModel.initializeLivenessStream()
        XCTAssertEqual(livenessService.interactions, [
                    "initializeLivenessStream(withSessionID:userAgent:challenges:options:)",
                    "initializeLivenessStream(withSessionID:userAgent:challenges:options:)"
        ])
        XCTAssertEqual(FaceLivenessDetectionViewModel.attemptCount, 2)
    }
    
    /// Given:  A `FaceLivenessDetectionViewModel`
    /// When: The attempt count is 4, last attempt time was < 5 minutes and initializeLivenessStream() is called
    /// Then: The attempt count is incremented
    func testAttemptCountIncrement() async throws {
        viewModel.livenessService = self.livenessService
        FaceLivenessDetectionViewModel.attemptCount = 4
        FaceLivenessDetectionViewModel.attemptIdTimeStamp = Date().addingTimeInterval(-180)
        self.viewModel.initializeLivenessStream()
        XCTAssertEqual(livenessService.interactions, [
                    "initializeLivenessStream(withSessionID:userAgent:challenges:options:)"
        ])
        
        XCTAssertEqual(FaceLivenessDetectionViewModel.attemptCount, 5)
    }
    
    /// Given:  A `FaceLivenessDetectionViewModel`
    /// When: The attempt count is 4, last attempt time was > 5 minutes and initializeLivenessStream() is called
    /// Then: The attempt count is not incremented and reset to 1
    func testAttemptCountReset() async throws {
        viewModel.livenessService = self.livenessService
        FaceLivenessDetectionViewModel.attemptCount = 4
        FaceLivenessDetectionViewModel.attemptIdTimeStamp = Date().addingTimeInterval(-305)
        self.viewModel.initializeLivenessStream()
        XCTAssertEqual(livenessService.interactions, [
                    "initializeLivenessStream(withSessionID:userAgent:challenges:options:)"
        ])
        
        XCTAssertEqual(FaceLivenessDetectionViewModel.attemptCount, 1)
    }
}
