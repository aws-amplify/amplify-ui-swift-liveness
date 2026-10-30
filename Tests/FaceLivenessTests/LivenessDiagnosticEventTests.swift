//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import AVFoundation
import SwiftUI
import Amplify
// with the SPI, which FaceLivenessSessionError.diagnosticName inherits from its type
@_spi(PredictionsFaceLiveness) @testable import FaceLiveness
// for FaceLivenessSessionError(code:)
@testable import AWSPredictionsPlugin
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

/// How each diagnostic line renders, and the name, close code, cause and format tables behind its fields.
final class LivenessDiagnosticEventTests: XCTestCase {
    private typealias LivenessError = LivenessStateMachine.LivenessError

    private let id = LivenessDiagnosticsFixture.sessionID

    // MARK: - Events

    /// Given: One of each event
    /// When: It's rendered
    /// Then: It's the exact line, at Android's level
    func testEachEventRendersItsFieldsInOrderAtItsLevel() {
        for (event, line, level) in renderings {
            XCTAssertEqual(event.description, line, event.name)
            XCTAssertEqual(event.level, level, event.name)
        }
    }

    /// Given: One of each event, and Amplify UI for Android's events
    /// When: Their category, names and keys are compared
    /// Then: Android's category and events are kept, with the shared keys first, in Android's order
    func testEventsKeepAndroidsNamesAndKeyOrder() {
        XCTAssertEqual(LivenessSessionDiagnostics.logCategory, "Liveness")
        XCTAssertEqual(Set(renderings.map { $0.event.name }), Set(Self.androidKeys.keys).union(["CameraPermissionDenied"]))

        var androidOnly: [String] = []
        for (event, _, _) in renderings {
            let keys = event.fields.map { $0.key }
            // CameraPermissionDenied is iOS only, so it shares only the session ID
            let android = (Self.androidKeys[event.name] ?? ["sessionId"]).map { Self.renamedKeys["\(event.name).\($0)"] ?? $0 }
            let shared = android.filter(keys.contains)
            XCTAssertEqual(Array(keys.prefix(shared.count)), shared, event.name)
            androidOnly += android.filter { !keys.contains($0) }.map { "\(event.name).\($0)" }
        }
        XCTAssertEqual(
            androidOnly,
            ["FirstFrame.pixelStride", "FirstFrame.rotation", "SessionError.stopSession", "FaceDetectionWatchdog.showingStartView"]
        )
    }

    /// Given: Events missing an optional value, such as the attempt of a session that couldn't start
    /// When: They're rendered
    /// Then: Each missing value renders null
    func testMissingValuesRenderNull() {
        let unstarted = LivenessDiagnosticEvent.sessionStarting(
            sessionID: id, attempt: nil, deviceInfo: .test, codec: "H264", preCheckEnabled: true, region: nil
        )
        let rows: [(event: LivenessDiagnosticEvent, key: String)] = [
            (unstarted, "attempt"),
            (unstarted, "region"),
            (.initialFaceDetected(sessionID: id, elapsedSinceFirstFrameMs: 0, elapsedSinceCheckStartMs: nil), "elapsedSinceCheckStartMs"),
            (.sessionError(sessionID: id, type: "unknown", message: "", cause: nil, closeCode: "RUNTIME_ERROR", reason: "unknown"), "cause"),
            (.analyzeFailed(sessionID: id, failure: FrameAnalysisFailure(stage: .noImageBuffer, cause: nil)), "cause"),
            (.ovalPositionChanged(sessionID: id, from: nil, to: .tooFar, phase: .preCheck), "from")
        ]
        for (event, key) in rows {
            XCTAssertEqual(field(key, of: event), "null", "\(event.name).\(key)")
        }
    }

    /// Given: First frames matching the target on one side only or in landscape, and one with padded rows
    /// When: They're rendered
    /// Then: None of the first match the target, and the last is padded
    func testFirstFrameMatchesTheTargetOnBothSidesAndFlagsPaddedRows() {
        func firstFrame(width: Int, height: Int, rowStride: Int) -> LivenessDiagnosticEvent {
            .firstFrame(
                sessionID: id, width: width, height: height, targetWidth: 480, targetHeight: 640,
                rowStride: rowStride, expectedRowStride: width * 4, format: "BGRA"
            )
        }
        // frames arrive rotated to portrait, so unlike on Android a landscape one doesn't match
        for (width, height) in [(480, 480), (360, 640), (640, 480)] {
            let frame = firstFrame(width: width, height: height, rowStride: width * 4)
            XCTAssertEqual(field("resolutionMatchesTarget", of: frame), "false", "\(width)x\(height)")
        }
        XCTAssertEqual(field("rowStridePadded", of: firstFrame(width: 480, height: 640, rowStride: 1984)), "true")
    }

    /// Given: A face distance below, at and above the threshold
    /// When: FaceDistanceChanged is rendered for each
    /// Then: Only the one above exceeds it, as only that fails the pre-check
    func testFaceDistanceExceedsTheThresholdOnlyAboveIt() {
        let exceeds = [Float(0.31), 0.32, 0.33].map { distance in
            field("exceedsThreshold", of: .faceDistanceChanged(sessionID: id, distance: distance, faceDistanceThreshold: 0.32, phase: .preCheck))
        }
        XCTAssertEqual(exceeds, ["false", "false", "true"])
    }

    /// Given: A watchdog that read no gates, and one whose detector has no session configuration
    /// When: They're rendered
    /// Then: The unread gates render their defaults, and the missing configuration renders absent
    func testFaceDetectionWatchdogRendersMissingGates() {
        func watchdog(_ gates: GateSnapshot?) -> LivenessDiagnosticEvent {
            .faceDetectionWatchdog(
                sessionID: id, elapsedMs: 10_000, framesAnalyzed: 0, maxDetectionScore: 0, faceDetectionThreshold: 0.7,
                analyzeErrors: 0, gates: gates, framesDelivered: 0
            )
        }
        let gates = ["readyForOval", "faceTargetChallenge", "initialFaceDistanceCheckPassed", "checkState", "captureRunning"]
        XCTAssertEqual(gates.map { field($0, of: watchdog(nil)) }, ["false", "unknown", "false", "unknown", "false"])

        let noConfiguration = GateSnapshot(
            readyForOval: true, faceTargetChallengePresent: false, initialFaceDistanceCheckPassed: false,
            checkState: "initial", captureRunning: true
        )
        XCTAssertEqual(field("faceTargetChallenge", of: watchdog(noConfiguration)), "absent")
    }

    // MARK: - Values

    /// Given: Values of every kind
    /// When: They're rendered
    /// Then: Floats render as Kotlin's from 1e-3 up, smaller ones in Swift's notation, and line breaks as spaces
    func testValuesRender() {
        let rows: [(value: LivenessDiagnosticEvent.Value, rendered: String)] = [
            (.float(0), "0.0"), (.float(Float(0.6 as Double)), "0.6"), (.float(0.0005), "0.0005"), (.float(4.54e-5), "4.54e-05"),
            (.float(.nan), "NaN"), (.float(.infinity), "Infinity"), (.float(-.infinity), "-Infinity"),
            (.int(30_000), "30000"), (.bool(true), "true"), (.bool(false), "false"), (.null, "null"),
            (.string("one\ntwo\rthree\r\nfour"), "one two three  four")
        ]
        for (value, rendered) in rows {
            XCTAssertEqual(value.rendered, rendered, "\(value)")
        }
    }

    // MARK: - Names, close codes and host errors

    /// Given: Every liveness error, and a code none has
    /// When: Each is named and mapped to the error the host receives
    /// Then: Each is named as declared and reaches the host as before diagnostics; the other code by number
    func testLivenessErrorsAreNamedAndReachTheHostAsBefore() {
        let rows: [(error: LivenessError, name: String, hostError: FaceLivenessDetectionError)] = [
            (.unknown, "unknown", .cameraPermissionDenied),
            (.missingVideoPermission, "missingVideoPermission", .cameraPermissionDenied),
            (.errorWithUnderlyingOSFramework, "errorWithUnderlyingOSFramework", .cameraPermissionDenied),
            (.userCancelled, "userCancelled", .userCancelled),
            (.timedOut, "timedOut", .faceInOvalMatchExceededTimeLimitError),
            (.couldNotOpenStream, "couldNotOpenStream", .socketClosed),
            (.socketClosed, "socketClosed", .socketClosed),
            (.viewResignation, "viewResignation", .sessionInterrupted),
            (.cameraNotAvailable, "cameraNotAvailable", .cameraNotAvailable)
        ]
        for (error, name, hostError) in rows {
            XCTAssertEqual(error.diagnosticName, name, "code \(error.code)")
            XCTAssertEqual(error.hostError, hostError, name)
        }
        XCTAssertEqual(LivenessError(code: 7, webSocketCloseCode: nil).diagnosticName, "code7")
    }

    /// Given: Every service error, and a code none has
    /// When: Each is named and mapped to the error the host receives
    /// Then: Each is named as declared and reaches the host as before diagnostics; the other code by number
    func testServiceErrorsAreNamedAndReachTheHostAsBefore() {
        XCTAssertEqual(Self.serviceErrors.map { $0.error.code }, Array(UInt8(0)...10))
        for (error, name, hostError) in Self.serviceErrors {
            XCTAssertEqual(error.diagnosticName, name, "code \(error.code)")
            XCTAssertEqual(FaceLivenessDetectionError.hostError(for: error), hostError, name)
        }
        XCTAssertEqual(FaceLivenessSessionError(code: 11).diagnosticName, "code11")
    }

    /// Given: A detector view's liveness session
    /// When: The session reports every service error
    /// Then: The host's completion handler receives each as it did before diagnostics
    @MainActor
    func testTheDetectorViewReportsServiceErrorsAsBefore() async throws {
        let received = EventLog<FaceLivenessDetectionError>()
        let detector = FaceLivenessDetectorView(
            sessionID: UUID().uuidString,
            credentialsProvider: MockCredentialsProvider { MockAWSCredentials(accessKeyId: "accessKey", secretAccessKey: "secretKey") },
            region: "us-east-1",
            isPresented: .constant(true),
            onCompletion: { result in
                if case .failure(let error) = result { received.append(error) }
            }
        )
        let session = try await detector.sessionTask.value

        Self.serviceErrors.forEach { session.onServiceException($0.error) }

        XCTAssertEqual(received.events.map(\.diagnosticName), Self.serviceErrors.map { $0.hostError.diagnosticName })
    }

    /// Given: Every error the host can receive and every capture session error, and codes none has
    /// When: They're named
    /// Then: Each is named as declared, and the other codes by their number
    func testDetectionAndCaptureErrorsAreNamedAsDeclared() {
        let detectionErrors: [(error: FaceLivenessDetectionError, name: String)] = [
            (.unknown, "unknown"), (.sessionNotFound, "sessionNotFound"), (.sessionTimedOut, "sessionTimedOut"),
            (.faceInOvalMatchExceededTimeLimitError, "faceInOvalMatchExceededTimeLimitError"), (.accessDenied, "accessDenied"),
            (.cameraPermissionDenied, "cameraPermissionDenied"), (.userCancelled, "userCancelled"), (.socketClosed, "socketClosed"),
            (.countdownFaceTooClose, "countdownFaceTooClose"), (.countdownMultipleFaces, "countdownMultipleFaces"),
            (.countdownNoFace, "countdownNoFace"), (.invalidRegion, "invalidRegion"), (.validation, "validation"),
            (.internalServer, "internalServer"), (.throttling, "throttling"), (.serviceQuotaExceeded, "serviceQuotaExceeded"),
            (.serviceUnavailable, "serviceUnavailable"), (.invalidSignature, "invalidSignature"),
            (.cameraNotAvailable, "cameraNotAvailable"), (.sessionInterrupted, "sessionInterrupted")
        ]
        XCTAssertEqual(detectionErrors.map { $0.error.code }, Array(UInt8(0)...19))
        for (error, name) in detectionErrors {
            XCTAssertEqual(error.diagnosticName, name, "code \(error.code)")
        }
        XCTAssertEqual(FaceLivenessDetectionError(code: 20, message: "", recoverySuggestion: "").diagnosticName, "code20")

        let captureErrors: [(error: LivenessCaptureSessionError, name: String)] = [
            (.deviceInputUnavailable, "deviceInputUnavailable"), (.cameraUnavailable, "cameraUnavailable"),
            (.captureSessionUnavailable, "captureSessionUnavailable"),
            (.captureSessionInputUnavailable, "captureSessionInputUnavailable"),
            (.captureSessionOutputUnavailable, "captureSessionOutputUnavailable")
        ]
        for (error, name) in captureErrors {
            XCTAssertEqual(error.diagnosticName, name, "code \(error.code)")
        }
        XCTAssertEqual(LivenessCaptureSessionError(code: 4).diagnosticName, "code4")
    }

    /// Given: Every check state case
    /// When: Each is named and asked whether the pre-check has passed
    /// Then: Each is named by case and payload, and only the states before the check haven't passed it
    func testCheckStatesAreNamedByCaseAndKnowWhetherThePreCheckPassed() {
        let rows: [(state: LivenessStateMachine.State, name: String, passedPreCheck: Bool)] = [
            (.initial, "initial", false),
            (.awaitingChallengeType, "awaitingChallengeType", false),
            (.pendingFacePreparedConfirmation(.noFace), "pendingFacePreparedConfirmation.noFace", false),
            (.waitForRecording, "waitForRecording", true),
            (.recording(ovalDisplayed: false), "recording", true),
            (.recording(ovalDisplayed: true), "recording.ovalDisplayed", true),
            (.awaitingFaceInOvalMatch(.moveFaceCloser, 0.4), "awaitingFaceInOvalMatch.moveFaceCloser", true),
            (.faceMatched, "faceMatched", true),
            (.initialClientInfoEventSent, "initialClientInfoEventSent", true),
            (.displayingFreshness, "displayingFreshness", true),
            (.completedDisplayingFreshness, "completedDisplayingFreshness", true),
            (.completedNoLightCheck, "completedNoLightCheck", true),
            (.completed, "completed", true),
            (.awaitingDisconnectEvent, "awaitingDisconnectEvent", true),
            (.disconnectEventReceived, "disconnectEventReceived", true),
            (.encounteredUnrecoverableError(.timedOut), "encounteredUnrecoverableError.timedOut", true)
        ]
        for (state, name, passedPreCheck) in rows {
            XCTAssertEqual(state.diagnosticName, name)
            XCTAssertEqual(state.hasPassedPreCheck, passedPreCheck, name)
        }
    }

    /// Given: Every oval position
    /// When: It's named
    /// Then: It's named as on Android
    func testOvalPositionsAreNamedAsOnAndroid() {
        let names = [FaceOvalPosition.matched, .tooFarLeft, .tooFarRight, .tooClose, .tooFar].map(\.rawValue)
        XCTAssertEqual(names, ["MATCHED", "TOO_FAR_LEFT", "TOO_FAR_RIGHT", "TOO_CLOSE", "TOO_FAR"])
    }

    /// Given: Errors with each close code the check defines, an unlisted code and none
    /// When: Their close codes are named
    /// Then: Android's names where it has the code, iOS's own for 4002, 4004 and 4006, the unlisted one's number,
    ///       and none, or a closed socket, a runtime error
    func testCloseCodesUseAndroidsNamesWhereItHasThem() {
        let rows = [
            (1000, "NORMAL"), (4001, "TIMEOUT"), (4003, "CANCELED"), (4005, "RUNTIME_ERROR"),
            // iOS only
            (4002, "TIMEOUT_NO_FACE"), (4004, "VIEW_CLOSURE"), (4006, "MISSING_VIDEO_PERMISSION"),
            (4010, "CODE_4010")
        ]
        for (rawValue, name) in rows {
            let error = LivenessError(code: 7, webSocketCloseCode: URLSessionWebSocketTask.CloseCode(rawValue: rawValue))
            XCTAssertEqual(error.diagnosticCloseCode, name, "\(rawValue)")
        }
        XCTAssertEqual(LivenessError(code: 7, webSocketCloseCode: nil).diagnosticCloseCode, "RUNTIME_ERROR")
        // the server closed it, so the normal closure sent afterwards isn't why the check ended
        XCTAssertEqual(LivenessError.socketClosed.diagnosticCloseCode, "RUNTIME_ERROR")
    }

    // MARK: - Causes

    /// Given: No error, and an error of each kind, some with an error beneath them
    /// When: Their causes are described
    /// Then: Each error is its type, or domain and code, and its description, outermost first
    func testCausesDescribeEachKindOfError() {
        let offline = URLError(.notConnectedToInternet)
        let inner = NSError(domain: "Inner", code: 3, userInfo: [NSLocalizedDescriptionKey: "inner"])
        let rows: [(error: Error?, causes: String?)] = [
            (nil, nil),
            // without the recovery suggestion
            (AuthError.service("Session expired", "Sign in again", offline),
             "AuthError: Session expired <- NSURLErrorDomain(-1009): \((offline as NSError).localizedDescription)"),
            (EncodingError.invalidValue(1, .init(codingPath: [], debugDescription: "bad value", underlyingError: inner)),
             "EncodingError: bad value <- Inner(3): inner"),
            (LivenessCaptureSessionError.cameraUnavailable, "LivenessCaptureSessionError: cameraUnavailable"),
            (FaceLivenessSessionError.invalidURL, "FaceLivenessSessionError: invalidURL"),
            (FaceLivenessDetectionError.socketClosed, "FaceLivenessDetectionError: socketClosed")
        ]
        for (error, causes) in rows {
            XCTAssertEqual(LivenessSessionDiagnostics.describeCauses(error), causes, String(describing: error))
        }
    }

    /// Given: A chain of seven errors, each the underlying error of the one before
    /// When: Its causes are described
    /// Then: Only the outermost five are, outermost first
    func testCausesKeepTheOutermostFiveOfAChain() {
        var error = NSError(domain: "Level", code: 7, userInfo: [NSLocalizedDescriptionKey: "level 7"])
        for level in (1...6).reversed() {
            error = NSError(domain: "Level", code: level, userInfo: [NSLocalizedDescriptionKey: "level \(level)", NSUnderlyingErrorKey: error])
        }

        XCTAssertEqual(
            LivenessSessionDiagnostics.describeCauses(error),
            "Level(1): level 1 <- Level(2): level 2 <- Level(3): level 3 <- Level(4): level 4 <- Level(5): level 5"
        )
    }

    /// Given: Two chained errors with 500-character descriptions
    /// When: Their causes are described
    /// Then: Each entry is cut to its first 200 characters
    func testCausesCutEachEntryTo200Characters() {
        let long = String(repeating: "x", count: 500)
        let inner = NSError(domain: "Inner", code: 2, userInfo: [NSLocalizedDescriptionKey: long])
        let outer = NSError(domain: "Outer", code: 1, userInfo: [NSLocalizedDescriptionKey: long, NSUnderlyingErrorKey: inner])

        let kept = String(repeating: "x", count: 190)
        XCTAssertEqual(LivenessSessionDiagnostics.describeCauses(outer), "Outer(1): \(kept) <- Inner(2): \(kept)")
    }

    /// Given: An Amplify error quoting a Cognito identity ID, and a description that would be cut inside one
    /// When: Their causes are described
    /// Then: Each ID's UUID is masked and the rest is left alone
    func testCausesMaskCognitoIdentityIDs() {
        let identityID = "us-east-1:0f7c1a2b-3c4d-5e6f-7a8b-9c0d1e2f3a4b"
        let notAuthorized = AuthError.notAuthorized("Access to Identity '\(identityID)' is forbidden.", "Check the role")
        XCTAssertEqual(
            LivenessSessionDiagnostics.describeCauses(notAuthorized),
            "AuthError: Access to Identity 'us-east-1:<masked>' is forbidden."
        )

        // masked before the entry is cut to 200 characters, which would otherwise keep part of the UUID
        let padding = String(repeating: "x", count: 159)
        let long = NSError(domain: "Outer", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(padding) \(identityID)"])
        XCTAssertEqual(LivenessSessionDiagnostics.describeCauses(long), "Outer(1): \(padding) us-east-1:<masked>")
    }

    // MARK: - Formats, codecs and device

    /// Given: The BGRA and 420f pixel formats, and 32ARGB, which is a number rather than four characters
    /// When: Their four-character codes are read
    /// Then: The formats are named by their characters, and 32ARGB is unknown, with its number
    func testFourCharCodesNamePixelFormats() {
        XCTAssertEqual(LivenessSessionDiagnostics.fourCharCode(kCVPixelFormatType_32BGRA), "BGRA")
        XCTAssertEqual(LivenessSessionDiagnostics.fourCharCode(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange), "420f")
        XCTAssertEqual(LivenessSessionDiagnostics.fourCharCode(kCVPixelFormatType_32ARGB), "UNKNOWN(32)")
    }

    /// Given: A codec type, a codec's raw string, an unlisted codec, nothing and a non-codec
    /// When: Their codec names are read
    /// Then: H.264 and HEVC are named as on Android, the unlisted codec keeps its name, the rest are unknown
    func testCodecNamesNameTheVideoCodec() {
        let rows: [(codec: Any?, name: String)] = [
            (AVVideoCodecType.h264, "H264"), ("hvc1", "HEVC"), (AVVideoCodecType(rawValue: "abcd"), "abcd"),
            (nil, "Unknown"), (42, "Unknown")
        ]
        for (codec, name) in rows {
            XCTAssertEqual(LivenessSessionDiagnostics.codecName(codec), name, String(describing: codec))
        }
    }

    /// Given: The device the tests run on
    /// When: Its device info is read
    /// Then: It names the model, the OS version and both library versions
    @MainActor
    func testCurrentDeviceInfoDescribesThisDevice() {
        let info = LivenessDeviceInfo.current

        XCTAssertFalse(info.model.isEmpty)
        if let simulatorModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            XCTAssertEqual(info.model, simulatorModel)
        }
        XCTAssertEqual(info.osVersion, UIDevice.current.systemVersion)
        XCTAssertEqual(info.livenessVersion, UserAgentValues.libVersion)
        XCTAssertFalse(info.amplifyVersion.isEmpty)
    }

    // MARK: - Support

    /// The rendered value of `key` in `event`.
    private func field(_ key: String, of event: LivenessDiagnosticEvent) -> String? {
        event.fields.first { $0.key == key }?.value.rendered
    }

    /// One of each event with every optional value set, its line, and its level, which is Android's.
    private var renderings: [(event: LivenessDiagnosticEvent, line: String, level: LogLevel)] {
        let gates = GateSnapshot(
            readyForOval: true, faceTargetChallengePresent: true, initialFaceDistanceCheckPassed: false,
            checkState: "pendingFacePreparedConfirmation.noFace", captureRunning: true
        )
        let modelError = NSError(domain: "com.apple.CoreML", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to evaluate model"])
        return [
            (.sessionStarting(sessionID: id, attempt: 2, deviceInfo: .test, codec: "H264", preCheckEnabled: true, region: "us-east-1"),
             "SessionStarting(sessionId=session-1, attempt=2, device=Apple/iPhone16,2, api=18.5, livenessVersion=1.5.3, codec=H264, "
                 + "preCheckEnabled=true, amplifyVersion=2.63.0, region=us-east-1)", .info),
            (.firstFrame(sessionID: id, width: 480, height: 640, targetWidth: 480, targetHeight: 640,
                         rowStride: 1920, expectedRowStride: 1920, format: "BGRA"),
             "FirstFrame(sessionId=session-1, frame=480x640, targetFrame=480x640, resolutionMatchesTarget=true, rowStride=1920, "
                 + "expectedRowStride=1920, rowStridePadded=false, format=BGRA)", .info),
            (.sessionReady(sessionID: id, challengeType: "FaceMovementAndLightChallenge", challengeID: "challenge-1",
                           faceDetectionThreshold: 0.7, targetIouThreshold: 0.6, ovalFitTimeout: 30_000),
             "SessionReady(sessionId=session-1, challengeType=FaceMovementAndLightChallenge, challengeId=challenge-1, "
                 + "faceDetectionThreshold=0.7, targetIouThreshold=0.6, ovalFitTimeout=30000)", .info),
            (.cameraBound(sessionID: id, facing: "front"), "CameraBound(sessionId=session-1, facing=front)", .info),
            (.initialFaceDetected(sessionID: id, elapsedSinceFirstFrameMs: 4_200, elapsedSinceCheckStartMs: 350),
             "InitialFaceDetected(sessionId=session-1, elapsedSinceFirstFrameMs=4200, elapsedSinceCheckStartMs=350)", .info),
            (.colorSequenceStarted(sessionID: id), "ColorSequenceStarted(sessionId=session-1)", .info),
            (.challengeCompleted(sessionID: id, framesAnalyzed: 412, phase: .colorSequence),
             "ChallengeCompleted(sessionId=session-1, framesAnalyzed=412, phase=COLOR_SEQUENCE)", .info),
            (.sessionEnded(sessionID: id, framesAnalyzed: 300, faceEverDetected: true, ovalEverMatched: true, ovalPositionChanges: 4,
                           challengeFrames: 120, challengeFramesWithFace: 118, challengeMinIou: 0.32, challengeMeanIou: 0.75,
                           analyzeErrors: 2, closeCode: "NORMAL", framesDropped: 3),
             "SessionEnded(sessionId=session-1, framesAnalyzed=300, faceEverDetected=true, ovalEverMatched=true, ovalPositionChanges=4, "
                 + "challengeFrames=120, challengeFramesWithFace=118, challengeMinIou=0.32, challengeMeanIou=0.75, analyzeErrors=2, "
                 + "closeCode=NORMAL, framesDropped=3)", .info),
            (.sessionError(sessionID: id, type: "socketClosed", message: "Websocket connection unexpectedly closed",
                           cause: "NSURLErrorDomain(-1009): offline", closeCode: "RUNTIME_ERROR", reason: "couldNotOpenStream"),
             "SessionError(sessionId=session-1, type=socketClosed, message=Websocket connection unexpectedly closed, "
                 + "cause=NSURLErrorDomain(-1009): offline, closeCode=RUNTIME_ERROR, reason=couldNotOpenStream)", .warn),
            (.faceDetectionWatchdog(sessionID: id, elapsedMs: 10_012, framesAnalyzed: 300, maxDetectionScore: 0.68,
                                    faceDetectionThreshold: 0.7, analyzeErrors: 3, gates: gates, framesDelivered: 303),
             "FaceDetectionWatchdog(sessionId=session-1, elapsedMs=10012, framesAnalyzed=300, maxDetectionScore=0.68, "
                 + "faceDetectionThreshold=0.7, analyzeErrors=3, readyForOval=true, faceTargetChallenge=present, "
                 + "initialFaceDistanceCheckPassed=false, checkState=pendingFacePreparedConfirmation.noFace, framesDelivered=303, "
                 + "captureRunning=true)", .warn),
            (.analyzeFailed(sessionID: id, failure: FrameAnalysisFailure(stage: .prediction, cause: modelError)),
             "AnalyzeFailed(sessionId=session-1, stage=prediction, cause=com.apple.CoreML(0): Failed to evaluate model)", .error),
            (.frameBeforeSessionReady, "FrameBeforeSessionReady", .debug),
            (.faceCountChanged(sessionID: id, from: 0, to: 1, framesAnalyzed: 12, topScore: 0.93, phase: .ovalFit),
             "FaceCountChanged(sessionId=session-1, from=0, to=1, framesAnalyzed=12, topScore=0.93, phase=OVAL_FIT)", .info),
            (.ovalPositionChanged(sessionID: id, from: .matched, to: .tooFar, phase: .colorSequence),
             "OvalPositionChanged(sessionId=session-1, from=MATCHED, to=TOO_FAR, phase=COLOR_SEQUENCE)", .debug),
            (.firstOvalMatch(sessionID: id, framesAnalyzed: 57, phase: .ovalFit),
             "FirstOvalMatch(sessionId=session-1, framesAnalyzed=57, phase=OVAL_FIT)", .info),
            (.faceDistanceChanged(sessionID: id, distance: 0.31, faceDistanceThreshold: 0.32, phase: .preCheck),
             "FaceDistanceChanged(sessionId=session-1, distance=0.31, faceDistanceThreshold=0.32, exceedsThreshold=false, phase=PRE_CHECK)",
             .debug),
            (.cameraPermissionDenied(sessionID: id, status: "denied"), "CameraPermissionDenied(sessionId=session-1, status=denied)", .warn)
        ]
    }

    /// The keys of each event in Amplify UI for Android, in its order.
    private static let androidKeys: [String: [String]] = [
        "SessionStarting": ["sessionId", "attempt", "device", "api", "livenessVersion", "codec", "preCheckEnabled"],
        "FirstFrame": [
            "sessionId", "frame", "targetFrame", "resolutionMatchesTarget", "rowStride", "expectedRowStride", "rowStridePadded",
            "pixelStride", "rotation", "format"
        ],
        "SessionReady": ["sessionId", "challengeType", "challengeId", "faceDetectionThreshold", "targetIouThreshold", "ovalFitTimeout"],
        "CameraBound": ["sessionId", "facing"],
        "InitialFaceDetected": ["sessionId", "elapsedSinceFirstFrameMs"],
        "ColorSequenceStarted": ["sessionId"],
        "ChallengeCompleted": ["sessionId", "framesAnalyzed", "phase"],
        "SessionEnded": [
            "sessionId", "framesAnalyzed", "faceEverDetected", "ovalEverMatched", "ovalPositionChanges", "challengeFrames",
            "challengeFramesWithFace", "challengeMinIou", "challengeMeanIou", "analyzeErrors", "closeCode"
        ],
        "SessionError": ["sessionId", "type", "message", "cause", "stopSession", "closeCode"],
        "FaceDetectionWatchdog": [
            "sessionId", "elapsedMs", "framesAnalyzed", "maxDetectionScore", "faceDetectionThreshold", "analyzeErrors",
            "showingStartView", "readyForOval", "faceTargetChallenge", "initialFaceDistanceCheckPassed", "checkState"
        ],
        // Android passes the throwable to the logger separately
        "AnalyzeFailed": ["sessionId"],
        "FrameBeforeSessionReady": [],
        "FaceCountChanged": ["sessionId", "from", "to", "framesAnalyzed", "topScore", "phase"],
        "OvalPositionChanged": ["sessionId", "from", "to", "phase"],
        "FirstOvalMatch": ["sessionId", "framesAnalyzed", "phase"],
        "FaceDistanceChanged": ["sessionId", "distance", "faceDistanceThresholdMin", "exceedsThresholdMin", "phase"]
    ]

    /// Android keys iOS renames, since iOS measures the distance differently.
    private static let renamedKeys = [
        "FaceDistanceChanged.faceDistanceThresholdMin": "faceDistanceThreshold",
        "FaceDistanceChanged.exceedsThresholdMin": "exceedsThreshold"
    ]

    /// Each service error, its name, and the error the host received for it before diagnostics.
    private static var serviceErrors: [(error: FaceLivenessSessionError, name: String, hostError: FaceLivenessDetectionError)] {
        [
            (.unknown, "unknown", .unknown),
            (.validation, "validation", .validation),
            (.internalServer, "internalServer", .internalServer),
            (.throttling, "throttling", .throttling),
            (.serviceQuotaExceeded, "serviceQuotaExceeded", .serviceQuotaExceeded),
            (.serviceUnavailable, "serviceUnavailable", .serviceUnavailable),
            (.sessionNotFound, "sessionNotFound", .sessionNotFound),
            (.accessDenied, "accessDenied", .accessDenied),
            (.invalidRegion, "invalidRegion", .invalidRegion),
            (.invalidURL, "invalidURL", .unknown),
            (.invalidSignature, "invalidSignature", .invalidSignature)
        ]
    }
}
