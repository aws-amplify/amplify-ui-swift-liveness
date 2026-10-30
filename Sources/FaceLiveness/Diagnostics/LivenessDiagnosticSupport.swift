//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import AVFoundation
import UIKit
import Amplify
import InternalAmplifyCredentials
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

extension LivenessDeviceInfo {
    @MainActor static var current: LivenessDeviceInfo {
        LivenessDeviceInfo(
            model: ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? Device.current.machine,
            osVersion: UIDevice.current.systemVersion,
            livenessVersion: UserAgentValues.libVersion,
            amplifyVersion: AmplifyAWSServiceConfiguration.amplifyVersion
        )
    }
}

extension LivenessSessionDiagnostics {
    static let maxCauseDepth = 5
    static let maxCauseLength = 200

    /// Flattens an error chain into one line, outermost first, at most `maxCauseDepth` entries.
    static func describeCauses(_ error: Error?) -> String? {
        var entries: [String] = []
        var next = error
        while let error = next, entries.count < maxCauseDepth {
            let (entry, underlying) = describe(error)
            entries.append(String(maskingIdentityIDs(in: entry).prefix(maxCauseLength)))
            next = underlying
        }
        return entries.isEmpty ? nil : entries.joined(separator: " <- ")
    }

    // a Cognito identity ID, region:uuid, which service messages can quote
    private static let identityID = try? NSRegularExpression(
        pattern: "\\b([a-z]{2}(?:-[a-z]+)+-[0-9]+):[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\\b"
    )

    static func maskingIdentityIDs(in text: String) -> String {
        guard let identityID else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return identityID.stringByReplacingMatches(in: text, range: range, withTemplate: "$1:<masked>")
    }

    private static func describe(_ error: Error) -> (entry: String, underlying: Error?) {
        switch error {
        case let error as LivenessCaptureSessionError:
            return ("LivenessCaptureSessionError: \(error.diagnosticName)", nil)
        case let error as FaceLivenessSessionError:
            return ("FaceLivenessSessionError: \(error.diagnosticName)", nil)
        case let error as FaceLivenessDetectionError:
            return ("FaceLivenessDetectionError: \(error.diagnosticName)", nil)
        case let error as AmplifyError:
            return ("\(type(of: error)): \(error.errorDescription)", error.underlyingError)
        case let error as EncodingError:
            switch error {
            case .invalidValue(_, let context):
                return ("EncodingError: \(context.debugDescription)", context.underlyingError)
            @unknown default:
                return ("EncodingError: \(error.localizedDescription)", nil)
            }
        default:
            let error = error as NSError
            return ("\(error.domain)(\(error.code)): \(error.localizedDescription)", error.userInfo[NSUnderlyingErrorKey] as? Error)
        }
    }

    /// A pixel format's four-character code, such as `BGRA`.
    static func fourCharCode(_ code: OSType) -> String {
        let bytes = [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: code >> $0) }
        guard bytes.allSatisfy({ (0x20...0x7E).contains($0) }) else { return "UNKNOWN(\(code))" }
        return String(decoding: bytes, as: UTF8.self)
    }

    static func codecName(_ codec: Any?) -> String {
        switch (codec as? AVVideoCodecType)?.rawValue ?? codec as? String {
        case AVVideoCodecType.h264.rawValue: return "H264"
        case AVVideoCodecType.hevc.rawValue: return "HEVC"
        case let other?: return other
        case nil: return "Unknown"
        }
    }
}

extension LivenessStateMachine.LivenessError {
    var diagnosticName: String {
        switch self {
        case .unknown: return "unknown"
        case .missingVideoPermission: return "missingVideoPermission"
        case .errorWithUnderlyingOSFramework: return "errorWithUnderlyingOSFramework"
        case .userCancelled: return "userCancelled"
        case .timedOut: return "timedOut"
        case .couldNotOpenStream: return "couldNotOpenStream"
        case .socketClosed: return "socketClosed"
        case .viewResignation: return "viewResignation"
        case .cameraNotAvailable: return "cameraNotAvailable"
        default: return "code\(code)"
        }
    }

    /// Named as Android names it, plus the codes only iOS sends.
    var diagnosticCloseCode: String {
        // the server already closed the socket, so the normal closure sent afterwards isn't why it ended
        guard self != .socketClosed, let closeCode = webSocketCloseCode else { return "RUNTIME_ERROR" }
        switch closeCode.rawValue {
        case 1000: return "NORMAL"
        case 4001: return "TIMEOUT"
        case 4002: return "TIMEOUT_NO_FACE"
        case 4003: return "CANCELED"
        case 4004: return "VIEW_CLOSURE"
        case 4005: return "RUNTIME_ERROR"
        case 4006: return "MISSING_VIDEO_PERMISSION"
        default: return "CODE_\(closeCode.rawValue)"
        }
    }
}

extension FaceLivenessDetectionError {
    var diagnosticName: String {
        switch self {
        case .unknown: return "unknown"
        case .sessionNotFound: return "sessionNotFound"
        case .sessionTimedOut: return "sessionTimedOut"
        case .faceInOvalMatchExceededTimeLimitError: return "faceInOvalMatchExceededTimeLimitError"
        case .accessDenied: return "accessDenied"
        case .cameraPermissionDenied: return "cameraPermissionDenied"
        case .userCancelled: return "userCancelled"
        case .socketClosed: return "socketClosed"
        case .countdownFaceTooClose: return "countdownFaceTooClose"
        case .countdownMultipleFaces: return "countdownMultipleFaces"
        case .countdownNoFace: return "countdownNoFace"
        case .invalidRegion: return "invalidRegion"
        case .validation: return "validation"
        case .internalServer: return "internalServer"
        case .throttling: return "throttling"
        case .serviceQuotaExceeded: return "serviceQuotaExceeded"
        case .serviceUnavailable: return "serviceUnavailable"
        case .invalidSignature: return "invalidSignature"
        case .cameraNotAvailable: return "cameraNotAvailable"
        case .sessionInterrupted: return "sessionInterrupted"
        default: return "code\(code)"
        }
    }
}

extension FaceLivenessSessionError {
    var diagnosticName: String {
        switch self {
        case .unknown: return "unknown"
        case .validation: return "validation"
        case .internalServer: return "internalServer"
        case .throttling: return "throttling"
        case .serviceQuotaExceeded: return "serviceQuotaExceeded"
        case .serviceUnavailable: return "serviceUnavailable"
        case .sessionNotFound: return "sessionNotFound"
        case .accessDenied: return "accessDenied"
        case .invalidRegion: return "invalidRegion"
        case .invalidURL: return "invalidURL"
        case .invalidSignature: return "invalidSignature"
        default: return "code\(code)"
        }
    }
}

extension LivenessCaptureSessionError {
    var diagnosticName: String {
        switch self {
        case .deviceInputUnavailable: return "deviceInputUnavailable"
        case .cameraUnavailable: return "cameraUnavailable"
        case .captureSessionUnavailable: return "captureSessionUnavailable"
        case .captureSessionInputUnavailable: return "captureSessionInputUnavailable"
        case .captureSessionOutputUnavailable: return "captureSessionOutputUnavailable"
        default: return "code\(code)"
        }
    }
}

extension LivenessStateMachine.State {
    var diagnosticName: String {
        switch self {
        case .initial: return "initial"
        case .awaitingChallengeType: return "awaitingChallengeType"
        case .pendingFacePreparedConfirmation(let reason): return "pendingFacePreparedConfirmation.\(reason)"
        case .recording(let ovalDisplayed): return ovalDisplayed ? "recording.ovalDisplayed" : "recording"
        case .awaitingFaceInOvalMatch(let reason, _): return "awaitingFaceInOvalMatch.\(reason)"
        case .faceMatched: return "faceMatched"
        case .initialClientInfoEventSent: return "initialClientInfoEventSent"
        case .displayingFreshness: return "displayingFreshness"
        case .completedDisplayingFreshness: return "completedDisplayingFreshness"
        case .completedNoLightCheck: return "completedNoLightCheck"
        case .completed: return "completed"
        case .awaitingDisconnectEvent: return "awaitingDisconnectEvent"
        case .disconnectEventReceived: return "disconnectEventReceived"
        case .encounteredUnrecoverableError(let error): return "encounteredUnrecoverableError.\(error.diagnosticName)"
        case .waitForRecording: return "waitForRecording"
        }
    }

    /// Whether the face has been found close enough to start the check.
    var hasPassedPreCheck: Bool {
        switch self {
        case .initial, .awaitingChallengeType, .pendingFacePreparedConfirmation:
            return false
        default:
            return true
        }
    }
}
