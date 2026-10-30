//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import Combine
import AVFoundation
@testable import FaceLiveness
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

/// The diagnostics hooks in `FaceLivenessDetectionViewModel` and its result handler: what each
/// one reports, and that the check behaves as it does without them.
@MainActor
final class FaceLivenessDetectionViewModelDiagnosticsTests: XCTestCase {
    private var logger: MockLogger!
    private var clock: TestClock!
    private var scheduler: ManualScheduler!
    private var diagnostics: LivenessSessionDiagnostics!
    private var presenter: MockLivenessViewControllerPresenter!
    private var cancellables: Set<AnyCancellable> = []

    /// A 480x640 preview at the origin, on which the service's oval keeps its video coordinates.
    private let previewRect = CGRect(origin: .zero, size: LivenessGeometryFixture.videoSize)

    override func setUp() {
        resetFixture()
    }

    override func tearDown() {
        cancellables.removeAll()
        FaceLivenessDetectionViewModel.attemptCount = 0
        FaceLivenessDetectionViewModel.attemptIdTimeStamp = Date()
    }

    // MARK: - Session and service events

    /// Given: A view model created without diagnostics, and one given them
    /// When: Their diagnostics are read
    /// Then: The first made its own, for its session; the second uses those it was given
    func testViewModelMakesItsOwnDiagnosticsOnlyWhenNotGivenThem() {
        let viewModel = LivenessGeometryFixture.makeViewModel(presenter: presenter)

        XCTAssertEqual(viewModel.diagnostics.sessionID, viewModel.sessionID)
        XCTAssertTrue(makeViewModel().diagnostics === diagnostics)
    }

    /// Given: A check a moment after its second attempt, and one with the pre-check screen 5 minutes after its fourth
    /// When: Each starts its stream, then a check can't start a session at all
    /// Then: SessionStarting reports the attempt the service is sent, the codec and the pre-check screen, then attempt=null
    func testSessionStartingReportsTheAttemptTheServiceIsSent() {
        let line = { (attempt: String, preCheck: Bool) in
            "Liveness SessionStarting(sessionId=session-1, attempt=\(attempt), "
                + "device=Apple/iPhone16,2, api=18.5, livenessVersion=1.5.3, codec=H264, "
                + "preCheckEnabled=\(preCheck), amplifyVersion=2.63.0, region=us-east-1)"
        }
        let rows: [(previous: Int, secondsAgo: TimeInterval, preCheck: Bool, attempt: Int)] = [(2, 0, false, 3), (4, 305, true, 1)]
        for row in rows {
            resetFixture()
            FaceLivenessDetectionViewModel.attemptCount = row.previous
            FaceLivenessDetectionViewModel.attemptIdTimeStamp = Date(timeIntervalSinceNow: -row.secondsAgo)
            let viewModel = makeUnconfiguredViewModel(isPreviewScreenEnabled: row.preCheck)
            let service = MockLivenessService()
            let sent = EventLog<FaceLivenessSession.Options>()
            service.onInitializeLivenessStream = { _, _, _, options in sent.append(options) }
            viewModel.livenessService = service

            viewModel.initializeLivenessStream()

            XCTAssertEqual(sent.events.map { $0.attemptCount }, [row.attempt], "\(row)")
            XCTAssertEqual(sent.events.map { $0.preCheckViewEnabled }, [row.preCheck], "\(row)")
            XCTAssertEqual(logger.messages, [line("\(row.attempt)", row.preCheck)], "\(row)")
        }

        resetFixture()
        makeUnconfiguredViewModel().logSessionStarting(attempt: nil)
        XCTAssertEqual(logger.messages, [line("null", false)])
    }

    /// Given: A view model registered for the service's events, before the session configuration arrives
    /// When: The service sends the configuration from its own queue, then the challenge
    /// Then: SessionReady reports the configuration and challenge ID, and the challenge's capture session shares the diagnostics
    func testServiceListenersReportTheSessionAndItsCaptureSession() throws {
        let viewModel = makeViewModel(kind: .faceMovementAndLight)
        viewModel.sessionConfiguration = nil
        let service = MockLivenessService()
        viewModel.livenessService = service
        viewModel.registerServiceEvents(onChallengeTypeReceived: { _ in })
        let listener = try XCTUnwrap(service.registeredSessionConfigurationListener)

        let delivered = expectation(description: "session configuration delivered")
        DispatchQueue(label: "test.websocket").async {
            listener(LivenessDiagnosticsFixture.movementAndLightConfiguration())
            delivered.fulfill()
        }
        wait(for: [delivered], timeout: 2)
        try XCTUnwrap(service.registeredChallengeListener)(.faceMovementAndLightChallenge("2.0.0"))

        XCTAssertEqual(logger.messages, ["Liveness SessionReady(sessionId=session-1, challengeType=FaceMovementAndLightChallenge, "
            + "challengeId=\(viewModel.challengeID), faceDetectionThreshold=0.7, targetIouThreshold=0.6, "
            + "ovalFitTimeout=30000)"])
        XCTAssertNotNil(viewModel.sessionConfiguration)
        XCTAssertTrue(try XCTUnwrap(viewModel.captureSession?.outputSampleBufferCapturer).diagnostics === viewModel.diagnostics)
    }

    /// Given: A view model that registered for the service's events twice, wrapping its exception handler twice
    /// When: The service reports from its own queue that the session wasn't found
    /// Then: One SessionError is logged before the host's handler runs, and the host is told once
    func testServiceExceptionIsLoggedOnceBeforeTheHostHearsOfIt() {
        let viewModel = makeViewModel()
        let service = MockLivenessService()
        let logger = self.logger!
        let hostCalls = EventLog<(error: FaceLivenessSessionError, logged: [String])>()
        service.onServiceException = { hostCalls.append(($0, logger.messages)) }
        viewModel.livenessService = service
        viewModel.registerServiceEvents(onChallengeTypeReceived: { _ in })
        viewModel.registerServiceEvents(onChallengeTypeReceived: { _ in })

        let reported = expectation(description: "exception reported")
        DispatchQueue(label: "test.liveness-service").async {
            service.onServiceException(.sessionNotFound)
            reported.fulfill()
        }
        wait(for: [reported], timeout: 2)

        let notFound = "Liveness SessionError(sessionId=session-1, type=sessionNotFound, "
            + "message=Session not found., cause=null, closeCode=RUNTIME_ERROR, "
            + "reason=service.sessionNotFound)"
        XCTAssertEqual(hostCalls.events.map { $0.error }, [.sessionNotFound])
        XCTAssertEqual(hostCalls.events.map { $0.logged }, [[notFound]])
        XCTAssertEqual(logger.messages, [notFound])
    }

    /// Given: A view model registered for the service's events
    /// When: The socket completes, then the host removes the detector
    /// Then: A disconnection ends it normally, 1011 fails the check with the code as cause, and 4003, the check's own code, logs nothing
    func testSocketCompletionReportsHowTheSessionEnded() throws {
        let rows: [(label: String, reason: ServerDisconnection, state: LivenessStateMachine.State, lines: [String])] = [
            ("disconnection event", .disconnectionEvent, .completed, [sessionEndedLine(closeCode: "NORMAL")]),
            ("1011", .unexpectedClosure(.internalServerError), .encounteredUnrecoverableError(.socketClosed), [
                "Liveness SessionError(sessionId=session-1, type=socketClosed, "
                    + "message=Websocket connection unexpectedly closed, cause=WebSocketCloseCode: 1011, "
                    + "closeCode=RUNTIME_ERROR, reason=socketClosed)",
                sessionEndedLine(closeCode: "RUNTIME_ERROR")
            ]),
            (
                "4003", .unexpectedClosure(try XCTUnwrap(URLSessionWebSocketTask.CloseCode(rawValue: 4003))), .initial,
                [sessionEndedLine(closeCode: "DISPOSED")]
            )
        ]
        for row in rows {
            resetFixture()
            let viewModel = makeViewModel()
            let service = MockLivenessService()
            viewModel.livenessService = service
            viewModel.registerServiceEvents(onChallengeTypeReceived: { _ in })

            try XCTUnwrap(service.registeredOnComplete)(row.reason)
            drainMainQueue()
            viewModel.diagnostics.onTeardown()

            XCTAssertEqual(viewModel.livenessState.state, row.state, row.label)
            XCTAssertEqual(logger.messages, row.lines, row.label)
        }
    }

    // MARK: - Errors

    /// Given: A check whose stream, camera or initial face event fails
    /// When: The failure reaches the check
    /// Then: SessionError cites the failure as its cause and the error the check ended with as its reason
    func testFailuresAreLoggedWithTheirCause() {
        let cameraError: LivenessStateMachine.LivenessError =
            AVCaptureDevice.authorizationStatus(for: .video) == .authorized ? .cameraNotAvailable : .missingVideoPermission
        let rows: [(label: String, error: LivenessStateMachine.LivenessError, cause: String, fail: (FaceLivenessDetectionViewModel) -> Void)] = [
            ("stream refused", .couldNotOpenStream, "TestStream(7): stream refused", { viewModel in
                viewModel.livenessService = StreamRefusingLivenessService()
                viewModel.initializeLivenessStream()
                XCTAssertEqual(self.logger.lines(named: "SessionStarting").count, 1, "logged before the stream fails")
            }),
            ("no camera", cameraError, "LivenessCaptureSessionError: cameraUnavailable", { viewModel in
                let capturer = OutputSampleBufferCapturer(faceDetector: viewModel.faceDetector, videoChunker: viewModel.videoChunker)
                viewModel.captureSession = LivenessCaptureSession(captureDevice: .init(avCaptureDevice: nil), outputDelegate: capturer)
                XCTAssertNil(viewModel.configureCamera(withinFrame: self.previewRect))
                XCTAssertTrue(self.scheduler.items.isEmpty, "a camera that can't be configured arms no watchdog")
            }),
            ("initial face on an empty preview", .unknown, "EncodingError: ", { viewModel in
                viewModel.livenessService = MockLivenessService()
                viewModel.cameraViewRect = .zero
                viewModel.sendInitialFaceDetectedEvent(initialFace: .zero)
                XCTAssertTrue(self.logger.lines(named: "InitialFaceDetected").isEmpty, "nothing was sent")
            })
        ]
        for row in rows {
            resetFixture()
            let viewModel = makeViewModel()
            row.fail(viewModel)
            drainMainQueue()

            XCTAssertEqual(viewModel.livenessState.state, .encounteredUnrecoverableError(row.error), row.label)
            let errors = logger.lines(named: "SessionError")
            XCTAssertEqual(errors.count, 1, row.label)
            XCTAssertTrue(errors.allSatisfy { $0.contains(", cause=\(row.cause)") }, "\(row.label): \(errors)")
            XCTAssertTrue(errors.allSatisfy { $0.hasSuffix(", reason=\(row.error.diagnosticName))") }, "\(row.label): \(errors)")
        }
    }

    /// Given: A movement check holding its matched face for its last second, observed as the detector view does
    /// When: The user cancels during that second, and the terminal state is published again
    /// Then: SessionError is logged before the observer sees the cancellation, once, and ChallengeCompleted never is
    func testCancellationIsLoggedOnceBeforeObserversSeeItAndSuppressesChallengeCompleted() {
        let cancelled = "Liveness SessionError(sessionId=session-1, type=userCancelled, "
            + "message=User cancelled the face liveness check., cause=null, closeCode=CANCELED, "
            + "reason=userCancelled)"
        let viewModel = makeViewModel()
        viewModel.livenessState = .init(state: .faceMatched)
        let logger = self.logger!
        let loggedWhenObserved = EventLog<[String]>()
        // endCheck, the republished .timedOut, then the delayed completedNoLightCheck
        let delayedCompletionRan = expectation(description: "delayed no-light completion ran")
        viewModel.$livenessState
            .dropFirst()
            .sink { _ in
                loggedWhenObserved.append(logger.messages)
                if loggedWhenObserved.events.count == 3 { delayedCompletionRan.fulfill() }
            }
            .store(in: &cancellables)

        viewModel.completeNoLightCheck()
        viewModel.endCheck(with: .userCancelled)
        viewModel.livenessState.unrecoverableStateEncountered(.timedOut)
        wait(for: [delayedCompletionRan], timeout: 5)
        drainMainQueue()

        XCTAssertEqual(viewModel.livenessState.state, .encounteredUnrecoverableError(.userCancelled))
        XCTAssertEqual(loggedWhenObserved.events.first, [cancelled])
        XCTAssertEqual(logger.messages, [cancelled])
    }

    // MARK: - Frames and faces

    /// Given: The view model as the detector holds it, confirming the face
    /// When: From the capture queue it reports frames before session ready, failed (then delivered as no face), without and with a face
    /// Then: Each report reaches diagnostics rather than the protocol's no-op, and the check sees the failed frame as no face
    func testFrameReportsFromTheCaptureQueueReachDiagnostics() throws {
        let viewModel = makeViewModel()
        viewModel.livenessState = .init(state: .pendingFacePreparedConfirmation(.pendingCheck))
        // the detector calls the view model from the capture queue
        nonisolated(unsafe) let handler = try resultHandler(of: viewModel)

        let reported = expectation(description: "frames reported")
        DispatchQueue(label: "test.capture").async {
            handler.process(frameReport: .init(topScore: 0.5, usedSessionThreshold: false))
            handler.process(frameReport: .init(failure: .init(stage: .prediction, cause: nil)))
            handler.process(newResult: .noFace)
            handler.process(frameReport: .init(faceCount: 0, topScore: 0.25, usedSessionThreshold: true))
            handler.process(frameReport: .init(faceCount: 1, topScore: 0.875, usedSessionThreshold: true))
            reported.fulfill()
        }
        wait(for: [reported], timeout: 2)
        drainMainQueue()

        XCTAssertEqual(viewModel.livenessState.state, .pendingFacePreparedConfirmation(.noFace))
        XCTAssertEqual(logger.messages, [
            "Liveness FrameBeforeSessionReady",
            "Liveness AnalyzeFailed(sessionId=session-1, stage=prediction, cause=null)",
            "Liveness FaceCountChanged(sessionId=session-1, from=0, to=1, framesAnalyzed=2, topScore=0.875, phase=PRE_CHECK)"
        ])
    }

    /// Given: A check in each state a single face can arrive in, with the oval drawn but no initial face sent
    /// When: A face arrives
    /// Then: Its distance alone is logged, and the check moves on as before
    func testFaceDistanceIsLoggedInEveryStateWithoutChangingTheCheck() {
        let far = "Liveness FaceDistanceChanged(sessionId=session-1, distance=0.0625, "
            + "faceDistanceThreshold=0.1, exceedsThreshold=false, phase=PRE_CHECK)"
        let close = "Liveness FaceDistanceChanged(sessionId=session-1, distance=0.25, "
            + "faceDistanceThreshold=0.1, exceedsThreshold=true, phase=PRE_CHECK)"
        let rows: [(state: LivenessStateMachine.State, face: DetectedFace, expected: LivenessStateMachine.State, line: String)] = [
            (.pendingFacePreparedConfirmation(.pendingCheck), Self.farFace, .recording(ovalDisplayed: false), far),
            (.pendingFacePreparedConfirmation(.pendingCheck), Self.matchedFace, .pendingFacePreparedConfirmation(.faceTooClose), close),
            (.recording(ovalDisplayed: true), Self.farFace, .awaitingFaceInOvalMatch(.moveFaceCloser, 0.25), far),
            (.faceMatched, Self.matchedFace, .faceMatched, close),
            (.displayingFreshness, Self.matchedFace, .displayingFreshness, close)
        ]
        for row in rows {
            resetFixture()
            let label = "\(row.state) with eyes \(row.face.faceDistance) apart"
            let viewModel = makeViewModel()
            prepare(viewModel, in: row.state)

            viewModel.process(newResult: .singleFace(row.face))
            drainMainQueue()

            XCTAssertEqual(viewModel.livenessState.state, row.expected, label)
            XCTAssertEqual(logger.messages, [row.line], label)
        }
    }

    // MARK: - Challenge progress

    /// Given: A movement check whose camera is laid out and configured
    /// When: Faces arrive while the oval is drawn, before and after the initial face is sent, then match and hold for a second
    /// Then: The oval is measured only once the initial face is sent, and the match and completion are logged in the oval fit phase
    func testMovementCheckMeasuresTheOvalOnlyOnceTheInitialFaceIsSent() {
        let viewModel = makeViewModel()
        let service = MockLivenessService()
        let initialFacesSent = EventLog<Int>()
        service.onInitialClientEvent = { _, _ in initialFacesSent.append(0) }
        viewModel.livenessService = service
        layOut(viewModel)
        clock.now = 2_000
        XCTAssertNil(viewModel.configureCamera(withinFrame: previewRect))
        drainMainQueue()
        viewModel.process(newResult: .singleFace(Self.farFace))
        drainMainQueue()
        XCTAssertEqual(viewModel.livenessState.state, .recording(ovalDisplayed: false))

        // the first draws the oval; all four arrive before the main queue sends the initial face
        clock.now = 3_250
        for _ in 0..<4 {
            viewModel.process(newResult: .singleFace(Self.farFace))
        }
        XCTAssertFalse(viewModel.ovalRect.isEmpty)
        XCTAssertTrue(logger.lines(named: "OvalPositionChanged").isEmpty, "not measured until the initial face is sent")
        drainMainQueue()
        for face in [Self.farFace, Self.farFace, Self.farFace, Self.matchedFace] {
            viewModel.process(newResult: .singleFace(face))
        }
        drainMainQueue()

        XCTAssertEqual(initialFacesSent.events.count, 1)
        XCTAssertEqual(viewModel.livenessState.state, .faceMatched)
        XCTAssertEqual(presenter.completeNoLightCheckCount, 1)
        XCTAssertEqual(
            logger.lines(named: "InitialFaceDetected"),
            ["Liveness InitialFaceDetected(sessionId=session-1, elapsedSinceFirstFrameMs=0, "
                + "elapsedSinceCheckStartMs=1250)"]
        )
        XCTAssertEqual(
            logger.lines(named: "OvalPositionChanged"),
            ["Liveness OvalPositionChanged(sessionId=session-1, from=null, to=TOO_FAR, phase=OVAL_FIT)"]
        )
        XCTAssertEqual(
            logger.lines(named: "FirstOvalMatch"),
            ["Liveness FirstOvalMatch(sessionId=session-1, framesAnalyzed=0, phase=OVAL_FIT)"]
        )

        viewModel.completeNoLightCheck()
        drainMainQueue()
        XCTAssertTrue(logger.lines(named: "ChallengeCompleted").isEmpty, "not until the matched face has been held for a second")
        drainMainQueue(after: 1.1)
        XCTAssertEqual(viewModel.livenessState.state, .completedNoLightCheck)
        XCTAssertEqual(
            logger.lines(named: "ChallengeCompleted"),
            ["Liveness ChallengeCompleted(sessionId=session-1, framesAnalyzed=0, phase=OVAL_FIT)"]
        )
    }

    /// Given: A light challenge check showing its colors after its face matched the oval during the oval fit
    /// When: Three colors are displayed, faces in and then out of the oval arrive, and the colors finish
    /// Then: Leaving the oval is logged in the color phase against the earlier match, the colors carry on, then ChallengeCompleted
    func testLightCheckMeasuresTheOvalWithoutRestartingTheColors() {
        let viewModel = makeViewModel(kind: .faceMovementAndLight)
        let service = MockLivenessService()
        let colorsSent = EventLog<Int>()
        service.onFreshnessEvent = { _, _ in colorsSent.append(0) }
        viewModel.livenessService = service
        prepare(viewModel, in: .displayingFreshness)
        viewModel.diagnostics.onInitialFaceDetectedSent()
        for _ in 0..<3 {
            viewModel.diagnostics.onOvalMeasurement(OvalMeasurement(position: .matched, iou: 0.9))
        }
        XCTAssertEqual(
            logger.lines(named: "FirstOvalMatch"),
            ["Liveness FirstOvalMatch(sessionId=session-1, framesAnalyzed=0, phase=OVAL_FIT)"]
        )
        logger.clear()

        for sequenceNumber in 0..<3 {
            viewModel.sendColorDisplayedEvent(colorEvent(sequenceNumber))
        }
        for face in [Self.matchedFace, Self.matchedFace, Self.matchedFace, Self.farFace, Self.farFace, Self.farFace] {
            viewModel.process(newResult: .singleFace(face))
        }
        drainMainQueue()

        XCTAssertEqual(colorsSent.events.count, 3)
        XCTAssertEqual(viewModel.livenessState.state, .displayingFreshness, "faces don't restart the colors")
        XCTAssertEqual(
            logger.lines(named: "ColorSequenceStarted"),
            ["Liveness ColorSequenceStarted(sessionId=session-1)"]
        )
        XCTAssertEqual(logger.lines(named: "FirstOvalMatch"), [])
        XCTAssertEqual(
            logger.lines(named: "OvalPositionChanged"),
            ["Liveness OvalPositionChanged(sessionId=session-1, from=MATCHED, to=TOO_FAR, phase=COLOR_SEQUENCE)"]
        )

        viewModel.handleFreshnessComplete()
        drainMainQueue()

        XCTAssertEqual(viewModel.livenessState.state, .completedDisplayingFreshness)
        XCTAssertEqual(
            logger.lines(named: "ChallengeCompleted"),
            ["Liveness ChallengeCompleted(sessionId=session-1, framesAnalyzed=0, phase=COLOR_SEQUENCE)"]
        )
    }

    // MARK: - Watchdog and teardown

    /// Given: A check with its session configuration, on the mock detector
    /// When: It configures its camera and the watchdog's 10 s pass, then its configuration and state change
    /// Then: The watchdog the camera armed reports the view model's gates, which follow its configuration and state
    func testConfigureCameraArmsTheWatchdogThatReportsTheViewModelsGates() {
        let viewModel = makeViewModel()
        layOut(viewModel)
        XCTAssertNil(viewModel.configureCamera(withinFrame: previewRect))
        drainMainQueue()
        XCTAssertEqual(scheduler.items.count, 1, "configuring the camera arms the watchdog")

        clock.now += 10_000
        scheduler.runPending()

        XCTAssertEqual(logger.lines(named: "FaceDetectionWatchdog"), [
            "Liveness FaceDetectionWatchdog(sessionId=session-1, elapsedMs=10000, framesAnalyzed=0, "
                + "maxDetectionScore=0.0, faceDetectionThreshold=0.7, analyzeErrors=0, readyForOval=true, "
                + "faceTargetChallenge=absent, initialFaceDistanceCheckPassed=false, "
                + "checkState=pendingFacePreparedConfirmation.pendingCheck, framesDelivered=0, "
                + "captureRunning=false)"
        ])
        viewModel.sessionConfiguration = nil
        viewModel.livenessState = .init(state: .recording(ovalDisplayed: true))
        let gates = viewModel.diagnosticsGateSnapshot()
        XCTAssertFalse(gates.readyForOval, "without a session configuration")
        XCTAssertTrue(gates.initialFaceDistanceCheckPassed, "once recording")
        XCTAssertEqual(gates.checkState, "recording.ovalDisplayed")
    }

    /// Given: A view model on the real detector, which doesn't keep it alive
    /// When: It's released without an outcome or the detector view's teardown
    /// Then: SessionEnded reports the session as disposed
    func testReleasingTheViewModelEndsTheSession() throws {
        weak var released: FaceLivenessDetectionViewModel?
        try autoreleasepool {
            let viewModel = makeUnconfiguredViewModel(faceDetector: try FaceDetectorShortRange.Model())
            released = viewModel
        }

        XCTAssertNil(released, "nothing else holds the view model")
        XCTAssertEqual(logger.messages, [sessionEndedLine(closeCode: "DISPOSED")])
    }

    // MARK: - Fixtures

    /// Eyes 0.0625 apart, within the fixture's 0.1 distance threshold; on the preview its landmarks
    /// sit small in the middle of the oval, so it's too far.
    private static let farFace = DetectedFace(
        boundingBox: CGRect(x: 0.4375, y: 0.40625, width: 0.125, height: 0.125),
        leftEye: CGPoint(x: 0.53125, y: 0.4375), rightEye: CGPoint(x: 0.46875, y: 0.4375),
        nose: CGPoint(x: 0.5, y: 0.46875), mouth: CGPoint(x: 0.5, y: 0.5),
        rightEar: CGPoint(x: 0.4375, y: 0.4375), leftEar: CGPoint(x: 0.5625, y: 0.4375),
        confidence: 0.9
    )

    /// Eyes 0.25 apart, too close for the pre-check; on the preview its landmarks span the oval.
    private static let matchedFace = DetectedFace(
        boundingBox: CGRect(x: 0.225, y: 0.3125, width: 0.55, height: 0.521875),
        leftEye: CGPoint(x: 0.625, y: 0.390625), rightEye: CGPoint(x: 0.375, y: 0.390625),
        nose: CGPoint(x: 0.5, y: 0.515625), mouth: CGPoint(x: 0.5, y: 0.640625),
        rightEar: CGPoint(x: 0.25, y: 0.46875), leftEar: CGPoint(x: 0.75, y: 0.46875),
        confidence: 0.95
    )

    private func resetFixture() {
        logger = MockLogger()
        clock = TestClock()
        scheduler = ManualScheduler()
        diagnostics = LivenessDiagnosticsFixture.makeDiagnostics(logger: logger, clock: clock, scheduler: scheduler)
        presenter = MockLivenessViewControllerPresenter()
    }

    /// A view model of `kind` reporting to `diagnostics`, whose oval fit can't time out during a test.
    private func makeViewModel(kind: LivenessGeometryFixture.ChallengeKind = .faceMovement) -> FaceLivenessDetectionViewModel {
        LivenessGeometryFixture.makeViewModel(presenter: presenter, kind: kind, ovalFitTimeout: 30_000, diagnostics: diagnostics)
    }

    /// A view model reporting to `diagnostics`, before any challenge or session configuration.
    private func makeUnconfiguredViewModel(
        faceDetector: FaceDetector = MockFaceDetector(),
        isPreviewScreenEnabled: Bool = false
    ) -> FaceLivenessDetectionViewModel {
        FaceLivenessDetectionViewModel(
            faceDetector: faceDetector,
            faceInOvalMatching: .init(),
            videoChunker: VideoChunker(
                assetWriter: LivenessAVAssetWriter(),
                assetWriterDelegate: .init(),
                assetWriterInput: LivenessAVAssetWriterInput()
            ),
            closeButtonAction: {},
            sessionID: LivenessDiagnosticsFixture.sessionID,
            isPreviewScreenEnabled: isPreviewScreenEnabled,
            challengeOptions: .init(),
            diagnostics: diagnostics
        )
    }

    /// The view model as the face detector holds it.
    private func resultHandler(of viewModel: FaceLivenessDetectionViewModel) throws -> FaceDetectionResultHandler {
        try XCTUnwrap(viewModel.faceDetector as? MockFaceDetector).detectionResultHandler
    }

    /// Lays out the preview and normalizes faces onto it as the view controller does, and hands
    /// diagnostics the session configuration as the service's listener does.
    private func layOut(_ viewModel: FaceLivenessDetectionViewModel) {
        viewModel.cameraViewRect = previewRect
        let size = previewRect.size
        viewModel.normalizeFace = { $0.normalize(width: size.width, height: size.height) }
        if let configuration = viewModel.sessionConfiguration {
            viewModel.diagnostics.onSessionReady(configuration, challengeID: viewModel.challengeID)
        }
    }

    /// Lays out `viewModel` and puts its check in `state`, past the pre-check with the oval drawn
    /// but no initial face sent, then clears the log.
    private func prepare(_ viewModel: FaceLivenessDetectionViewModel, in state: LivenessStateMachine.State) {
        layOut(viewModel)
        switch state {
        case .pendingFacePreparedConfirmation:
            break
        default:
            viewModel.livenessState.beginRecording()
            drawOvalAndWaitUntilDisplayed(viewModel)
        }
        viewModel.livenessState = .init(state: state)
        logger.clear()
    }

    private func colorEvent(_ sequenceNumber: Int) -> Freshness.ColorEvent {
        let black = FaceLivenessSession.DisplayColor(
            rgb: .init(red: 0, green: 0, blue: 0, _values: [0, 0, 0]),
            duration: 75,
            shouldScroll: false
        )
        return .init(currentColor: black, previousColor: black, sequenceNumber: sequenceNumber, colorStartTime: 1_000)
    }

    /// Runs the main queue's work, such as the view model's state hops, and any due within `delay`.
    private func drainMainQueue(after delay: TimeInterval = 0) {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { drained.fulfill() }
        wait(for: [drained], timeout: delay + 5)
    }
}

/// A liveness service whose stream can't be opened.
private final class StreamRefusingLivenessService: LivenessService, @unchecked Sendable {
    var onServiceException: (FaceLivenessSessionError) -> Void = { _ in }

    func initializeLivenessStream(
        withSessionID sessionID: String,
        userAgent: String,
        challenges: [Challenge],
        options: FaceLivenessSession.Options
    ) throws {
        throw NSError(domain: "TestStream", code: 7, userInfo: [NSLocalizedDescriptionKey: "stream refused"])
    }

    func send<T>(_ event: LivenessEvent<T>, eventDate: () -> Date) {}
    func register(onComplete: @escaping (ServerDisconnection) -> Void) {}
    func register(listener: @escaping (FaceLivenessSession.SessionConfiguration) -> Void, on event: LivenessEventKind.Server) {}
    func register(listener: @escaping (Challenge) -> Void, on event: LivenessEventKind.Server) {}
    func closeSocket(with code: URLSessionWebSocketTask.CloseCode) {}
}
