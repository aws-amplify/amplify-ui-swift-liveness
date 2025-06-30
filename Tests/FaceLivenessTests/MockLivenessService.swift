//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
@testable import FaceLiveness
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

class MockLivenessService {

    var interactions: [String] = []

    var onInitialClientEvent: (LivenessEvent<InitialClientEvent>, Date) -> Void = { _, _ in }
    var onFaceDetectionEvent: (LivenessEvent<FaceDetection>, Date) -> Void = { _, _ in }
    var onFinalClientEvent: (LivenessEvent<FinalClientEvent>, Date) -> Void = { _, _ in }
    var onFreshnessEvent: (LivenessEvent<FreshnessEvent>, Date) -> Void = { _, _ in }
    var onVideoEvent: (LivenessEvent<VideoEvent>, Date) -> Void = { _, _ in }
    var onInitializeLivenessStream: (String, String,[Challenge]?,FaceLivenessSession.Options) -> Void = { _, _, _, _ in }
    var onServiceException: (FaceLivenessSessionError) -> Void = { _ in }
    var onCloseSocket: (URLSessionWebSocketTask.CloseCode) -> Void = { _ in }
}

extension MockLivenessService: LivenessService {

    func send<T>(_ event: LivenessEvent<T>, eventDate: () -> Date) {
        interactions.append(#function)

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
        withSessionID sessionID: String, 
        userAgent: String,
        challenges: [Challenge],
        options: FaceLivenessSession.Options
    ) throws {
        interactions.append(#function)
        onInitializeLivenessStream(sessionID, userAgent, challenges, options)
    }

    func register(
        onComplete: @escaping (ServerDisconnection) -> Void
    ) {
        interactions.append(#function)
    }

    func register(
        listener: @escaping (FaceLivenessSession.SessionConfiguration) -> Void,
        on event: LivenessEventKind.Server
    ) {
        interactions.append(#function)
    }
    
    func register(listener: @escaping (Challenge) -> Void, on event: LivenessEventKind.Server) {
        interactions.append(#function)
    }

    func closeSocket(with code: URLSessionWebSocketTask.CloseCode) {
        interactions.append(#function)
        onCloseSocket(code)
    }
}
