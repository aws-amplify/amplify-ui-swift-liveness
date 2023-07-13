//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SwiftUI
import AVFoundation
import Amplify
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

fileprivate let videoSize: CGSize = .init(width: 480, height: 640)

@MainActor
class FaceLivenessDetectionViewModel: ObservableObject {
    @Published var readyForOval = false
    @Published var isRecording = false
    @Published var livenessState: LivenessStateMachine

    weak var livenessViewControllerDelegate: FaceLivenessViewControllerPresenter?
    let captureSession: LivenessCaptureSession
    var closeButtonAction: () -> Void
    let videoChunker: VideoChunker
    let sessionID: String
    var livenessService: LivenessService!
    let faceDetector: FaceDetector
    let faceInOvalMatching: FaceInOvalMatching
    let challengeID: String = UUID().uuidString
    var colorSequences: [ColorSequence] = []
    var hasSentFinalVideoEvent = false
    var hasSentFirstVideo = false
    var layerRectConverted: (CGRect) -> CGRect = { $0 }
    var sessionConfiguration: FaceLivenessSession.SessionConfiguration?
    var normalizeFace: (DetectedFace) -> DetectedFace = { $0 }
    var provideSingleFrame: ((UIImage) -> Void)?
    var cameraViewRect = CGRect.zero
    var ovalRect = CGRect.zero
    var faceGuideRect: CGRect!
    var initialClientEvent: InitialClientEvent?
    var faceMatchedTimestamp: UInt64?
    var noMatchCount = 0
    let log = Amplify.Logging.logger(forCategory: "AmplifyUISwiftLiveness")

    init(
        faceDetector: FaceDetector,
        faceInOvalMatching: FaceInOvalMatching,
        captureSession: LivenessCaptureSession,
        videoChunker: VideoChunker,
        stateMachine: LivenessStateMachine = .init(state: .initial),
        closeButtonAction: @escaping () -> Void,
        sessionID: String
    ) {
        self.closeButtonAction = closeButtonAction
        self.videoChunker = videoChunker
        self.livenessState = stateMachine
        self.sessionID = sessionID
        self.captureSession = captureSession
        self.faceDetector = faceDetector
        self.faceInOvalMatching = faceInOvalMatching

        self.closeButtonAction = { [weak self] in
            guard let self else { return }
            Task {
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

    func registerServiceEvents() {
        livenessService.register(onComplete: { [weak self] reason in
            guard let self else { return }
            self.stopRecording()

            switch reason {
            case .disconnectionEvent:
                Task { self.livenessState.complete() }
                self.log.info("Received disconnect event - liveness flow complete")
            case .unexpectedClosure:
                Task {
                    self.livenessState
                    .unrecoverableStateEncountered(.socketClosed)
                }
                self.log.error("Encountered unexpected socket connection closure")
            }
        })

        livenessService.register(
            listener: { [weak self] sessionConfiguration in
                self?.sessionConfiguration = sessionConfiguration
            },
            on: .challenge
        )
    }

    @objc func willResignActive(_ notification: Notification) {
        Task {
            self.stopRecording()
            self.livenessState.unrecoverableStateEncountered(.socketClosed)
        }
    }

    func stopRecording() {
        log.verbose("completed recording")
        captureSession.stopRunning()
    }

    func startCamera(withinFrame frame: CGRect) -> CALayer? {
        log.verbose("starting camera within frame: \(frame)")
        do {
            let avLayer = try captureSession.startSession(frame: frame)
            Task {
                self.livenessState.checkIsFacePrepared()
            }
            return avLayer
        } catch {
            log.error("Camera session failed to start - unable to continue")
            Task {
                self.livenessState.unrecoverableStateEncountered(
                    self.generateLivenessError(from: error)
                )
            }
            return nil
        }
    }

    func drawOval(onComplete: @escaping () -> Void) {
        log.verbose("drawing oval on screen")
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
        self.log.verbose("oval displayed on screen")
        Task {
            self.livenessState.ovalDisplayed()
            onComplete()
        }
        ovalRect = normalizedOvalRect
    }


    func initializeLivenessStream() {
        log.verbose("initialized liveness stream")
        do {
            try livenessService.initializeLivenessStream(
                withSessionID: sessionID,
                userAgent: UserAgentValues.standard().userAgentString
            )
        } catch {
            log.error("unable to create connection with liveness service. \(error)")
            Task {
                self.livenessState.unrecoverableStateEncountered(.couldNotOpenStream)
            }
        }
    }

    func sendColorDisplayedEvent(
        _ event: Freshness.ColorEvent
    ) {
        log.verbose("sending color displayed event for color: \(event.currentColor.rgb)")

        let freshnessEvent = FreshnessEvent(
            challengeID: challengeID,
            color: event.currentColor.rgb._values,
            sequenceNumber: event.sequenceNumber,
            timestamp: event.colorStartTime,
            previousColor: event.previousColor.rgb._values
        )

        do {
            try livenessService.send(
                .freshness(event: freshnessEvent),
                eventDate: { .init() }
            )
        } catch {
            log.error("encountered error sending color event: \(error)")
            Task {
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
        log.verbose(#function)
        guard initialClientEvent == nil else { return }
        log.verbose("starting video chunking")
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

        log.verbose("sending initial face detected event")
        do {
            try livenessService.send(
                .initialFaceDetected(event: _initialClientEvent),
                eventDate: { .init() }
            )
        } catch {
            log.error("encountered error sending initial face detected event: \(error)")
            Task {
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
            let faceMatchedTimestamp
        else { return }

        let finalClientEvent = FinalClientEvent(
            sessionConfiguration: sessionConfiguration,
            initialClientEvent: initialClientEvent,
            videoSize: videoSize,
            faceMatchedStart: faceMatchedTimestamp,
            faceMatchedEnd: faceMatchedEnd,
            videoEnd: Date().timestampMilliseconds
        )

        log.verbose("sending final client event: \(finalClientEvent)")
        do {
            try livenessService.send(
                .final(event: finalClientEvent),
                eventDate: { .init() }
            )

            log.verbose("sent final client event - sending empty video event")
            sendVideoEvent(
                data: .init(),
                videoEventTime: Date().timestampMilliseconds
            )
            log.verbose("sent empty video event")
            hasSentFinalVideoEvent = true

        } catch {
            Task {
                self.livenessState.unrecoverableStateEncountered(.unknown)
            }
        }
    }

    func sendVideoEvent(data: Data, videoEventTime: UInt64, n: UInt8 = 1) {
        guard !hasSentFinalVideoEvent else { return }
        log.verbose("sending video event of size: \(data.count) and timestamp: \(videoEventTime)")
        let eventDate = Date()
        let timestamp = eventDate.timestampMilliseconds

        let videoEvent = VideoEvent.init(chunk: data, timestamp: timestamp)

        do {
            try livenessService.send(
                .video(event: videoEvent),
                eventDate: { eventDate }
            )
        } catch {
            log.error("encountered error sending video event: \(error)")
            Task {
                self.livenessState.unrecoverableStateEncountered(.unknown)
            }
        }
    }

    func sendFinalVideoChunk(data: Data, videoEventTime: UInt64) {
        log.verbose("Sending final video chunk")
        sendVideoEvent(data: data, videoEventTime: videoEventTime)
        sendFinalEvent(
            targetFaceRect: faceGuideRect,
            viewSize: videoSize,
            faceMatchedEnd: Date().timestampMilliseconds
        )

        videoChunker.finish { [weak livenessViewControllerDelegate, log] image in
            log.verbose("Video chunker finished")
            Task {
                livenessViewControllerDelegate?.displaySingleFrame(uiImage: image)
            }
        }
    }

    func handleFreshnessComplete(faceGuide: CGRect) {
        log.verbose("completed color display")
        Task {
            self.livenessState.completedDisplayingFreshness()
            self.faceGuideRect = faceGuide
        }
    }

    func sendVideoEvent(data: Data, videoEventTime: UInt64) {
        guard !hasSentFinalVideoEvent else { return }
        let eventDate = Date()
        let timestamp = eventDate.timestampMilliseconds

        let videoEvent = VideoEvent.init(chunk: data, timestamp: timestamp)

        do {
            try livenessService.send(
                .video(event: videoEvent),
                eventDate: { eventDate }
            )
        } catch {
            Task {
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

            livenessError = .missingVideoPermission
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
}
