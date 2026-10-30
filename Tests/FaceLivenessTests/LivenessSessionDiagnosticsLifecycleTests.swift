//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import CoreVideo
import Amplify
@testable import FaceLiveness
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

/// The face detection watchdog, the overlap statistics, how errors and outcomes are reported, and
/// what happens once a session has ended, with a recording logger, a clock and a manual scheduler.
final class LivenessSessionDiagnosticsLifecycleTests: XCTestCase {
    private var logger: MockLogger!
    private var clock: TestClock!
    private var scheduler: ManualScheduler!
    private var diagnostics: LivenessSessionDiagnostics!

    override func setUp() {
        startSession()
    }

    override func tearDown() {
        diagnostics = nil
        scheduler = nil
        clock = nil
        logger = nil
    }

    // MARK: - Watchdog

    /// Given: A new session
    /// When: Unanalyzed frames arrive, then check start and frames without a face, in either order
    /// Then: Only check start or an analyzed frame without a face arms the watchdog, once, for 10 s
    func testTheWatchdogIsArmedOnceByCheckStartOrAFrameWithoutAFace() {
        diagnostics.onFrameReport(FaceDetectionFrameReport(faceCount: 1, topScore: 0.95, usedSessionThreshold: false))
        diagnostics.onFrameReport(FaceDetectionFrameReport(failure: FrameAnalysisFailure(stage: .prediction, cause: nil)))
        XCTAssertEqual(scheduler.items.count, 0, "a frame that wasn't analyzed armed the watchdog")
        analyzeFrameWithoutFace()
        diagnostics.onCheckStarted()
        analyzeFrameWithoutFace()
        XCTAssertEqual(scheduler.items.map(\.delay), [10], "armed by a frame")

        startSession()
        diagnostics.onCheckStarted()
        diagnostics.onCheckStarted()
        analyzeFrameWithoutFace()
        XCTAssertEqual(scheduler.items.map(\.delay), [10], "armed by check start")
        XCTAssertEqual(logger.entries, [])
    }

    /// Given: A session that already found a face, and one that already failed
    /// When: The check takes over the camera
    /// Then: Neither arms the watchdog, since it could no longer fire
    func testCheckStartDoesNotArmTheWatchdogAfterAFaceOrAnError() {
        let rows: [(name: String, before: Hook)] = [
            ("a face", { $0.onFrameAnalyzed(faceCount: 1, topScore: 0.9) }),
            ("an error", { $0.onCheckStateChanged(.encounteredUnrecoverableError(.userCancelled)) })
        ]
        for row in rows {
            startSession()
            row.before(diagnostics)
            diagnostics.onCheckStarted()
            XCTAssertEqual(scheduler.items.count, 0, row.name)
        }
    }

    /// Given: A watchdog armed by a frame without a face
    /// When: Something stops it, then its cancelled timer runs anyway, as one in flight would, and it's fired directly
    /// Then: The timer was cancelled and no watchdog line is logged
    func testAnInFlightWatchdogStaysSilentOnceStopped() {
        for (name, stop) in watchdogStoppers {
            startSession()
            analyzeFrameWithoutFace()

            stop(diagnostics)
            scheduler.runAll()
            diagnostics.emitWatchdogSnapshot()

            XCTAssertEqual(scheduler.items.map(\.cancelled), [true], name)
            XCTAssertEqual(logger.lines(named: "FaceDetectionWatchdog"), [], name)
        }
    }

    /// Given: A gate provider that stops the watchdog while it's being read
    /// When: The watchdog fires
    /// Then: No watchdog line is logged, since its conditions are checked again after the read
    func testTheWatchdogRechecksItsConditionsAfterReadingTheGates() {
        for (name, stop) in watchdogStoppers {
            startSession()
            let session = diagnostics!
            session.registerGateProvider { [weak session] in
                if let session { stop(session) }
                return nil
            }
            session.onCheckStarted()
            scheduler.runPending()
            XCTAssertEqual(logger.lines(named: "FaceDetectionWatchdog"), [], name)
        }
    }

    /// Given: A watchdog that has fired
    /// When: It's fired again, its timer runs again, and the check restarts with another frame without a face
    /// Then: One watchdog line is logged in all
    func testTheWatchdogFiresAtMostOnce() {
        analyzeFrameWithoutFace()
        scheduler.runPending()

        diagnostics.emitWatchdogSnapshot()
        scheduler.runAll()
        diagnostics.onCheckStarted()
        analyzeFrameWithoutFace()
        scheduler.runAll()

        XCTAssertEqual(logger.lines(named: "FaceDetectionWatchdog").count, 1)
    }

    /// Given: A session ready with a 0.85 threshold, whose check started at 2.5 s, with a gate provider
    /// When: Frames arrive, unanalyzed and analyzed without a face, and the timer fires at 12.345 s
    /// Then: The line has the time since it was armed, the analyzed frames and best score, the errors and the gates
    func testTheWatchdogReportsWhatTheCheckSaw() {
        let configuration = LivenessDiagnosticsFixture.movementConfiguration(faceDetectionThreshold: 0.85)
        diagnostics.onSessionReady(configuration, challengeID: "challenge-1")
        diagnostics.registerGateProvider {
            GateSnapshot(readyForOval: true, faceTargetChallengePresent: true, initialFaceDistanceCheckPassed: true,
                         checkState: "recording.ovalDisplayed", captureRunning: true)
        }
        clock.now = 2_500
        diagnostics.onCheckStarted()
        clock.now = 4_000
        for _ in 0..<5 {
            diagnostics.onCheckFrameDelivered()
        }
        diagnostics.onFrameReport(FaceDetectionFrameReport(faceCount: 1, topScore: 0.95, usedSessionThreshold: false))
        diagnostics.onFrameReport(FaceDetectionFrameReport(failure: FrameAnalysisFailure(stage: .prediction, cause: nil)))
        for topScore: Float in [0.05, 0.68, 0.11] {
            analyzeFrameWithoutFace(topScore: topScore)
        }
        clock.now = 12_345
        scheduler.runPending()

        XCTAssertEqual(logger.lines(named: "FaceDetectionWatchdog"), [
            "Liveness FaceDetectionWatchdog(sessionId=session-1, elapsedMs=9845, framesAnalyzed=3, maxDetectionScore=0.68, "
                + "faceDetectionThreshold=0.85, analyzeErrors=1, readyForOval=true, faceTargetChallenge=present, "
                + "initialFaceDistanceCheckPassed=true, checkState=recording.ovalDisplayed, framesDelivered=5, captureRunning=true)"
        ])
    }

    /// Given: No gate provider, or one with no snapshot, as once the view model is gone
    /// When: The check starts, no frame arrives, and the timer fires 10 s later
    /// Then: The silent camera is reported at warn, with every gate unknown
    func testTheWatchdogReportsASilentCameraWithUnknownGates() {
        for registersProvider in [false, true] {
            startSession()
            if registersProvider {
                diagnostics.registerGateProvider { nil }
            }
            diagnostics.onCheckStarted()
            clock.now += 10_000
            scheduler.runPending()

            XCTAssertEqual(logger.entries, [MockLogger.Entry(
                level: .warn,
                message: "Liveness FaceDetectionWatchdog(sessionId=session-1, elapsedMs=10000, framesAnalyzed=0, "
                    + "maxDetectionScore=0.0, faceDetectionThreshold=0.0, analyzeErrors=0, readyForOval=false, "
                    + "faceTargetChallenge=unknown, initialFaceDistanceCheckPassed=false, checkState=unknown, "
                    + "framesDelivered=0, captureRunning=false)"
            )], registersProvider ? "a provider with no snapshot" : "no provider")
        }
    }

    /// Given: The scheduler the watchdog uses outside tests
    /// When: Work is scheduled with no delay, and other work is scheduled and then cancelled
    /// Then: The first runs later on main, not during the call, and the cancelled work never runs
    func testTheMainQueueSchedulerRunsWorkLaterOnMainUnlessCancelled() {
        let ran = expectation(description: "scheduled work ran")
        let cancelledRan = expectation(description: "cancelled work ran")
        cancelledRan.isInverted = true
        let ranOnMain = EventLog<Bool>()

        _ = LivenessSessionDiagnostics.mainQueueScheduler(0) {
            ranOnMain.append(Thread.isMainThread)
            ran.fulfill()
        }
        XCTAssertEqual(ranOnMain.events, [], "the work ran during the call")
        let cancel = LivenessSessionDiagnostics.mainQueueScheduler(0.05) {
            cancelledRan.fulfill()
        }
        cancel()

        wait(for: [ran, cancelledRan], timeout: 0.5)
        XCTAssertEqual(ranOnMain.events, [true])
    }

    // MARK: - Overlap

    /// Given: A face measured against the oval during the check, before and after its first match
    /// When: The detector is removed
    /// Then: The window and overlap count from the first match, sampling only the finite overlaps of faces
    func testTheOverlapIsMeasuredFromTheFirstMatch() throws {
        // challengeFrames, challengeFramesWithFace, challengeMinIou and challengeMeanIou
        let rows: [(name: String, frames: [Frame], overlap: String)] = [
            ("matched throughout", [.face(.matched, 0.8), .face(.matched, 0.4), .face(.matched, 0.6)], "3 3 0.4 0.6"),
            ("matched on the third frame", [.face(.tooFar, 0.05), .face(.tooFar, 0.1), .face(.matched, 0.7)], "1 1 0.7 0.7"),
            ("moving after the match", [.face(.matched, 0.9), .face(.tooClose, 0.3), .face(.tooFar, 0.6)], "3 3 0.3 0.6"),
            ("lost after a late match", [.face(.tooFar, 0.2), .face(.matched, 0.7), .face(.matched, 0.6), .noFace], "3 2 0.6 0.65"),
            ("gone for 20 frames", [.face(.matched, 0.7)] + Array(repeating: Frame.noFace, count: 20), "21 1 0.7 0.7"),
            ("non-finite overlaps", [.face(.matched, 0.7), .face(.matched, .nan), .face(.matched, .infinity),
                                     .face(.matched, -.infinity)], "4 1 0.7 0.7"),
            ("never matched", Array(repeating: Frame.face(.tooFar, 0.2), count: 10), "0 0 0.0 0.0")
        ]

        for row in rows {
            startSession()
            diagnostics.onInitialFaceDetectedSent()
            for frame in row.frames {
                switch frame {
                case let .face(position, iou): analyzeFace(position, iou: iou)
                case .noFace: analyzeFrameWithoutFace()
                }
            }
            diagnostics.onTeardown()

            let summary = fields(of: try XCTUnwrap(logger.lines(named: "SessionEnded").first, row.name))
            let keys = ["challengeFrames", "challengeFramesWithFace", "challengeMinIou", "challengeMeanIou"]
            XCTAssertEqual(keys.map { summary[$0] ?? "-" }.joined(separator: " "), row.overlap, row.name)
        }
    }

    /// Given: A face that has matched the oval and held it long enough to be logged
    /// When: 100 more frames measure it there
    /// Then: None of them logs a line, though each is sampled
    func testAHeldMatchLogsNothingPerFrame() throws {
        let debounce = LivenessSessionDiagnostics.ovalPositionDebounceFrames
        diagnostics.onInitialFaceDetectedSent()
        for _ in 0..<debounce {
            analyzeFace(.matched, iou: 0.5)
        }
        let linesWhenHeld = logger.messages

        for _ in 0..<100 {
            analyzeFace(.matched, iou: 0.5)
        }

        XCTAssertEqual(logger.messages, linesWhenHeld)
        diagnostics.onTeardown()
        XCTAssertEqual(fields(of: try XCTUnwrap(logger.messages.last))["challengeFramesWithFace"], String(debounce + 100))
    }

    // MARK: - Freezing

    /// Given: A matched session closed by ChallengeCompleted, a check error or a service exception
    /// When: Every per-frame hook is called again
    /// Then: Nothing more is logged, and SessionEnded reports the session as it was when it closed
    func testPerFrameAccountingFreezesWhenTheChallengeEndsOrFails() {
        let closers: [(name: String, close: Hook, closeCode: String)] = [
            ("ChallengeCompleted", { $0.onChallengeCompleted() }, "DISPOSED"),
            ("a check error", { $0.onCheckStateChanged(.encounteredUnrecoverableError(.timedOut)) }, "TIMEOUT"),
            ("a service exception", { $0.onServiceException(.serviceUnavailable) }, "RUNTIME_ERROR")
        ]
        for (name, close, closeCode) in closers {
            startSession()
            diagnostics.onInitialFaceDetectedSent()
            analyzeFace(.matched, iou: 0.8)
            analyzeFace(.matched, iou: 0.6)
            diagnostics.onFrameDropped()
            close(diagnostics)
            let linesAtClose = logger.messages

            diagnostics.onFrameDropped()
            diagnostics.onFrameReport(FaceDetectionFrameReport(faceCount: 0, topScore: 0.99, usedSessionThreshold: false))
            diagnostics.onFrameReport(FaceDetectionFrameReport(failure: FrameAnalysisFailure(stage: .prediction, cause: nil)))
            diagnostics.onFrameReport(FaceDetectionFrameReport(faceCount: 2, topScore: 0.97, usedSessionThreshold: true))
            diagnostics.onFaceDistance(0.9)
            for _ in 0..<3 {
                diagnostics.onOvalMeasurement(OvalMeasurement(position: .tooFar, iou: 0.05))
            }

            XCTAssertEqual(logger.messages, linesAtClose, name)
            diagnostics.onTeardown()
            let ended = "Liveness SessionEnded(sessionId=session-1, framesAnalyzed=2, faceEverDetected=true, "
                + "ovalEverMatched=true, ovalPositionChanges=0, challengeFrames=2, challengeFramesWithFace=2, challengeMinIou=0.6, "
                + "challengeMeanIou=0.7, analyzeErrors=0, closeCode=\(closeCode), framesDropped=1)"
            XCTAssertEqual(logger.messages.last, ended, name)
        }
    }

    // MARK: - Outcomes

    /// Given: Sessions with no outcome, a completion, or errors in either order on either channel
    /// When: The detector is removed
    /// Then: SessionEnded has the first error's close code, else NORMAL or DISPOSED; completion logs nothing itself
    func testSessionEndedReportsTheFirstErrorElseCompletionElseDisposal() {
        let complete: Hook = { $0.onCheckStateChanged(.completed) }
        let cancel: Hook = { $0.onCheckStateChanged(.encounteredUnrecoverableError(.userCancelled)) }
        let timeOut: Hook = { $0.onCheckStateChanged(.encounteredUnrecoverableError(.timedOut)) }
        let loseStream: Hook = { $0.onCheckStateChanged(.encounteredUnrecoverableError(.couldNotOpenStream)) }
        let failService: Hook = { $0.onServiceException(.internalServer) }
        let rows: [(name: String, steps: [Hook], closeCode: String)] = [
            ("no outcome", [], "DISPOSED"),
            ("a completion", [complete], "NORMAL"),
            ("a cancellation", [cancel], "CANCELED"),
            ("a timeout, then a completion", [timeOut, complete], "TIMEOUT"),
            ("a timeout, then a runtime error", [timeOut, loseStream], "TIMEOUT"),
            ("a cancellation, then a service exception", [cancel, failService], "CANCELED"),
            ("a service exception, then a cancellation", [failService, cancel], "RUNTIME_ERROR")
        ]

        for row in rows {
            startSession()
            row.steps.forEach { $0(diagnostics) }
            diagnostics.onTeardown()

            let lines = logger.messages.filter { !$0.hasPrefix("Liveness SessionError(") }
            XCTAssertEqual(lines, [sessionEndedLine(closeCode: row.closeCode)], row.name)
        }
    }

    /// Given: A watchdog armed at check start
    /// When: The check passes through every state but completion and an error, and the detector is removed
    /// Then: None logs a line or stops the watchdog, and the session ends disposed
    func testOtherCheckStatesLogNothing() {
        diagnostics.onCheckStarted()
        let states: [LivenessStateMachine.State] = [
            .initial, .awaitingChallengeType, .pendingFacePreparedConfirmation(.pendingCheck), .waitForRecording,
            .recording(ovalDisplayed: true), .awaitingFaceInOvalMatch(.moveFaceCloser, 0.4), .faceMatched,
            .initialClientInfoEventSent, .displayingFreshness, .completedDisplayingFreshness, .completedNoLightCheck,
            .awaitingDisconnectEvent, .disconnectEventReceived
        ]

        for state in states {
            diagnostics.onCheckStateChanged(state)
        }

        XCTAssertEqual(scheduler.items.map(\.cancelled), [false])
        diagnostics.onTeardown()
        XCTAssertEqual(logger.messages, [sessionEndedLine()])
    }

    // MARK: - Session errors

    /// Given: A check in progress
    /// When: It times out, and the service then reports that the session wasn't found
    /// Then: Each logs a SessionError at warn with the host's error, no cause, its close code and what failed
    func testEachErrorLogsTheHostsErrorItsCloseCodeAndWhatFailed() {
        diagnostics.onCheckStateChanged(.encounteredUnrecoverableError(.timedOut))
        diagnostics.onServiceException(.sessionNotFound)

        XCTAssertEqual(logger.entries, [
            MockLogger.Entry(level: .warn, message: "Liveness SessionError(sessionId=session-1, "
                + "type=faceInOvalMatchExceededTimeLimitError, message=Face did not match oval within time limit., "
                + "cause=null, closeCode=TIMEOUT, reason=timedOut)"),
            MockLogger.Entry(level: .warn, message: "Liveness SessionError(sessionId=session-1, type=sessionNotFound, "
                + "message=Session not found., cause=null, closeCode=RUNTIME_ERROR, reason=service.sessionNotFound)")
        ])
    }

    /// Given: A check in progress
    /// When: A check error, which every later state change republishes, and a service exception each repeat
    /// Then: Each distinct error logs one SessionError, in order
    func testEachDistinctErrorLogsOneSessionError() {
        diagnostics.onCheckStateChanged(.encounteredUnrecoverableError(.timedOut))
        diagnostics.onCheckStateChanged(.encounteredUnrecoverableError(.timedOut))
        diagnostics.onServiceException(.throttling)
        diagnostics.onServiceException(.throttling)
        diagnostics.onCheckStateChanged(.encounteredUnrecoverableError(.couldNotOpenStream))
        diagnostics.onServiceException(.internalServer)

        XCTAssertEqual(
            logger.lines(named: "SessionError").map { fields(of: $0)["reason"] },
            ["timedOut", "service.throttling", "couldNotOpenStream", "service.internalServer"]
        )
    }

    /// Given: Causes noted for the unknown error: none, then an error, then a string
    /// When: The check is cancelled, then ends with the unknown error
    /// Then: Noting logs nothing, and only the unknown error has a cause: the first real one, described
    func testANotedCauseIsTheFirstForItsErrorDescribed() {
        diagnostics.noteCause(nil as String?, for: .unknown)
        diagnostics.noteCause(NSError(domain: "AVFoundationErrorDomain", code: -11852, userInfo: [
            NSLocalizedDescriptionKey: "Cannot Use Camera"
        ]), for: .unknown)
        diagnostics.noteCause("WebSocketCloseCode: 1006", for: .unknown)
        XCTAssertEqual(logger.entries, [])

        diagnostics.onCheckStateChanged(.encounteredUnrecoverableError(.userCancelled))
        diagnostics.onCheckStateChanged(.encounteredUnrecoverableError(.unknown))

        XCTAssertEqual(logger.messages, [
            "Liveness SessionError(sessionId=session-1, type=userCancelled, message=User cancelled the face liveness check., "
                + "cause=null, closeCode=CANCELED, reason=userCancelled)",
            "Liveness SessionError(sessionId=session-1, type=cameraPermissionDenied, "
                + "message=Camera permissions have not been granted., cause=AVFoundationErrorDomain(-11852): Cannot Use Camera, "
                + "closeCode=RUNTIME_ERROR, reason=unknown)"
        ])
    }

    // MARK: - Service exception wrapper

    /// Given: The service's exception handler wrapped twice, as registering the service's events twice does
    /// When: The service reports an exception
    /// Then: The host hears of it once, with the same error, after its one SessionError was logged
    func testTheWrapperLogsOnceBeforeTheHostHearsOfIt() {
        let logger = self.logger!
        let heard = EventLog<(error: FaceLivenessSessionError, logged: [String])>()
        let forward = diagnostics.recordingServiceExceptions(
            forwardingTo: diagnostics.recordingServiceExceptions { heard.append(($0, logger.lines(named: "SessionError"))) }
        )

        forward(.throttling)

        XCTAssertEqual(heard.events.map { $0.error }, [.throttling])
        XCTAssertEqual(heard.events.map { $0.logged }, [[
            "Liveness SessionError(sessionId=session-1, type=throttling, message=A request was denied due to request throttling., "
                + "cause=null, closeCode=RUNTIME_ERROR, reason=service.throttling)"
        ]])
    }

    /// Given: The service's exception handler wrapped by diagnostics that have since been released
    /// When: The service reports an exception
    /// Then: The wrapper didn't keep the diagnostics alive, and the host still hears of it, once
    func testTheWrapperStillForwardsOnceTheDiagnosticsAreGone() {
        let received = EventLog<FaceLivenessSessionError>()
        let forward = diagnostics.recordingServiceExceptions { received.append($0) }
        weak var released: LivenessSessionDiagnostics?
        released = diagnostics
        diagnostics = nil
        XCTAssertNil(released, "the wrapper kept the diagnostics alive")

        forward(.accessDenied)

        XCTAssertEqual(received.events, [.accessDenied])
        XCTAssertEqual(logger.entries, [])
    }

    // MARK: - After teardown

    /// Given: A session past its initial face whose detector has been removed
    /// When: Every hook that would log or arm the watchdog is called again, including another removal
    /// Then: Nothing more is logged or scheduled, and the host still hears of service exceptions
    func testNothingIsRecordedAfterTeardown() throws {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 480, 640, kCVPixelFormatType_32BGRA, nil, &buffer)
        let received = EventLog<FaceLivenessSessionError>()
        let forward = diagnostics.recordingServiceExceptions { received.append($0) }
        diagnostics.onInitialFaceDetectedSent()
        diagnostics.onTeardown()
        let linesAtTeardown = logger.messages

        diagnostics.onSessionStartRequested(attempt: 2, codec: "H264", preCheckEnabled: true)
        diagnostics.onSessionReady(LivenessDiagnosticsFixture.movementAndLightConfiguration(), challengeID: "challenge-1")
        diagnostics.onCameraBound(facing: "front")
        diagnostics.onCameraPermissionDenied(status: "denied")
        diagnostics.onCheckStarted()
        diagnostics.onCameraFrame(try XCTUnwrap(buffer))
        diagnostics.onFrameReport(FaceDetectionFrameReport(faceCount: 0, topScore: 0.2, usedSessionThreshold: true))
        diagnostics.onFrameReport(FaceDetectionFrameReport(faceCount: 1, topScore: 0.9, usedSessionThreshold: true))
        diagnostics.onFrameReport(FaceDetectionFrameReport(faceCount: 1, topScore: 0.9, usedSessionThreshold: false))
        diagnostics.onFrameReport(FaceDetectionFrameReport(failure: FrameAnalysisFailure(stage: .prediction, cause: nil)))
        diagnostics.onFaceDistance(0.4)
        diagnostics.onOvalMeasurement(OvalMeasurement(position: .matched, iou: 0.7))
        diagnostics.onColorDisplayed()
        diagnostics.onChallengeCompleted()
        diagnostics.onCheckStateChanged(.encounteredUnrecoverableError(.socketClosed))
        forward(.validation)
        diagnostics.emitWatchdogSnapshot()
        diagnostics.onTeardown()

        XCTAssertEqual(logger.messages, linesAtTeardown)
        XCTAssertEqual(linesAtTeardown.last, sessionEndedLine())
        XCTAssertEqual(scheduler.items.count, 0, "a watchdog was armed after the session ended")
        XCTAssertEqual(received.events, [.validation])
    }

    /// Given: A session with an armed watchdog
    /// When: The detector is removed from 64 threads at once
    /// Then: One SessionEnded is logged and the watchdog is cancelled
    func testConcurrentTeardownLogsOneSessionEnded() {
        let diagnostics = self.diagnostics!
        analyzeFrameWithoutFace()

        DispatchQueue.concurrentPerform(iterations: 64) { _ in
            diagnostics.onTeardown()
        }

        XCTAssertEqual(logger.messages, [sessionEndedLine(framesAnalyzed: 1)])
        XCTAssertEqual(scheduler.items.map(\.cancelled), [true])
    }

    // MARK: - Concurrency

    /// Given: Hooks arriving at once from the capture queue, main and the service's queue
    /// When: 500 frames are analyzed, colors show, a service exception arrives half way, and the detector is removed
    /// Then: One SessionEnded is logged, last, with counts consistent with the frames analyzed before the exception
    func testHooksFromSeveralQueuesStayConsistent() throws {
        let diagnostics = self.diagnostics!
        let frameCount = 500
        let halfWay = DispatchSemaphore(value: 0)
        let framesAnalyzed = expectation(description: "frames analyzed")
        let colorsShown = expectation(description: "colors shown")
        let exceptionReported = expectation(description: "service exception reported")
        let forward = diagnostics.recordingServiceExceptions { _ in }
        diagnostics.onSessionReady(LivenessDiagnosticsFixture.movementAndLightConfiguration(), challengeID: "challenge-1")
        diagnostics.onCheckStarted()
        diagnostics.onInitialFaceDetectedSent()

        DispatchQueue(label: "test.capture").async {
            for index in 0..<frameCount {
                diagnostics.onCheckFrameDelivered()
                if index % 7 == 6 {
                    diagnostics.onFrameDropped()
                }
                if index % 5 == 4 {
                    diagnostics.onFrameAnalyzed(faceCount: 0, topScore: 0.2)
                } else {
                    diagnostics.onFrameAnalyzed(faceCount: 1, topScore: 0.9)
                    diagnostics.onFaceDistance(index % 2 == 0 ? 0.3 : 0.4)
                    let position: FaceOvalPosition = index % 3 == 0 ? .tooFar : .matched
                    diagnostics.onOvalMeasurement(OvalMeasurement(position: position, iou: index % 2 == 0 ? 0.6 : 0.8))
                }
                if index == frameCount / 2 - 1 {
                    halfWay.signal()
                }
            }
            framesAnalyzed.fulfill()
        }
        DispatchQueue.main.async {
            for _ in 0..<8 {
                diagnostics.onColorDisplayed()
            }
            colorsShown.fulfill()
        }
        DispatchQueue(label: "test.service").async {
            halfWay.wait()
            forward(.internalServer)
            exceptionReported.fulfill()
        }
        wait(for: [framesAnalyzed, colorsShown, exceptionReported], timeout: 10)
        // a timer firing after the faces were seen stays silent
        scheduler.runAll()
        diagnostics.onTeardown()

        let ended = logger.lines(named: "SessionEnded")
        XCTAssertEqual(ended.count, 1)
        XCTAssertEqual(logger.messages.last, ended.first)
        XCTAssertEqual(logger.lines(named: "SessionError").map { fields(of: $0)["reason"] }, ["service.internalServer"])
        XCTAssertEqual(logger.lines(named: "ColorSequenceStarted"), ["Liveness ColorSequenceStarted(sessionId=session-1)"])
        XCTAssertEqual(logger.lines(named: "FaceDetectionWatchdog"), [])
        XCTAssertEqual(scheduler.items.map(\.cancelled), [true])

        let summary = fields(of: try XCTUnwrap(ended.first))
        XCTAssertEqual(summary["closeCode"], "RUNTIME_ERROR")
        XCTAssertEqual(summary["challengeMinIou"], "0.6")
        let meanIou = try XCTUnwrap(summary["challengeMeanIou"].flatMap { Float($0) })
        XCTAssertTrue(meanIou > 0.6 && meanIou < 0.8, "challengeMeanIou=\(meanIou)")

        func count(_ key: String) throws -> Int { try XCTUnwrap(summary[key].flatMap { Int($0) }, key) }
        // the first half was analyzed before the exception, and nothing was counted twice
        let analyzed = try count("framesAnalyzed")
        XCTAssertTrue((frameCount / 2...frameCount).contains(analyzed), "framesAnalyzed=\(analyzed)")
        // the second frame first matched, so every analyzed frame since is in the window
        XCTAssertEqual(try count("challengeFrames"), analyzed - 1)
        // one sample per frame with a face since the match, though the exception may have cut off the last frame's
        let facesSinceMatch = (0..<analyzed).filter { $0 >= 1 && $0 % 5 != 4 }.count
        let withFace = try count("challengeFramesWithFace")
        XCTAssertTrue(
            (facesSinceMatch - 1...facesSinceMatch).contains(withFace),
            "challengeFramesWithFace=\(withFace), facesSinceMatch=\(facesSinceMatch), framesAnalyzed=\(analyzed)"
        )
        // a frame's drop is reported before it is analyzed, so at most one drop more than frames
        let dropsBeforeFreeze = (0..<analyzed).filter { $0 % 7 == 6 }.count
        let dropped = try count("framesDropped")
        XCTAssertTrue(
            (dropsBeforeFreeze...dropsBeforeFreeze + 1).contains(dropped),
            "framesDropped=\(dropped), dropsBeforeFreeze=\(dropsBeforeFreeze), framesAnalyzed=\(analyzed)"
        )
    }
}

// MARK: - Support

private typealias Hook = (LivenessSessionDiagnostics) -> Void

/// One analyzed frame: a face measured against the oval, with its overlap, or no face.
private enum Frame {
    case face(FaceOvalPosition, Double)
    case noFace
}

private extension LivenessSessionDiagnosticsLifecycleTests {
    /// Everything that stops the watchdog, besides its firing.
    var watchdogStoppers: [(name: String, stop: Hook)] {
        [
            ("a face", { $0.onFrameAnalyzed(faceCount: 1, topScore: 0.9) }),
            ("two faces", { $0.onFrameAnalyzed(faceCount: 2, topScore: 0.9) }),
            ("a check error", { $0.onCheckStateChanged(.encounteredUnrecoverableError(.timedOut)) }),
            ("a service exception", { $0.onServiceException(.internalServer) }),
            ("completion", { $0.onCheckStateChanged(.completed) }),
            ("teardown", { $0.onTeardown() })
        ]
    }

    /// Replaces the session under test with a new one, with its own logger, clock and scheduler.
    func startSession() {
        logger = MockLogger()
        clock = TestClock()
        scheduler = ManualScheduler()
        diagnostics = LivenessDiagnosticsFixture.makeDiagnostics(logger: logger, clock: clock, scheduler: scheduler)
    }

    /// A frame with one face measured against the oval, reported as the view model reports it.
    func analyzeFace(_ position: FaceOvalPosition, iou: Double) {
        diagnostics.onFrameAnalyzed(faceCount: 1, topScore: 0.9)
        diagnostics.onOvalMeasurement(OvalMeasurement(position: position, iou: iou))
    }

    func analyzeFrameWithoutFace(topScore: Float = 0.1) {
        diagnostics.onFrameAnalyzed(faceCount: 0, topScore: topScore)
    }

}
