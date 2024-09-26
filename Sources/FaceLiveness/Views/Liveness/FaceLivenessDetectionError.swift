//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

public struct FaceLivenessDetectionError: Error, Equatable {
    let code: UInt8
    public let message: String
    public let recoverySuggestion: String

    public static let unknown = FaceLivenessDetectionError(
        code: 0,
        message: "An unknown error occurred.",
        recoverySuggestion: "Please open an issue...."
    )

    public static let sessionNotFound = FaceLivenessDetectionError(
        code: 1,
        message: "Session not found.",
        recoverySuggestion: "Enter a valid session ID."
    )

    public static let sessionTimedOut = FaceLivenessDetectionError(
        code: 2,
        message: "Session timed out. Did not receive final response from server within time limit.",
        recoverySuggestion: "Try again."
    )

    public static let faceInOvalMatchExceededTimeLimitError = FaceLivenessDetectionError(
        code: 3,
        message: "Face did not match oval within time limit.",
        recoverySuggestion: "Retry the face liveness check and prompt the user to follow the on screen instructions."
    )

    public static let accessDenied = FaceLivenessDetectionError(
        code: 4,
        message: "Not authorized to perform a face liveness check.",
        recoverySuggestion: "Valid credentials are required for the face liveness check."
    )

    public static let cameraPermissionDenied = FaceLivenessDetectionError(
        code: 5,
        message: "Camera permissions have not been granted.",
        recoverySuggestion: "Prompt the user to grant camera permission."
    )

    public static let userCancelled = FaceLivenessDetectionError(
        code: 6,
        message: "User cancelled the face liveness check.",
        recoverySuggestion: "Retry the face liveness check."
    )

    public static let socketClosed = FaceLivenessDetectionError(
        code: 7,
        message: "Websocket connection unexpectedly closed",
        recoverySuggestion: ""
    )

    public static let countdownFaceTooClose = FaceLivenessDetectionError(
        code: 8,
        message: "Check failed during countdown.",
        recoverySuggestion: "User should not move closer during the countdown."
    )

    public static let countdownMultipleFaces = FaceLivenessDetectionError(
        code: 9,
        message: "Check failed during countdown.",
        recoverySuggestion: "Multiple faces detected during the countdown."
    )

    public static let countdownNoFace = FaceLivenessDetectionError(
        code: 10,
        message: "Check failed during countdown.",
        recoverySuggestion: "No face detected during the countdown."
    )

    public static let invalidRegion = FaceLivenessDetectionError(
        code: 11,
        message: "The region provided is invalid.",
        recoverySuggestion: "Confirm that you are using a valid `region` and try again."
    )

    public static let validation = FaceLivenessDetectionError(
        code: 12,
        message: "The input fails to satisfy the constraints specified by the service.",
        recoverySuggestion: """
        Retry the face liveness check and prompt the user to follow the on screen instructions.
        """
    )

    public static let internalServer = FaceLivenessDetectionError(
        code: 13,
        message: "Unexpected error during processing of request.",
        recoverySuggestion: ""
    )

    public static let throttling = FaceLivenessDetectionError(
        code: 14,
        message: "A request was denied due to request throttling.",
        recoverySuggestion: """
        Occurs when too many requests were made by a user (exceeding their service quota),
        the service isn't able to scale, or a service-wide throttling was done to
        recover from an operational event.
        """
    )

    public static let serviceQuotaExceeded = FaceLivenessDetectionError(
        code: 15,
        message: "Occurs when a request would cause a service quota to be exceeded.",
        recoverySuggestion: ""
    )

    public static let serviceUnavailable = FaceLivenessDetectionError(
        code: 16,
        message: "Service-wide throttling to recover from an operational event or service is not able to scale.",
        recoverySuggestion: ""
    )

    public static let invalidSignature = FaceLivenessDetectionError(
        code: 17,
        message: "The signature on the request is invalid.",
        recoverySuggestion: "Ensure the device time is correct and try again."
    )
    
    public static let cameraNotAvailable = FaceLivenessDetectionError(
        code: 18,
        message: "The camera is not available.",
        recoverySuggestion: "There might be a hardware issue."
    )

    public static func == (lhs: FaceLivenessDetectionError, rhs: FaceLivenessDetectionError) -> Bool {
        lhs.code == rhs.code
    }
}
