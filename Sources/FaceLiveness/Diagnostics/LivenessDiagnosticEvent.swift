//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Amplify

/// One diagnostic line, `Name(key=value, ...)`. Names match Amplify UI for Android; iOS-only fields come last.
struct LivenessDiagnosticEvent: CustomStringConvertible {
    let name: String
    let level: LogLevel
    let fields: [(key: String, value: Value)]

    var description: String {
        guard !fields.isEmpty else { return name }
        return name + "(" + fields.map { "\($0.key)=\($0.value.rendered)" }.joined(separator: ", ") + ")"
    }

    enum Value: Equatable {
        case string(String)
        case int(Int)
        case float(Float)
        case bool(Bool)
        case null

        static func optional(_ value: String?) -> Self { value.map(Self.string) ?? .null }
        static func optional(_ value: Int?) -> Self { value.map(Self.int) ?? .null }

        var rendered: String {
            switch self {
            case .string(let value):
                // one event, one line
                return value.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
            case .int(let value):
                return String(value)
            case .float(let value):
                if value.isNaN { return "NaN" }
                if value.isInfinite { return value < 0 ? "-Infinity" : "Infinity" }
                return value.description
            case .bool(let value):
                return value ? "true" : "false"
            case .null:
                return "null"
            }
        }
    }
}

/// The part of the check a face observation belongs to; a movement-only check never leaves `ovalFit`.
enum ChallengePhase: Comparable {
    case preCheck
    case ovalFit
    case colorSequence

    var name: String {
        switch self {
        case .preCheck: return "PRE_CHECK"
        case .ovalFit: return "OVAL_FIT"
        case .colorSequence: return "COLOR_SEQUENCE"
        }
    }
}

/// The conditions the check needs to find a face, read when the face detection watchdog fires.
struct GateSnapshot: Equatable {
    let readyForOval: Bool
    let faceTargetChallengePresent: Bool
    let initialFaceDistanceCheckPassed: Bool
    let checkState: String
    let captureRunning: Bool
}

/// Device and build metadata, captured once per session.
struct LivenessDeviceInfo: Equatable {
    let model: String
    let osVersion: String
    let livenessVersion: String
    let amplifyVersion: String

    var device: String { "Apple/\(model)" }
}

extension LivenessDiagnosticEvent {
    static func sessionStarting(
        sessionID: String,
        attempt: Int?,
        deviceInfo: LivenessDeviceInfo,
        codec: String,
        preCheckEnabled: Bool,
        region: String?
    ) -> Self {
        .init(name: "SessionStarting", level: .info, fields: [
            ("sessionId", .string(sessionID)),
            ("attempt", .optional(attempt)),
            ("device", .string(deviceInfo.device)),
            ("api", .string(deviceInfo.osVersion)),
            ("livenessVersion", .string(deviceInfo.livenessVersion)),
            ("codec", .string(codec)),
            ("preCheckEnabled", .bool(preCheckEnabled)),
            ("amplifyVersion", .string(deviceInfo.amplifyVersion)),
            ("region", .optional(region))
        ])
    }

    static func firstFrame(
        sessionID: String,
        width: Int,
        height: Int,
        targetWidth: Int,
        targetHeight: Int,
        rowStride: Int,
        expectedRowStride: Int,
        format: String
    ) -> Self {
        .init(name: "FirstFrame", level: .info, fields: [
            ("sessionId", .string(sessionID)),
            ("frame", .string("\(width)x\(height)")),
            ("targetFrame", .string("\(targetWidth)x\(targetHeight)")),
            ("resolutionMatchesTarget", .bool(width == targetWidth && height == targetHeight)),
            ("rowStride", .int(rowStride)),
            ("expectedRowStride", .int(expectedRowStride)),
            ("rowStridePadded", .bool(rowStride != expectedRowStride)),
            ("format", .string(format))
        ])
    }

    static func sessionReady(
        sessionID: String,
        challengeType: String,
        challengeID: String,
        faceDetectionThreshold: Float,
        targetIouThreshold: Float,
        ovalFitTimeout: Int
    ) -> Self {
        .init(name: "SessionReady", level: .info, fields: [
            ("sessionId", .string(sessionID)),
            ("challengeType", .string(challengeType)),
            ("challengeId", .string(challengeID)),
            ("faceDetectionThreshold", .float(faceDetectionThreshold)),
            ("targetIouThreshold", .float(targetIouThreshold)),
            ("ovalFitTimeout", .int(ovalFitTimeout))
        ])
    }

    static func cameraBound(sessionID: String, facing: String) -> Self {
        .init(name: "CameraBound", level: .info, fields: [
            ("sessionId", .string(sessionID)),
            ("facing", .string(facing))
        ])
    }

    /// The first frame can arrive on the get ready screen, so the time since the check started is logged too.
    static func initialFaceDetected(
        sessionID: String,
        elapsedSinceFirstFrameMs: Int,
        elapsedSinceCheckStartMs: Int?
    ) -> Self {
        .init(name: "InitialFaceDetected", level: .info, fields: [
            ("sessionId", .string(sessionID)),
            ("elapsedSinceFirstFrameMs", .int(elapsedSinceFirstFrameMs)),
            ("elapsedSinceCheckStartMs", .optional(elapsedSinceCheckStartMs))
        ])
    }

    static func colorSequenceStarted(sessionID: String) -> Self {
        .init(name: "ColorSequenceStarted", level: .info, fields: [
            ("sessionId", .string(sessionID))
        ])
    }

    /// Bounds the time the face still mattered, before the wait for the result.
    static func challengeCompleted(sessionID: String, framesAnalyzed: Int, phase: ChallengePhase) -> Self {
        .init(name: "ChallengeCompleted", level: .info, fields: [
            ("sessionId", .string(sessionID)),
            ("framesAnalyzed", .int(framesAnalyzed)),
            ("phase", .string(phase.name))
        ])
    }

    /// One per session, abandoned ones included. Read the IoU statistics with their sample size,
    /// `challengeFramesWithFace`: a face that leaves the frame adds no samples.
    static func sessionEnded(
        sessionID: String,
        framesAnalyzed: Int,
        faceEverDetected: Bool,
        ovalEverMatched: Bool,
        ovalPositionChanges: Int,
        challengeFrames: Int,
        challengeFramesWithFace: Int,
        challengeMinIou: Float,
        challengeMeanIou: Float,
        analyzeErrors: Int,
        closeCode: String,
        framesDropped: Int
    ) -> Self {
        .init(name: "SessionEnded", level: .info, fields: [
            ("sessionId", .string(sessionID)),
            ("framesAnalyzed", .int(framesAnalyzed)),
            ("faceEverDetected", .bool(faceEverDetected)),
            ("ovalEverMatched", .bool(ovalEverMatched)),
            ("ovalPositionChanges", .int(ovalPositionChanges)),
            ("challengeFrames", .int(challengeFrames)),
            ("challengeFramesWithFace", .int(challengeFramesWithFace)),
            ("challengeMinIou", .float(challengeMinIou)),
            ("challengeMeanIou", .float(challengeMeanIou)),
            ("analyzeErrors", .int(analyzeErrors)),
            ("closeCode", .string(closeCode)),
            ("framesDropped", .int(framesDropped))
        ])
    }

    /// `type` and `message` are what the host receives; `reason` tells apart the failures that share them.
    static func sessionError(
        sessionID: String,
        type: String,
        message: String,
        cause: String?,
        closeCode: String,
        reason: String
    ) -> Self {
        .init(name: "SessionError", level: .warn, fields: [
            ("sessionId", .string(sessionID)),
            ("type", .string(type)),
            ("message", .string(message)),
            ("cause", .optional(cause)),
            ("closeCode", .string(closeCode)),
            ("reason", .string(reason))
        ])
    }

    static func faceDetectionWatchdog(
        sessionID: String,
        elapsedMs: Int,
        framesAnalyzed: Int,
        maxDetectionScore: Float,
        faceDetectionThreshold: Float,
        analyzeErrors: Int,
        gates: GateSnapshot?,
        framesDelivered: Int
    ) -> Self {
        let faceTargetChallenge: String
        switch gates?.faceTargetChallengePresent {
        case .none: faceTargetChallenge = "unknown"
        case .some(true): faceTargetChallenge = "present"
        case .some(false): faceTargetChallenge = "absent"
        }
        return .init(name: "FaceDetectionWatchdog", level: .warn, fields: [
            ("sessionId", .string(sessionID)),
            ("elapsedMs", .int(elapsedMs)),
            ("framesAnalyzed", .int(framesAnalyzed)),
            ("maxDetectionScore", .float(maxDetectionScore)),
            ("faceDetectionThreshold", .float(faceDetectionThreshold)),
            ("analyzeErrors", .int(analyzeErrors)),
            ("readyForOval", .bool(gates?.readyForOval ?? false)),
            ("faceTargetChallenge", .string(faceTargetChallenge)),
            ("initialFaceDistanceCheckPassed", .bool(gates?.initialFaceDistanceCheckPassed ?? false)),
            ("checkState", .string(gates?.checkState ?? "unknown")),
            ("framesDelivered", .int(framesDelivered)),
            ("captureRunning", .bool(gates?.captureRunning ?? false))
        ])
    }

    static func analyzeFailed(sessionID: String, failure: FrameAnalysisFailure) -> Self {
        .init(name: "AnalyzeFailed", level: .error, fields: [
            ("sessionId", .string(sessionID)),
            ("stage", .string(failure.stage.rawValue)),
            ("cause", .optional(LivenessSessionDiagnostics.describeCauses(failure.cause)))
        ])
    }

    static let frameBeforeSessionReady = Self(name: "FrameBeforeSessionReady", level: .debug, fields: [])

    static func faceCountChanged(
        sessionID: String,
        from: Int,
        to: Int,
        framesAnalyzed: Int,
        topScore: Float,
        phase: ChallengePhase
    ) -> Self {
        .init(name: "FaceCountChanged", level: .info, fields: [
            ("sessionId", .string(sessionID)),
            ("from", .int(from)),
            ("to", .int(to)),
            ("framesAnalyzed", .int(framesAnalyzed)),
            ("topScore", .float(topScore)),
            ("phase", .string(phase.name))
        ])
    }

    /// Debug, since the match bounds coach the user rather than predict the service's verdict.
    static func ovalPositionChanged(
        sessionID: String,
        from: FaceOvalPosition?,
        to: FaceOvalPosition,
        phase: ChallengePhase
    ) -> Self {
        .init(name: "OvalPositionChanged", level: .debug, fields: [
            ("sessionId", .string(sessionID)),
            ("from", .optional(from?.rawValue)),
            ("to", .string(to.rawValue)),
            ("phase", .string(phase.name))
        ])
    }

    static func firstOvalMatch(sessionID: String, framesAnalyzed: Int, phase: ChallengePhase) -> Self {
        .init(name: "FirstOvalMatch", level: .info, fields: [
            ("sessionId", .string(sessionID)),
            ("framesAnalyzed", .int(framesAnalyzed)),
            ("phase", .string(phase.name))
        ])
    }

    /// The inter-eye distance in normalized frame coordinates against the pre-check threshold; not
    /// Android's measure, so the keys differ.
    static func faceDistanceChanged(
        sessionID: String,
        distance: Float,
        faceDistanceThreshold: Float,
        phase: ChallengePhase
    ) -> Self {
        .init(name: "FaceDistanceChanged", level: .debug, fields: [
            ("sessionId", .string(sessionID)),
            ("distance", .float(distance)),
            ("faceDistanceThreshold", .float(faceDistanceThreshold)),
            ("exceedsThreshold", .bool(distance > faceDistanceThreshold)),
            ("phase", .string(phase.name))
        ])
    }

    /// The check waits on the permission screen until the host removes it.
    static func cameraPermissionDenied(sessionID: String, status: String) -> Self {
        .init(name: "CameraPermissionDenied", level: .warn, fields: [
            ("sessionId", .string(sessionID)),
            ("status", .string(status))
        ])
    }
}
