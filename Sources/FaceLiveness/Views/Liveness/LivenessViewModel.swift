////
//// Copyright Amazon.com Inc. or its affiliates.
//// All Rights Reserved.
////
//// SPDX-License-Identifier: Apache-2.0
////
//
//import Foundation
//import AVFoundation
//import UIKit
//@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin
//
//import Amplify
//
//extension LivenessViewModel: FaceDetectionResultHandler {
//    func process(newResult: FaceDetectionResult) {
//        switch newResult {
//        case .noFace:
//            if case .pendingFacePreparedConfirmation = faceLivenessDetectionViewModel.livenessState.state {
//                DispatchQueue.main.async {
//                    try? self.faceLivenessDetectionViewModel.livenessState.faceNotPrepared(reason: .noFace)
//                }
//            }
//        case .multipleFaces:
//            if case .pendingFacePreparedConfirmation = faceLivenessDetectionViewModel.livenessState.state {
//                DispatchQueue.main.async {
//                    try? self.faceLivenessDetectionViewModel.livenessState.faceNotPrepared(reason: .multipleFaces)
//                }
//            }
//        case .singleFace(let face):
//            var normalizedFace = normalizeFace(face)
//            normalizedFace.boundingBox = normalizedFace.boundingBoxFromLandmarks()
//
//            if !hasCompletedInitialFaceDistanceCheck {
//                let af = face.faceDistance
//                if af <= initialFaceDistanceThreshold {
//                    hasCompletedInitialFaceDistanceCheck = true
//                } else {
//                    DispatchQueue.main.async {
//                        try? self.faceLivenessDetectionViewModel.livenessState
//                            .faceNotPrepared(reason: .faceTooClose)
//                    }
//                    return
//                }
//            } else {
//                if case .countingDown = faceLivenessDetectionViewModel.livenessState.state {
//                    let af = face.faceDistance
//                    if af >= 0.37 {
//                        DispatchQueue.main.async {
//                            self.faceLivenessDetectionViewModel.livenessState.unrecoverableStateEncountered(
//                                .invalidFaceMovementDuringCountdown
//                            )
//                        }
//                    }
//               }
//
//                if case .pendingFacePreparedConfirmation = faceLivenessDetectionViewModel.livenessState.state {
//                    DispatchQueue.main.async {
//                        try? self.faceLivenessDetectionViewModel.livenessState.startCountdown()
//                        self.initializeLivenessStream()
//                    }
//                }
//            }
//
//            drawOval()
//
//            guard ovalRect != .zero else { return }
//            guard let sessionConfiguration = sessionConfiguration else { return }
//            let instruction = faceInOvalMatching.faceMatchState(
//                for: normalizedFace.boundingBox,
//                in: ovalRect,
//                challengeConfig: sessionConfiguration.ovalMatchChallenge
//            )
//
//            if case .recording = faceLivenessDetectionViewModel.livenessState.state {
//                if !hasSentClientInfoEvent {
//                    sendInitialFaceDetectedEvent(
//                        initialFace: normalizedFace.boundingBox,
//                        videoStartTime: Date.livenessTimestamp
//                    )
//                }
//
//                DispatchQueue.main.async {
//                    switch instruction {
//                    case .match:
//                        let colorSequences = sessionConfiguration.colorChallenge.colors
//                        self.faceLivenessDetectionViewModel.livenessState.faceMatched()
//                        let generator = UINotificationFeedbackGenerator()
//                        generator.notificationOccurred(.success)
//                        self.faceMatchedTimestamp = Date.livenessTimestamp
//                        self.displayFreshness(colorSequences)
//
//                    case .tooClose(_, let percentage):
//                        self.faceLivenessDetectionViewModel.livenessState
//                            .awaitingFaceMatch(with: .faceTooClose, nearnessPercentage: percentage)
//                    case .tooFar(_, let percentage):
//                        self.faceLivenessDetectionViewModel.livenessState
//                            .awaitingFaceMatch(with: .moveFaceCloser, nearnessPercentage: percentage)
//                    case .tooFarLeft(_, let percentage):
//                        self.faceLivenessDetectionViewModel.livenessState
//                            .awaitingFaceMatch(with: .moveFaceRight, nearnessPercentage: percentage)
//                    case .tooFarRight(_, let percentage):
//                        self.faceLivenessDetectionViewModel.livenessState
//                            .awaitingFaceMatch(with: .moveFaceLeft, nearnessPercentage: percentage)
//                    case .none:
//                        break
//                    }
//                }
//
//            }
//
//            if case .awaitingFaceInOvalMatch = faceLivenessDetectionViewModel.livenessState.state {
//                DispatchQueue.main.async {
//                    switch instruction {
//                    case .match:
//                        let colorSequences = sessionConfiguration.colorChallenge.colors
//                        self.faceLivenessDetectionViewModel.livenessState.faceMatched()
//                        self.faceMatchedTimestamp = Date.livenessTimestamp
//                        self.displayFreshness(colorSequences)
//                        let generator = UINotificationFeedbackGenerator()
//                        generator.notificationOccurred(.success)
//                        self.noMatchCount = 0
//
//                    case .tooClose(_, let percentage):
//                        self.faceLivenessDetectionViewModel.livenessState
//                            .awaitingFaceMatch(with: .faceTooClose, nearnessPercentage: percentage)
//                        self.noMatchCount += 1
//                        if self.noMatchCount >= 210 {
//                            self.faceLivenessDetectionViewModel.livenessState
//                                .unrecoverableStateEncountered(.timedOut)
//                            self.captureSession.stopRunning()
//                            return
//                        }
//                    case .tooFar(_, let percentage):
//                        self.faceLivenessDetectionViewModel.livenessState
//                            .awaitingFaceMatch(with: .moveFaceCloser, nearnessPercentage: percentage)
//                        self.noMatchCount += 1
//                        if self.noMatchCount >= 210 {
//                            self.faceLivenessDetectionViewModel.livenessState
//                                .unrecoverableStateEncountered(.timedOut)
//                            self.captureSession.stopRunning()
//                            return
//                        }
//                    case .tooFarLeft(_, let percentage):
//                        self.faceLivenessDetectionViewModel.livenessState
//                            .awaitingFaceMatch(with: .moveFaceRight, nearnessPercentage: percentage)
//                        self.noMatchCount += 1
//                        if self.noMatchCount >= 210 {
//                            self.faceLivenessDetectionViewModel.livenessState
//                                .unrecoverableStateEncountered(.timedOut)
//                            self.captureSession.stopRunning()
//                            return
//                        }
//                    case .tooFarRight(_, let percentage):
//                        self.faceLivenessDetectionViewModel.livenessState
//                            .awaitingFaceMatch(with: .moveFaceLeft, nearnessPercentage: percentage)
//                        self.noMatchCount += 1
//                        if self.noMatchCount >= 210 {
//                            self.faceLivenessDetectionViewModel.livenessState
//                                .unrecoverableStateEncountered(.timedOut)
//                            self.captureSession.stopRunning()
//                            return
//                        }
//                    default: break
//                    }
//                }
//            }
//        }
//    }
//}
//
//extension LivenessViewModel: VideoSegmentProcessor {
//    func process(initalSegment: Data, currentSeparableSegment: Data) {
//        if hasSentClientInfoEvent {
//            sendVideoChunks(initial: initalSegment, current: currentSeparableSegment)
//            if !hasSentFinalVideoEvent,
//               case .completedDisplayingFreshness = faceLivenessDetectionViewModel.livenessState.state {
//                let chunk = chunk(initial: initalSegment, current: currentSeparableSegment)
//                sendFinalVideoChunk(data: chunk, videoEventTime: .zero)
//            }
//        }
//    }
//
////    func process(data: inout Data, timeStamp: UInt64) {
////        if hasSentClientInfoEvent {
////            sendVideoEvent(data: data, videoEventTime: timeStamp,  n: UInt8(videoCount))
////        }
////
////
////        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
////        let segmentFileName = "fileSequence\(videoCount).mp4"
////        videoCount += 1
////        let fileURL = URL(
////            fileURLWithPath: segmentFileName,
////            isDirectory: false,
////            relativeTo: url
////        )
////        do {
////            try data.write(to: fileURL)
////        } catch {}
////    }
//}
//
//final class LivenessViewModel {
//    // var videoCount = 0
//    //    var drawFaceBox: (DetectedFace) -> Void = { _ in }
//
//    /* <<>> */ let livenessService: LivenessService!
//    /* <<>> */ let faceDetector: FaceDetector
//    /* <<>> */ let faceInOvalMatching: FaceInOvalMatching
//    /* <<>> */ let videoChunker: VideoChunker
//    /* <<>> */ let captureSession: LivenessCaptureSession
//    /* <<>> */ let freshnessChallengeID: String
//    /* <<>> */ let initialFaceDistanceThreshold: CGFloat = 0.32
//    /* <<>> */ let faceLivenessDetectionViewModel: FaceLivenessDetectionViewModel
//
//    /* STATE <<<>>> */ var colorSequences: [ColorSequence] = []
//    /* STATE */ var hasCompletedInitialFaceDistanceCheck = false
//    /* STATE */ var hasSentClientInfoEvent = false
//    /* STATE */ var faceMatchedTimestamp: UInt64?
//    /* STATE */ var noMatchCount = 0
//    /* STATE */ var ovalRect = CGRect.zero
//
//    var layerRectConverted: (CGRect) -> CGRect = { $0 }
//    var normalizeFace: (DetectedFace) -> DetectedFace = { $0 }
//
//    init(
//        faceLivenessDetectionViewModel: FaceLivenessDetectionViewModel,
//        freshnessChallengeID: String = UUID().uuidString
//    ) {
//        self.livenessService = faceLivenessDetectionViewModel.livenessService
//        self.faceDetector = faceLivenessDetectionViewModel.faceDetector
//        self.faceInOvalMatching = faceLivenessDetectionViewModel.faceInOvalMatching
//        self.captureSession = faceLivenessDetectionViewModel.captureSession
//        self.videoChunker = faceLivenessDetectionViewModel.videoChunker
//        self.faceLivenessDetectionViewModel = faceLivenessDetectionViewModel
//        self.freshnessChallengeID = freshnessChallengeID
//
//        faceDetector.setResultHandler(detectionResultHandler: self)
//
//        livenessService.register(onComplete: { [weak self] reason in
//            switch reason {
//            case .disconnectionEvent:
//                self?.captureSession.stopRunning()
//
//                DispatchQueue.main.async {
//                    self?.faceLivenessDetectionViewModel.livenessState.complete()
//                }
//            case .unexpectedClosure:
//                DispatchQueue.main.async {
//                    self?.faceLivenessDetectionViewModel.livenessState
//                        .unrecoverableStateEncountered(.socketClosed)
//                }
//            }
//        })
//
//        livenessService.register(
//            listener: { [weak self] sessionConfiguration in
//                self?.sessionConfiguration = sessionConfiguration
//            },
//            on: .challenge
//        )
//
//        videoChunker.assetWriterDelegate.set(segmentProcessor: self)
////        (videoChunker.assetWriterDelegate as! VideoChunker.AssetWriterDelegate).set(frameProcessor: self)
//
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(willResignActive),
//            name: UIScene.willDeactivateNotification, object: nil
//        )
//    }
//
//    deinit {
//        NotificationCenter.default.removeObserver(self)
//    }
//
//    @objc func willResignActive(_ notification: Notification) {
//        DispatchQueue.main.async {
//            self.faceLivenessDetectionViewModel.stopRecording()
//            self.faceLivenessDetectionViewModel.livenessState.unrecoverableStateEncountered(.socketClosed)
//        }
//    }
//
//    func startCamera(withinFrame frame: CGRect) -> AVCaptureVideoPreviewLayer? {
//        noMatchCount = 0
//        do {
//            let avLayer = try captureSession.startSession(frame: frame)
//            avLayer.frame = frame
//            layerRectConverted = avLayer.layerRectConverted(fromMetadataOutputRect:)
//            DispatchQueue.main.async {
//                try? self.faceLivenessDetectionViewModel.livenessState.checkIsFacePrepared()
//            }
//            return avLayer
//        } catch {
//            DispatchQueue.main.async {
//                self.faceLivenessDetectionViewModel.livenessState.unrecoverableStateEncountered(
//                    self.generateLivenessError(from: error)
//                )
//            }
//            return nil
//        }
//    }
//
//    var sessionConfiguration: FaceLivenessSession.SessionConfiguration?
//    var drawOvalInCanvas: (FaceLivenessSession.OvalMatchChallenge.Oval) -> CGRect? = { _ in nil }
//
//    func drawOval() {
//        guard faceLivenessDetectionViewModel.livenessState.state == .recording(ovalDisplayed: false),
//              let ovalParameters = sessionConfiguration?.ovalMatchChallenge.oval
//        else { return }
//
//        if let ovalRect = drawOvalInCanvas(ovalParameters) {
//            self.ovalRect = ovalRect
//            DispatchQueue.main.async {
//                self.faceLivenessDetectionViewModel.livenessState.ovalDisplayed()
//            }
//        }
//    }
//
//    var displayFreshness: (_ colorSequences: [FaceLivenessSession.DisplayColor]) -> Void = { _ in }
//
//    func initializeLivenessStream() {
//        do {
//            try livenessService.initializeLivenessStream(
//                withSessionID: faceLivenessDetectionViewModel.sessionID,
//                userAgent: UserAgentValues.standard().userAgentString
//            )
//        } catch {
//            DispatchQueue.main.async {
//                self.faceLivenessDetectionViewModel.livenessState.unrecoverableStateEncountered(.couldNotOpenStream)
//            }
//        }
//    }
//
//    func sendColorDisplayedEvent(
//        _ event: Freshness.ColorEvent
//    ) {
//        let freshnessEvent = FreshnessEvent(
//            challengeID: freshnessChallengeID,
//            color: event.currentColor.rgb._values,
//            sequenceNumber: event.sequenceNumber,
//            timestamp: event.colorStartTime,
//            previousColor: event.previousColor.rgb._values
//        )
//
//        do {
//            try livenessService.send(
//                .freshness(
//                    event: freshnessEvent
//                ),
//                eventDate: { .init() }
//            )
//        } catch {
//            DispatchQueue.main.async {
//                self.faceLivenessDetectionViewModel.livenessState.unrecoverableStateEncountered(.unknown)
//            }
//        }
//    }
//
//    var initialFace: FaceDetection?
//    var cameraViewRect = CGRect.zero
//    var videoStartTimeStamp: UInt64?
//
//    var initialClientEvent: InitialClientEvent?
//
//    func boundingBox(for cgRect: CGRect, relativeTo canvas: CGRect) -> FaceLivenessSession.BoundingBox {
//        .init(
//            x: cgRect.minX / cameraViewRect.width,
//            y: cgRect.minY / cameraViewRect.height,
//            width: cgRect.width / cameraViewRect.width,
//            height: cgRect.height / cameraViewRect.height
//        )
//    }
//
//    func sendInitialFaceDetectedEvent(
//        initialFace: CGRect,
//        videoStartTime: UInt64
//    ) {
//        faceLivenessDetectionViewModel.videoChunker.start()
//
//        let initialFace = FaceDetection(
//            boundingBox: boundingBox(for: initialFace, relativeTo: cameraViewRect),
//            startTimestamp: videoStartTime
//        )
//
//        let initialClientEvent = InitialClientEvent(
//            challengeID: freshnessChallengeID,
//            initialFaceLocation: initialFace,
//            videoStartTime: videoStartTime
//        )
//
//        self.initialClientEvent = initialClientEvent
//
//
//        do {
//            try livenessService.send(
//                .initialFaceDetected(event: initialClientEvent),
//                eventDate: { .init() }
//            )
//            hasSentClientInfoEvent = true
//        } catch {
//            DispatchQueue.main.async {
//                self.faceLivenessDetectionViewModel.livenessState.unrecoverableStateEncountered(.unknown)
//            }
//        }
//    }
//
//    func sendFinalEvent(
//        targetFaceRect: CGRect,
//        viewSize: CGSize,
//        faceMatchedEnd: UInt64
//    ) {
//        let height = sessionConfiguration!.ovalMatchChallenge.oval.boundingBox.height
//        let width = sessionConfiguration!.ovalMatchChallenge.oval.boundingBox.width
//        let minX = sessionConfiguration!.ovalMatchChallenge.oval.boundingBox.x
//        let minY = sessionConfiguration!.ovalMatchChallenge.oval.boundingBox.y
//
//        let finalClientEvent = FinalClientEvent(
//            initialClientEvent: initialClientEvent!,
//            targetFace: .init(
//                initialEvent: .init(
//                    boundingBox: .init(
//                        x: Double(minX) / 480,
//                        y: Double(minY) / 640,
//                        width: Double(width) / 480,
//                        height: Double(height) / 640
//                    ),
//                    startTimestamp: faceMatchedTimestamp!
//                ),
//                endTimestamp: faceMatchedEnd
//            ),
//            videoEndTimeStamp: Date.livenessTimestamp
//        )
//
//        do {
//            try livenessService.send(
//                .final(event: finalClientEvent),
//                eventDate: { .init() }
//            )
//
//            sendVideoEvent(
//                data: .init(),
//                videoEventTime: Date.livenessTimestamp
//            )
//            hasSentFinalVideoEvent = true
//            
//        } catch {
//            DispatchQueue.main.async {
//                self.faceLivenessDetectionViewModel.livenessState.unrecoverableStateEncountered(.unknown)
//            }
//        }
//    }
//
//    var hasSentFinalVideoEvent = false
//    var hasSentFirstVideo = false
//
//    func sendFinalVideoChunk(data: Data, videoEventTime: UInt64) {
//        sendVideoEvent(data: data, videoEventTime: videoEventTime)
//        sendFinalEvent(
//            targetFaceRect: faceGuideRect,
//            viewSize: .init(width: 480, height: 640),
//            faceMatchedEnd: Date.livenessTimestamp
//        )
////        videoChunker.provideSingleFrame = provideSingleFrame
//        videoChunker.finish { _ in
//
//        }
//    }
//
//
//    var provideSingleFrame: ((UIImage) -> Void)?
//    var faceGuideRect: CGRect!
//
//    func handleFreshnessComplete(faceGuideRect: CGRect) {
//        DispatchQueue.main.async {
//            self.faceLivenessDetectionViewModel
//                .livenessState.completedDisplayingFreshness()
//
//            self.faceGuideRect = faceGuideRect
//        }
//    }
//
//    func chunk(initial: Data, current: Data) -> Data {
//        let data: Data
//        if hasSentFirstVideo {
//            data = current
//        } else {
//            data = initial + current
//            hasSentFirstVideo = true
//        }
//        return data
//    }
//
//    func sendVideoChunks(initial: Data, current: Data) {
//        let data: Data
//        if hasSentFirstVideo {
//            data = current
//        } else {
//            data = initial + current
//            hasSentFirstVideo = true
//        }
//        sendVideoEvent(data: data, videoEventTime: .zero)
//    }
//
//    func sendVideoEvent(data: Data, videoEventTime: UInt64, n: UInt8 = 1) {
//        guard !hasSentFinalVideoEvent else { return }
//        let eventDate = Date()
//        let timestamp = eventDate.livenessTimestamp
//
//        let videoEvent = VideoEvent.init(chunk: data, timestamp: timestamp)
//
//        do {
//            try livenessService.send(
//                .video(event: videoEvent),
//                eventDate: { eventDate }
//            )
//        } catch {
//            DispatchQueue.main.async {
//                self.faceLivenessDetectionViewModel.livenessState.unrecoverableStateEncountered(.unknown)
//            }
//        }
//    }
//
//    private func generateLivenessError(from captureSessionError: Error) -> LivenessStateMachine.LivenessError {
//        guard let captureSessionError = captureSessionError as? LivenessCaptureSessionError else { return .unknown }
//
//        let livenessError: LivenessStateMachine.LivenessError
//
//        switch captureSessionError {
//        case LivenessCaptureSessionError.cameraUnavailable,
//            LivenessCaptureSessionError.deviceInputUnavailable:
//
//            livenessError = .missingVideoPermission
//        case LivenessCaptureSessionError.captureSessionOutputUnavailable,
//            LivenessCaptureSessionError.captureSessionInputUnavailable:
//
//            livenessError = .errorWithUnderlyingOSFramework
//        default:
//            livenessError = .unknown
//        }
//
//        return livenessError
//    }
//}
//
//
//extension Date {
//    static var livenessTimestamp: UInt64 {
//        UInt64(Date().timeIntervalSince1970 * 1_000)
//    }
//
//    var livenessTimestamp: UInt64 {
//        UInt64(self.timeIntervalSince1970 * 1_000)
//    }
//}
