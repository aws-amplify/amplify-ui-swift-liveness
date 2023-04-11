//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
@testable import FaceLiveness
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

class MockLivenessService: LivenessService {
    var onInitialClientEvent: (LivenessEvent<InitialClientEvent>, Date) -> Void = { _, _ in }
    var onFaceDetectionEvent: (LivenessEvent<FaceDetection>, Date) -> Void = { _, _ in }
    var onFinalClientEvent: (LivenessEvent<FinalClientEvent>, Date) -> Void = { _, _ in }
    var onFreshnessEvent: (LivenessEvent<FreshnessEvent>, Date) -> Void = { _, _ in }
    var onVideoEvent: (LivenessEvent<VideoEvent>, Date) -> Void = { _, _ in }
    var onInitializeLivenessStream: (String, String) -> Void = { _, _ in }

    func send<T>(_ event: LivenessEvent<T>, eventDate: () -> Date) {
        switch event {
        case let initialClient as LivenessEvent<InitialClientEvent>:
            onInitialClientEvent(initialClient, eventDate())
        case let faceDetection as LivenessEvent<FaceDetection>:
            onFaceDetectionEvent(faceDetection, eventDate())
        case let finalClient as LivenessEvent<FinalClientEvent>:
            onFinalClientEvent(finalClient, eventDate())
        case let freshness as LivenessEvent<FreshnessEvent>:
            onFreshnessEvent(freshness, eventDate())
        case let video as LivenessEvent<VideoEvent>:
            onVideoEvent(video, eventDate())
        default: break
        }
    }

    func initializeLivenessStream(
        withSessionID sessionID: String, userAgent: String
    ) throws {
        onInitializeLivenessStream(sessionID, userAgent)
    }

    func register(
        onComplete: @escaping (ServerDisconnection) -> Void
    ) {}

    func register(
        listener: @escaping (FaceLivenessSession.SessionConfiguration) -> Void,
        on event: LivenessEventKind.Server
    ) {}
}
