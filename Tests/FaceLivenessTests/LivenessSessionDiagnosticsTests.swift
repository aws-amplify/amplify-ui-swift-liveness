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

/// The lines one session logs, hook by hook: how they're emitted, which are logged once, which only
/// when a tracked value changes, and the phase they carry.
final class LivenessSessionDiagnosticsTests: XCTestCase {
    private var logger: MockLogger!
    private var clock: TestClock!
    private var scheduler: ManualScheduler!
    private var diagnostics: LivenessSessionDiagnostics!

    override func setUp() {
        logger = MockLogger()
        clock = TestClock()
        scheduler = ManualScheduler()
        diagnostics = LivenessDiagnosticsFixture.makeDiagnostics(logger: logger, clock: clock, scheduler: scheduler)
    }

    override func tearDown() {
        diagnostics = nil
        scheduler = nil
        clock = nil
        logger = nil
    }

    // MARK: - Emission

    /// Given: A session logging a line at each level it uses
    /// When: The lines are logged
    /// Then: Each is "Liveness " and the event, through its level's message call, with the level never set
    func testEachLineIsLoggedThroughTheMessageCallForItsLevel() {
        diagnostics.onCameraBound(facing: "front")
        diagnostics.onCameraPermissionDenied(status: "denied")
        diagnostics.onFrameBeforeSessionReady()
        diagnostics.onAnalyzeError(FrameAnalysisFailure(stage: .prediction, cause: nil))

        XCTAssertEqual(logger.entries, [
            .init(level: .info, message: "Liveness CameraBound(sessionId=session-1, facing=front)"),
            .init(level: .warn, message: "Liveness CameraPermissionDenied(sessionId=session-1, status=denied)"),
            .init(level: .debug, message: "Liveness FrameBeforeSessionReady"),
            .init(level: .error, message: "Liveness AnalyzeFailed(sessionId=session-1, stage=prediction, cause=null)")
        ])
        XCTAssertEqual(logger.logLevelWriteCount, 0)
        XCTAssertEqual(logger.errorOverloadCallCount, 0, "error(error:) drops the message")
    }

    /// Given: A host that swaps its logger partway through a session
    /// When: A line is logged before the swap and another after it
    /// Then: Each goes to the logger installed when it was logged
    func testEachLineGoesToTheLoggerInstalledWhenItIsLogged() {
        let replacement = MockLogger()
        var installed: MockLogger = logger
        let diagnostics = LivenessSessionDiagnostics(
            sessionID: LivenessDiagnosticsFixture.sessionID,
            deviceInfo: .test,
            logger: { installed }
        )

        diagnostics.onCameraBound(facing: "front")
        installed = replacement
        diagnostics.onColorDisplayed()

        XCTAssertEqual(logger.messages, ["Liveness CameraBound(sessionId=session-1, facing=front)"])
        XCTAssertEqual(replacement.messages, ["Liveness ColorSequenceStarted(sessionId=session-1)"])
    }

    /// Given: A check whose face count, distance and oval position have settled
    /// When: Ten more such frames are delivered, analyzed and measured, one is dropped, and the face moves
    /// Then: Only the move is logged, since no line is logged per frame
    func testOnlyAFrameThatChangesSomethingLogsALine() {
        let frame = { (distance: Float) in
            self.diagnostics.onCheckFrameDelivered()
            self.diagnostics.onFrameReport(FaceDetectionFrameReport(faceCount: 1, topScore: 0.9, usedSessionThreshold: true))
            self.diagnostics.onFaceDistance(distance)
            self.diagnostics.onOvalMeasurement(OvalMeasurement(position: .matched, iou: 0.8))
        }
        diagnostics.onInitialFaceDetectedSent()
        for _ in 0..<LivenessSessionDiagnostics.debounceFrames {
            frame(0.3)
        }
        logger.clear()

        for _ in 0..<10 {
            frame(0.3)
        }
        diagnostics.onFrameDropped()
        frame(0.4)

        XCTAssertEqual(logger.messages.map(eventName(of:)), ["FaceDistanceChanged"])
    }

    // MARK: - One-shot lines

    /// Given: Hooks whose line is logged once a session
    /// When: Each is called three times, with other values after the first where it takes any
    /// Then: Each logs one line, for the first call
    func testOnceOnlyLinesAreLoggedForTheFirstCall() {
        let rows: [(name: String, call: (LivenessSessionDiagnostics, Int) -> Void, line: String)] = [
            (
                "CameraBound",
                { session, call in session.onCameraBound(facing: call == 0 ? "front" : "back") },
                "Liveness CameraBound(sessionId=session-1, facing=front)"
            ),
            (
                "CameraPermissionDenied",
                { session, call in session.onCameraPermissionDenied(status: call == 0 ? "declined" : "denied") },
                "Liveness CameraPermissionDenied(sessionId=session-1, status=declined)"
            ),
            ("FrameBeforeSessionReady", { session, _ in session.onFrameBeforeSessionReady() }, "Liveness FrameBeforeSessionReady"),
            ("ColorSequenceStarted", { session, _ in session.onColorDisplayed() }, "Liveness ColorSequenceStarted(sessionId=session-1)"),
            (
                "ChallengeCompleted",
                { session, _ in session.onChallengeCompleted() },
                "Liveness ChallengeCompleted(sessionId=session-1, framesAnalyzed=0, phase=PRE_CHECK)"
            )
        ]
        for row in rows {
            let logger = MockLogger()
            let session = LivenessDiagnosticsFixture.makeDiagnostics(logger: logger)
            for call in 0..<3 {
                row.call(session, call)
            }
            XCTAssertEqual(logger.messages, [row.line], row.name)
        }
    }

    /// Given: A landscape first frame with padded rows, as when portrait orientation wasn't applied
    /// When: It arrives, then two portrait frames
    /// Then: One FirstFrame line describes it: its size against 480x640 and its stride against four bytes a pixel
    func testFirstFrameDescribesTheFirstFrameAlone() throws {
        diagnostics.onCameraFrame(try makePixelBuffer(width: 640, height: 480, bytesPerRow: 2_624))
        diagnostics.onCameraFrame(try makePixelBuffer(bytesPerRow: 1_920))
        diagnostics.onCameraFrame(try makePixelBuffer(bytesPerRow: 1_920))

        XCTAssertEqual(logger.messages, [
            "Liveness FirstFrame(sessionId=session-1, frame=640x480, targetFrame=480x640, resolutionMatchesTarget=false, "
                + "rowStride=2624, expectedRowStride=2560, rowStridePadded=true, format=BGRA)"
        ])
    }

    /// Given: A camera delivering 420f frames rather than BGRA
    /// When: The first frame arrives
    /// Then: FirstFrame names the frame's own format
    func testFirstFrameNamesTheFramesFormat() throws {
        diagnostics.onCameraFrame(try makePixelBuffer(format: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange))

        XCTAssertEqual(logger.messages.map { fields(of: $0)["format"] }, ["420f"])
    }

    /// Given: A device on which analyzing frames fails
    /// When: Fifty frames fail, the first in another stage, and the session ends
    /// Then: Only the first failure is logged, and SessionEnded counts all fifty
    func testOnlyTheFirstAnalyzeFailureIsLoggedButAllAreCounted() {
        let cause = NSError(domain: "VNErrorDomain", code: 9, userInfo: [NSLocalizedDescriptionKey: "Prediction failed."])
        diagnostics.onAnalyzeError(FrameAnalysisFailure(stage: .prediction, cause: cause))
        for _ in 0..<49 {
            diagnostics.onAnalyzeError(FrameAnalysisFailure(stage: .imageConversion, cause: nil))
        }
        diagnostics.onTeardown()

        XCTAssertEqual(
            logger.lines(named: "AnalyzeFailed"),
            ["Liveness AnalyzeFailed(sessionId=session-1, stage=prediction, cause=VNErrorDomain(9): Prediction failed.)"]
        )
        XCTAssertEqual(sessionEnded(in: logger)["analyzeErrors"], "50")
    }

    /// Given: A host that retries the check
    /// When: An attempt starts, then one whose session couldn't be started, without the pre-check
    /// Then: Each logs SessionStarting with its own values and the session's device and region
    func testSessionStartingIsLoggedForEveryAttempt() {
        diagnostics.onSessionStartRequested(attempt: 1, codec: "H264", preCheckEnabled: true)
        diagnostics.onSessionStartRequested(attempt: nil, codec: "HEVC", preCheckEnabled: false)

        XCTAssertEqual(logger.messages, [
            "Liveness SessionStarting(sessionId=session-1, attempt=1, device=Apple/iPhone16,2, livenessVersion=1.5.3, codec=H264, "
                + "preCheckEnabled=true, osVersion=18.5, amplifyVersion=2.63.0, region=us-east-1)",
            "Liveness SessionStarting(sessionId=session-1, attempt=null, device=Apple/iPhone16,2, livenessVersion=1.5.3, codec=HEVC, "
                + "preCheckEnabled=false, osVersion=18.5, amplifyVersion=2.63.0, region=us-east-1)"
        ])
    }

    /// Given: A movement challenge, then a light challenge with other thresholds
    /// When: Both configurations arrive
    /// Then: Each logs SessionReady with its challenge type and its Double thresholds as Floats
    func testSessionReadyIsLoggedForEveryConfiguration() {
        let light = LivenessDiagnosticsFixture.ovalMatchChallenge(
            faceDetectionThreshold: 0.1 + 0.2,
            iouThreshold: 0.35,
            ovalFitTimeout: 7_000
        )

        diagnostics.onSessionReady(LivenessDiagnosticsFixture.movementConfiguration(), challengeID: "challenge-1")
        diagnostics.onSessionReady(.faceMovementAndLight(.init(colors: []), light), challengeID: "challenge-2")

        XCTAssertEqual(logger.messages, [
            "Liveness SessionReady(sessionId=session-1, challengeType=FaceMovementChallenge, challengeId=challenge-1, "
                + "faceDetectionThreshold=0.7, targetIouThreshold=0.6, ovalFitTimeout=30000)",
            "Liveness SessionReady(sessionId=session-1, challengeType=FaceMovementAndLightChallenge, challengeId=challenge-2, "
                + "faceDetectionThreshold=0.3, targetIouThreshold=0.35, ovalFitTimeout=7000)"
        ])
    }

    // MARK: - Face count

    /// Given: Sequences of face counts, one a frame
    /// When: Each frame is analyzed
    /// Then: The first is a baseline, and a new count is logged, from the last one logged, once it holds for three
    ///       frames in a row, so a count that flickers or holds for fewer frames logs nothing
    func testAFaceCountChangeIsLoggedOnceItHoldsForThreeFrames() {
        let flickering = Array(repeating: [1, 0], count: 10).flatMap { $0 }
        let rows: [(name: String, counts: [Int], logged: [String])] = [
            ("a held count", [2, 2, 2, 2], []),
            ("a change held for one frame", [1, 0, 1], []),
            ("a change held for two frames", [1, 0, 0, 1], []),
            ("a change held for three frames", [1, 0, 0, 0], ["1->0 at 4"]),
            ("flickering", flickering, []),
            ("a change and back", [0, 0, 0, 1, 1, 1, 0, 0, 0], ["0->1 at 6", "1->0 at 9"]),
            ("a change interrupted by the logged count", [1, 0, 0, 1, 0, 0, 0], ["1->0 at 7"]),
            ("a change interrupted by another", [1, 0, 0, 2, 2, 2], ["1->2 at 6"])
        ]
        for row in rows {
            let logger = MockLogger()
            let session = LivenessDiagnosticsFixture.makeDiagnostics(logger: logger)
            row.counts.forEach { session.onFrameAnalyzed(faceCount: $0, topScore: 0.9) }

            let logged = logger.lines(named: "FaceCountChanged").map(fields(of:))
                .map { "\($0["from"] ?? "?")->\($0["to"] ?? "?") at \($0["framesAnalyzed"] ?? "?")" }
            XCTAssertEqual(logged, row.logged, row.name)
        }
    }

    /// Given: Frames analyzed with 1, 0, 0, 0, 2, 2 and 2 faces, each scoring differently and the first highest
    /// When: Their reports arrive
    /// Then: Each change is logged on the frame that confirmed it, with that frame's count of frames analyzed and score
    func testAFaceCountChangeIsLoggedWithTheFrameThatConfirmedIt() {
        let frames: [(faces: Int, score: Float)] = [(1, 0.98), (0, 0.4), (0, 0.3), (0, 0.2), (2, 0.91), (2, 0.93), (2, 0.95)]
        for frame in frames {
            diagnostics.onFrameReport(FaceDetectionFrameReport(faceCount: frame.faces, topScore: frame.score, usedSessionThreshold: true))
        }

        XCTAssertEqual(logger.messages, [
            "Liveness FaceCountChanged(sessionId=session-1, from=1, to=0, framesAnalyzed=4, topScore=0.2, phase=PRE_CHECK)",
            "Liveness FaceCountChanged(sessionId=session-1, from=0, to=2, framesAnalyzed=7, topScore=0.95, phase=PRE_CHECK)"
        ])
    }

    // MARK: - Oval position

    /// Given: Sequences of the face's position against the oval
    /// When: Each is measured and the session ends
    /// Then: A position is logged once it holds for three frames in a row, and every change is counted
    func testOvalPositionIsLoggedOnceItHoldsForThreeFramesAndEveryChangeIsCounted() {
        let held: [FaceOvalPosition] = Array(repeating: .tooFar, count: 5) + Array(repeating: .matched, count: 6)
        let alternating: [FaceOvalPosition] = Array(repeating: [FaceOvalPosition.tooFar, .matched], count: 6).flatMap { $0 }
        let interrupted: [FaceOvalPosition] = [.tooFar, .tooFar, .tooFar, .tooClose, .tooClose, .tooFarLeft, .tooClose, .tooClose]
        let rows: [(name: String, positions: [FaceOvalPosition], logged: [String], changes: String)] = [
            ("two frames", [.tooFar, .tooFar], [], "0"),
            ("three frames", [.tooFar, .tooFar, .tooFar], ["null->TOO_FAR"], "0"),
            ("a held change", held, ["null->TOO_FAR", "TOO_FAR->MATCHED"], "1"),
            ("alternating", alternating, [], "11"),
            ("flapping off the logged position", [.matched, .matched, .matched] + alternating, ["null->MATCHED"], "12"),
            ("an interrupted run", interrupted, ["null->TOO_FAR"], "3"),
            ("a run held after an interruption", interrupted + [.tooClose], ["null->TOO_FAR", "TOO_FAR->TOO_CLOSE"], "3"),
            ("no positions", [], [], "0")
        ]
        for row in rows {
            let logger = MockLogger()
            let session = LivenessDiagnosticsFixture.makeDiagnostics(logger: logger)
            session.onInitialFaceDetectedSent()
            row.positions.forEach { session.onOvalMeasurement(OvalMeasurement(position: $0, iou: 0.5)) }
            session.onTeardown()

            let logged = logger.lines(named: "OvalPositionChanged").map(fields(of:)).map { "\($0["from"] ?? "?")->\($0["to"] ?? "?")" }
            XCTAssertEqual(logged, row.logged, row.name)
            XCTAssertEqual(sessionEnded(in: logger)["ovalPositionChanges"], row.changes, row.name)
        }
    }

    /// Given: A session that hasn't sent its initial face
    /// When: The face is measured in and out of the oval, then the initial face is sent and it's measured again
    /// Then: The early measurements are ignored, and the first later match logs FirstOvalMatch at once and is
    ///       itself an IoU sample, its position being applied before its IoU
    func testOvalMeasurementsCountFromTheInitialFaceAndTheFirstMatchIsSampled() {
        let measure = { (frames: [(FaceOvalPosition, Double)]) in
            for (position, iou) in frames {
                self.diagnostics.onFrameAnalyzed(faceCount: 1, topScore: 0.9)
                self.diagnostics.onOvalMeasurement(OvalMeasurement(position: position, iou: iou))
            }
        }
        measure([(.matched, 0.3), (.matched, 0.3), (.matched, 0.3), (.tooFar, 0.1)])
        XCTAssertEqual(logger.messages, [])

        diagnostics.onInitialFaceDetectedSent()
        logger.clear()
        measure([(.tooFar, 0.2), (.matched, 0.5), (.matched, 0.7), (.matched, 0.9)])

        XCTAssertEqual(logger.messages, [
            "Liveness FirstOvalMatch(sessionId=session-1, framesAnalyzed=6, phase=OVAL_FIT)",
            "Liveness OvalPositionChanged(sessionId=session-1, from=null, to=MATCHED, phase=OVAL_FIT)"
        ])
        diagnostics.onTeardown()
        let summary = sessionEnded(in: logger)
        XCTAssertEqual(summary["ovalPositionChanges"], "1")
        XCTAssertEqual(summary["challengeFrames"], "3")
        XCTAssertEqual(summary["challengeFramesWithFace"], "3")
        XCTAssertEqual(summary["challengeMinIou"], "0.5")
    }

    // MARK: - Distance

    /// Given: Sequences of measured face distances
    /// When: Each is measured
    /// Then: A distance is logged when it's finite and at least 0.05 from the last one logged
    func testFaceDistanceIsLoggedWhenItMovesAtLeastTheBandFromTheLastLoggedOne() {
        let rows: [(name: String, distances: [Float], logged: [String])] = [
            ("inside the band", [0.50, 0.52, 0.48, 0.53], ["0.5"]),
            ("crossing the band", [0.50, 0.56, 0.30], ["0.5", "0.56", "0.3"]),
            ("drifting across it", [0.50, 0.53, 0.56], ["0.5", "0.56"]),
            ("exactly the band", [0, Float(0.05).nextDown, 0.05], ["0.0", "0.05"]),
            ("not finite", [.nan, .infinity, -.infinity, 0.5, .nan, .infinity, 0.52], ["0.5"])
        ]
        for row in rows {
            let logger = MockLogger()
            let session = LivenessDiagnosticsFixture.makeDiagnostics(logger: logger)
            row.distances.forEach(session.onFaceDistance)
            XCTAssertEqual(logger.messages.map { fields(of: $0)["distance"] ?? $0 }, row.logged, row.name)
        }
    }

    /// Given: A session whose distance threshold is 0.32, with a different minimum and maximum
    /// When: A distance is measured
    /// Then: It's logged against 0.32, the threshold the pre-check uses
    func testFaceDistanceIsLoggedAgainstTheSessionsDistanceThreshold() {
        let challenge = FaceLivenessSession.OvalMatchChallenge(
            faceDetectionThreshold: 0.7,
            face: .init(
                distanceThreshold: 0.32,
                distanceThresholdMax: 0.5,
                distanceThresholdMin: 0.2,
                iouWidthThreshold: 0.15,
                iouHeightThreshold: 0.15
            ),
            oval: LivenessDiagnosticsFixture.ovalMatchChallenge().oval
        )
        diagnostics.onSessionReady(.faceMovement(challenge), challengeID: "challenge-1")

        diagnostics.onFaceDistance(0.31)

        XCTAssertEqual(logger.lines(named: "FaceDistanceChanged").map { fields(of: $0)["faceDistanceThreshold"] }, ["0.32"])
    }

    // MARK: - Phase

    /// Given: A light challenge
    /// When: A face appears, the initial face is sent, the face fits the oval, a color shows, a second face
    ///       appears and the challenge completes
    /// Then: Each line carries the phase it was logged in: PRE_CHECK, then OVAL_FIT, then COLOR_SEQUENCE
    func testEachLineCarriesThePhaseItWasLoggedIn() {
        let debounce = LivenessSessionDiagnostics.debounceFrames
        diagnostics.onFrameAnalyzed(faceCount: 0, topScore: 0.1)
        for _ in 0..<debounce {
            diagnostics.onFrameAnalyzed(faceCount: 1, topScore: 0.9)
        }
        diagnostics.onInitialFaceDetectedSent()
        diagnostics.onFaceDistance(0.3)
        for _ in 0..<debounce {
            diagnostics.onOvalMeasurement(OvalMeasurement(position: .matched, iou: 0.5))
        }
        diagnostics.onColorDisplayed()
        for _ in 0..<debounce {
            diagnostics.onFrameAnalyzed(faceCount: 2, topScore: 0.9)
        }
        diagnostics.onChallengeCompleted()

        let phases = logger.messages.compactMap { line in fields(of: line)["phase"].map { "\(eventName(of: line)) \($0)" } }
        XCTAssertEqual(phases, [
            "FaceCountChanged PRE_CHECK",
            "FaceDistanceChanged OVAL_FIT",
            "FirstOvalMatch OVAL_FIT",
            "OvalPositionChanged OVAL_FIT",
            "FaceCountChanged COLOR_SEQUENCE",
            "ChallengeCompleted COLOR_SEQUENCE"
        ])
        XCTAssertEqual(
            logger.lines(named: "ChallengeCompleted"),
            ["Liveness ChallengeCompleted(sessionId=session-1, framesAnalyzed=\(1 + 2 * debounce), phase=COLOR_SEQUENCE)"]
        )
    }

    /// Given: A movement challenge that fit the oval, and a color reported before the initial face
    /// When: Each challenge completes
    /// Then: The first ends in OVAL_FIT and the second in COLOR_SEQUENCE, since the phase never moves back
    func testThePhaseOnlyMovesForward() {
        let rows: [(name: String, steps: (LivenessSessionDiagnostics) -> Void, phase: String)] = [
            ("a movement challenge", { session in
                session.onInitialFaceDetectedSent()
                for _ in 0..<3 {
                    session.onOvalMeasurement(OvalMeasurement(position: .matched, iou: 0.5))
                }
            }, "OVAL_FIT"),
            ("a color before the initial face", { session in
                session.onColorDisplayed()
                session.onInitialFaceDetectedSent()
            }, "COLOR_SEQUENCE")
        ]
        for row in rows {
            let logger = MockLogger()
            let session = LivenessDiagnosticsFixture.makeDiagnostics(logger: logger)
            row.steps(session)
            session.onChallengeCompleted()
            XCTAssertEqual(logger.lines(named: "ChallengeCompleted").map { fields(of: $0)["phase"] }, [row.phase], row.name)
        }
    }

    // MARK: - InitialFaceDetected timing

    /// Given: Frames at 1.0, 1.5 and 2.0 s, and the check reported started at 1.5 and 2.0 s
    /// When: The initial face is sent at 3.0 s, and again at 3.5 s
    /// Then: One line is logged, timed from the first frame and the first check start
    func testInitialFaceDetectedIsLoggedOnceTimedFromTheFirstFrameAndCheckStart() throws {
        clock.now = 1_000
        diagnostics.onCameraFrame(try makePixelBuffer())
        clock.now = 1_500
        diagnostics.onCameraFrame(try makePixelBuffer())
        diagnostics.onCheckStarted()
        clock.now = 2_000
        diagnostics.onCameraFrame(try makePixelBuffer())
        diagnostics.onCheckStarted()
        clock.now = 3_000
        diagnostics.onInitialFaceDetectedSent()
        clock.now = 3_500
        diagnostics.onInitialFaceDetectedSent()

        XCTAssertEqual(
            logger.lines(named: "InitialFaceDetected"),
            ["Liveness InitialFaceDetected(sessionId=session-1, elapsedSinceFirstFrameMs=2000, elapsedSinceCheckStartMs=1500)"]
        )
    }

    /// Given: A session with no check start reported, and one with no camera frame
    /// When: The initial face is sent 300 ms after the frame or the check start
    /// Then: The missing check start is null, and the missing first frame is 0
    func testInitialFaceDetectedWithoutACheckStartOrAFrame() throws {
        let buffer = try makePixelBuffer()
        let rows: [(name: String, start: (LivenessSessionDiagnostics) -> Void, line: String)] = [
            (
                "no check start",
                { $0.onCameraFrame(buffer) },
                "Liveness InitialFaceDetected(sessionId=session-1, elapsedSinceFirstFrameMs=300, elapsedSinceCheckStartMs=null)"
            ),
            (
                "no frame",
                { $0.onCheckStarted() },
                "Liveness InitialFaceDetected(sessionId=session-1, elapsedSinceFirstFrameMs=0, elapsedSinceCheckStartMs=300)"
            )
        ]
        for row in rows {
            let logger = MockLogger()
            let clock = TestClock(now: 1_000)
            let session = LivenessDiagnosticsFixture.makeDiagnostics(logger: logger, clock: clock)
            row.start(session)
            clock.now = 1_300
            session.onInitialFaceDetectedSent()
            XCTAssertEqual(logger.lines(named: "InitialFaceDetected"), [row.line], row.name)
        }
    }

    // MARK: - Frame reports

    /// Given: Failed frames, one before SessionReady, and frames with a face scored before SessionReady
    /// When: Their reports arrive, then three analyzed frames without a face
    /// Then: Failures count only as analyze errors and early frames only log FrameBeforeSessionReady:
    ///       none starts the watchdog, sets the face count or counts as analyzed
    func testOnlyAnalyzedFrameReportsCountAsAnalyzedFrames() {
        let failure = FrameAnalysisFailure(stage: .prediction, cause: nil)
        diagnostics.onFrameReport(FaceDetectionFrameReport(faceCount: 1, topScore: 0.9, usedSessionThreshold: true, failure: failure))
        diagnostics.onFrameReport(FaceDetectionFrameReport(usedSessionThreshold: false, failure: failure))
        diagnostics.onFrameReport(FaceDetectionFrameReport(faceCount: 1, topScore: 0.8, usedSessionThreshold: false))
        diagnostics.onFrameReport(FaceDetectionFrameReport(faceCount: 1, topScore: 0.8, usedSessionThreshold: false))
        XCTAssertTrue(scheduler.items.isEmpty, "an unanalyzed frame started the watchdog")

        // enough to log a change, had an early frame set the face count
        let debounce = LivenessSessionDiagnostics.debounceFrames
        for _ in 0..<debounce {
            diagnostics.onFrameReport(FaceDetectionFrameReport(faceCount: 0, topScore: 0.1, usedSessionThreshold: true))
        }

        XCTAssertEqual(logger.messages, [
            "Liveness AnalyzeFailed(sessionId=session-1, stage=prediction, cause=null)",
            "Liveness FrameBeforeSessionReady"
        ])
        diagnostics.onTeardown()
        let summary = sessionEnded(in: logger)
        XCTAssertEqual(summary["framesAnalyzed"], String(debounce))
        XCTAssertEqual(summary["faceEverDetected"], "false")
        XCTAssertEqual(summary["analyzeErrors"], "2")
    }

    // MARK: - Support

    /// The fields of the SessionEnded line `logger` received.
    private func sessionEnded(in logger: MockLogger) -> [String: String] {
        logger.lines(named: "SessionEnded").first.map(fields(of:)) ?? [:]
    }

    /// The name of the event a line was logged for, such as `SessionEnded`.
    private func eventName(of line: String) -> String {
        String(line.dropFirst("Liveness ".count).prefix { $0 != "(" })
    }

    /// A frame with `bytesPerRow` bytes a row when given, so its stride is known; otherwise laid out
    /// however CoreVideo chooses, which planar formats need.
    private func makePixelBuffer(
        width: Int = 480,
        height: Int = 640,
        bytesPerRow: Int? = nil,
        format: OSType = kCVPixelFormatType_32BGRA
    ) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status: CVReturn
        if let bytesPerRow {
            let bytes = UnsafeMutableRawPointer.allocate(byteCount: bytesPerRow * height, alignment: 64)
            status = CVPixelBufferCreateWithBytes(
                kCFAllocatorDefault, width, height, format, bytes, bytesPerRow,
                { _, baseAddress in
                    if let baseAddress {
                        UnsafeMutableRawPointer(mutating: baseAddress).deallocate()
                    }
                },
                nil, nil, &buffer
            )
        } else {
            status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, format, nil, &buffer)
        }
        XCTAssertEqual(status, kCVReturnSuccess, "creating a \(width)x\(height) buffer")
        return try XCTUnwrap(buffer)
    }
}
