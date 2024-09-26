//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SwiftUI
import AVFoundation
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

fileprivate let videoSize: CGSize = .init(width: 480, height: 640)
fileprivate let defaultNoFitTimeoutInterval: TimeInterval = 7
fileprivate let defaultAttemptCountResetInterval: TimeInterval = 300.0

@MainActor
class FaceLivenessDetectionViewModel: ObservableObject {
    @Published var readyForOval = false
    @Published var isRecording = false
    @Published var livenessState: LivenessStateMachine

    weak var livenessViewControllerDelegate: FaceLivenessViewControllerPresenter?
    var captureSession: LivenessCaptureSession?
    var closeButtonAction: () -> Void
    let videoChunker: VideoChunker
    let sessionID: String
    var livenessService: LivenessService?
    let faceDetector: FaceDetector
    let faceInOvalMatching: FaceInOvalMatching
    let challengeID: String = UUID().uuidString
    let isPreviewScreenEnabled : Bool
    var colorSequences: [ColorSequence] = []
    var hasSentFinalVideoEvent = false
    var hasSentFirstVideo = false
    var layerRectConverted: (CGRect) -> CGRect = { $0 }
    var sessionConfiguration: FaceLivenessSession.SessionConfiguration?
    var challengeReceived: Challenge?
    var normalizeFace: (DetectedFace) -> DetectedFace = { $0 }
    var provideSingleFrame: ((UIImage) -> Void)?
    var cameraViewRect = CGRect.zero
    var ovalRect = CGRect.zero
    var faceGuideRect: CGRect!
    var initialClientEvent: InitialClientEvent?
    var faceMatchedTimestamp: UInt64?
    var noFitStartTime: Date?
    let challengeOptions: ChallengeOptions
    
    static var attemptCount: Int = 0
    static var attemptIdTimeStamp: Date = Date()
    
    var noFitTimeoutInterval: TimeInterval {
        if let sessionTimeoutMilliSec = sessionConfiguration?.ovalMatchChallenge.oval.ovalFitTimeout {
            return TimeInterval(sessionTimeoutMilliSec/1_000)
        } else {
            return defaultNoFitTimeoutInterval
        }
    }
    
    init(
        faceDetector: FaceDetector,
        faceInOvalMatching: FaceInOvalMatching,
        videoChunker: VideoChunker,
        stateMachine: LivenessStateMachine = .init(state: .initial),
        closeButtonAction: @escaping () -> Void,
        sessionID: String,
        isPreviewScreenEnabled: Bool,
        challengeOptions: ChallengeOptions
    ) {
        self.closeButtonAction = closeButtonAction
        self.videoChunker = videoChunker
        self.livenessState = stateMachine
        self.sessionID = sessionID
        self.faceDetector = faceDetector
        self.faceInOvalMatching = faceInOvalMatching
        self.isPreviewScreenEnabled = isPreviewScreenEnabled
        self.challengeOptions = challengeOptions

        self.closeButtonAction = { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                self.stopRecording()
                self.livenessState.unrecoverableStateEncountered(.userCancelled)
            }
        }

        faceDetector.setResultHandler(detectionResultHandler: self)
        videoChunker.assetWriterDelegate.set(segmentProcessor: self)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willResignActive),
            name: UIScene.willDeactivateNotification, object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func registerServiceEvents(onChallengeTypeReceived: @escaping (Challenge) -> Void) {
        livenessService?.register(onComplete: { [weak self] reason in
            self?.stopRecording()

            switch reason {
            case .disconnectionEvent:
                DispatchQueue.main.async {
                    self?.livenessState.complete()
                }
            case .unexpectedClosure:
                DispatchQueue.main.async {
                    self?.livenessState
                        .unrecoverableStateEncountered(.socketClosed)
                }
            }
        })

        livenessService?.register(
            listener: { [weak self] _sessionConfiguration in
                self?.sessionConfiguration = _sessionConfiguration
            },
            on: .challenge
        )
        
        livenessService?.register(
            listener: { [weak self] _challenge in
                self?.challengeReceived = _challenge
                self?.configureCaptureSession(challenge: _challenge)
                onChallengeTypeReceived(_challenge)
            },
            on: .challenge)
    }

    @objc func willResignActive(_ notification: Notification) {
        guard self.livenessState.state != .initial else { return }
        DispatchQueue.main.async {
            self.stopRecording()
            self.livenessState.unrecoverableStateEncountered(.viewResignation)
        }
    }

    func startSession() {
        captureSession?.startSession()
    }

    func stopRecording() {
        captureSession?.stopRunning()
    }

    func configureCamera(withinFrame frame: CGRect) -> CALayer? {
        do {
            let avLayer = try captureSession?.configureCamera(frame: frame)
            DispatchQueue.main.async {
                self.livenessState.checkIsFacePrepared()
            }
            return avLayer
        } catch {
            DispatchQueue.main.async {
                self.livenessState.unrecoverableStateEncountered(
                    self.generateLivenessError(from: error)
                )
            }
            return nil
        }
    }

    func drawOval(onComplete: @escaping () -> Void) {
        guard livenessState.state == .recording(ovalDisplayed: false),
              let ovalParameters = sessionConfiguration?.ovalMatchChallenge.oval
        else { return }

        let scaleRatio = cameraViewRect.width / videoSize.width
        let rect = CGRect(
            x: ovalParameters.boundingBox.x,
            y: ovalParameters.boundingBox.y,
            width: ovalParameters.boundingBox.width,
            height: ovalParameters.boundingBox.height
        )

        let normalizedOvalRect = CGRect(
            x: rect.minX * scaleRatio,
            y: rect.minY * scaleRatio,
            width: rect.width * scaleRatio,
            height: rect.height * scaleRatio
        )

        livenessViewControllerDelegate?.drawOvalInCanvas(normalizedOvalRect)
        DispatchQueue.main.async {
            self.livenessState.ovalDisplayed()
            onComplete()
        }
        ovalRect = normalizedOvalRect
    }


    func initializeLivenessStream() {
        do {
            if (abs(Self.attemptIdTimeStamp.timeIntervalSinceNow) > defaultAttemptCountResetInterval) {
                Self.attemptCount = 1
            } else {
                Self.attemptCount += 1
            }
            Self.attemptIdTimeStamp = Date()
            
            try livenessService?.initializeLivenessStream(
                withSessionID: sessionID,
                userAgent: UserAgentValues.standard().userAgentString,
                challenges: [challengeOptions.faceMovementChallengeOption.challenge,
                             challengeOptions.faceMovementAndLightChallengeOption.challenge],
                options: .init(
                    attemptCount: Self.attemptCount,
                    preCheckViewEnabled: isPreviewScreenEnabled)
            )
        } catch {
            DispatchQueue.main.async {
                self.livenessState.unrecoverableStateEncountered(.couldNotOpenStream)
            }
        }
    }

    func sendColorDisplayedEvent(
        _ event: Freshness.ColorEvent
    ) {
        let freshnessEvent = FreshnessEvent(
            challengeID: challengeID,
            color: event.currentColor.rgb._values,
            sequenceNumber: event.sequenceNumber,
            timestamp: event.colorStartTime,
            previousColor: event.previousColor.rgb._values
        )

        do {
            try livenessService?.send(
                .freshness(event: freshnessEvent),
                eventDate: { .init() }
            )
        } catch {
            DispatchQueue.main.async {
                self.livenessState.unrecoverableStateEncountered(.unknown)
            }
        }
    }

    func boundingBox(for cgRect: CGRect, relativeTo canvas: CGRect) -> FaceLivenessSession.BoundingBox {
        .init(
            x: cgRect.minX / cameraViewRect.width,
            y: cgRect.minY / cameraViewRect.height,
            width: cgRect.width / cameraViewRect.width,
            height: cgRect.height / cameraViewRect.height
        )
    }

    func sendInitialFaceDetectedEvent(
        initialFace: CGRect,
        videoStartTime: UInt64
    ) {
        guard initialClientEvent == nil else { return }
        guard let challengeReceived else { return }
        
        videoChunker.start()

        let initialFace = FaceDetection(
            boundingBox: boundingBox(for: initialFace, relativeTo: cameraViewRect),
            startTimestamp: videoStartTime
        )

        let _initialClientEvent = InitialClientEvent(
            challengeID: challengeID,
            initialFaceLocation: initialFace,
            videoStartTime: videoStartTime
        )

        initialClientEvent = _initialClientEvent

        do {
            try livenessService?.send(
                .initialFaceDetected(event: _initialClientEvent, 
                                     challenge: .init(version: challengeReceived.version,
                                                      type: challengeReceived.type)),
                eventDate: { .init() }
            )
        } catch {
            DispatchQueue.main.async {
                self.livenessState.unrecoverableStateEncountered(.unknown)
            }
        }
    }

    func sendFinalEvent(
        targetFaceRect: CGRect,
        viewSize: CGSize,
        faceMatchedEnd: UInt64
    ) {
        guard
            let sessionConfiguration,
            let initialClientEvent,
            let faceMatchedTimestamp,
            let challengeReceived
        else { return }

        let finalClientEvent = FinalClientEvent(
            sessionConfiguration: sessionConfiguration,
            initialClientEvent: initialClientEvent,
            videoSize: videoSize,
            faceMatchedStart: faceMatchedTimestamp,
            faceMatchedEnd: faceMatchedEnd,
            videoEnd: Date().timestampMilliseconds
        )

        do {
            try livenessService?.send(
                .final(event: finalClientEvent,
                       challenge: .init(version: challengeReceived.version,
                                            type: challengeReceived.type)),
                eventDate: { .init() }
            )

            sendVideoEvent(
                data: .init(),
                videoEventTime: Date().timestampMilliseconds
            )
            hasSentFinalVideoEvent = true

        } catch {
            DispatchQueue.main.async {
                self.livenessState.unrecoverableStateEncountered(.unknown)
            }
        }
    }

    func sendFinalVideoEvent() {
        sendFinalEvent(
            targetFaceRect: faceGuideRect,
            viewSize: videoSize,
            faceMatchedEnd: Date().timestampMilliseconds
        )

        videoChunker.finish { [weak livenessViewControllerDelegate] image in
            livenessViewControllerDelegate?.displaySingleFrame(uiImage: image)
        }
    }

    func handleFreshnessComplete(faceGuide: CGRect) {
        DispatchQueue.main.async {
            self.livenessState.completedDisplayingFreshness()
            self.faceGuideRect = faceGuide
        }
    }
    
    func completeNoLightCheck(faceGuide: CGRect) {
        DispatchQueue.main.async {
            self.livenessState.completedNoLightCheck()
            self.faceGuideRect = faceGuide
        }
    }

    func sendVideoEvent(data: Data, videoEventTime: UInt64) {
        guard !hasSentFinalVideoEvent else { return }
        let eventDate = Date()
        let timestamp = eventDate.timestampMilliseconds

        let videoEvent = VideoEvent.init(chunk: data, timestamp: timestamp)

        do {
            try livenessService?.send(
                .video(event: videoEvent),
                eventDate: { eventDate }
            )
        } catch {
            DispatchQueue.main.async {
                self.livenessState.unrecoverableStateEncountered(.unknown)
            }
        }
    }

    private func generateLivenessError(from captureSessionError: Error) -> LivenessStateMachine.LivenessError {
        guard let captureSessionError = captureSessionError as? LivenessCaptureSessionError else { return .unknown }

        let livenessError: LivenessStateMachine.LivenessError

        switch captureSessionError {
        case LivenessCaptureSessionError.cameraUnavailable,
            LivenessCaptureSessionError.deviceInputUnavailable:
            let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
            livenessError = authStatus == .authorized ? .cameraNotAvailable : .missingVideoPermission
        case LivenessCaptureSessionError.captureSessionOutputUnavailable,
            LivenessCaptureSessionError.captureSessionInputUnavailable:

            livenessError = .errorWithUnderlyingOSFramework
        default:
            livenessError = .unknown
        }

        return livenessError
    }

    func chunk(initial: Data, current: Data) -> Data {
        let data: Data
        if hasSentFirstVideo {
            data = current
        } else {
            data = initial + current
            hasSentFirstVideo = true
        }
        return data
    }
    
    func configureCaptureSession(challenge: Challenge) {
        let cameraPosition: LivenessCamera
        switch challenge.type {
        case .faceMovementChallenge:
            cameraPosition = challengeOptions.faceMovementChallengeOption.camera
        case .faceMovementAndLightChallenge:
            cameraPosition = challengeOptions.faceMovementAndLightChallengeOption.camera
        }
        
        let avCaptureDevice = AVCaptureDevice.default(
                                .builtInWideAngleCamera,
                                for: .video,
                                position: cameraPosition == .front ? .front : .back)

        self.captureSession = LivenessCaptureSession(
            captureDevice: .init(avCaptureDevice: avCaptureDevice),
            outputDelegate: OutputSampleBufferCapturer(
                faceDetector: self.faceDetector,
                videoChunker: self.videoChunker
            )
        )
    }
}

extension FaceLivenessDetectionViewModel: FaceDetectionSessionConfigurationWrapper { }
