//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
import AWSClientRuntime
import protocol AWSPluginsCore.AWSCredentialsProvider
import AWSPredictionsPlugin
import AVFoundation
import Amplify
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

public struct FaceLivenessDetectorView: View {
    @StateObject var viewModel: FaceLivenessDetectionViewModel
    @Binding var isPresented: Bool
    @State var displayState: DisplayState = .awaitingChallengeType
    @State var displayingCameraPermissionsNeededAlert = false

    let disableStartView: Bool
    let cameraPosition: LivenessCaptureDevicePosition
    let onCompletion: (Result<Void, FaceLivenessDetectionError>) -> Void

    let sessionTask: Task<FaceLivenessSession, Error>

    public init(
        sessionID: String,
        credentialsProvider: AWSCredentialsProvider? = nil,
        region: String,
        disableStartView: Bool = false,
        cameraPosition: LivenessCaptureDevicePosition = .front,
        isPresented: Binding<Bool>,
        onCompletion: @escaping (Result<Void, FaceLivenessDetectionError>) -> Void
    ) {        
        self.disableStartView = disableStartView
        self._isPresented = isPresented
        self.cameraPosition = cameraPosition
        self.onCompletion = onCompletion

        self.sessionTask = Task {
            let session = try await AWSPredictionsPlugin.startFaceLivenessSession(
                withID: sessionID,
                credentialsProvider: credentialsProvider,
                region: region,
                completion: map(detectionCompletion: onCompletion)
            )
            return session
        }

        let faceDetector = try! FaceDetectorShortRange.Model()
        let faceInOvalStateMatching = FaceInOvalMatching(
            instructor: Instructor()
        )

        let videoChunker = VideoChunker(
            assetWriter: LivenessAVAssetWriter(),
            assetWriterDelegate: VideoChunker.AssetWriterDelegate(),
            assetWriterInput: LivenessAVAssetWriterInput()
        )
        
        let avCaptureDevice = AVCaptureDevice.default(
                                .builtInWideAngleCamera,
                                for: .video,
                                position: cameraPosition == .front ? .front : .back)

        let captureSession = LivenessCaptureSession(
            captureDevice: .init(avCaptureDevice: avCaptureDevice),
            outputDelegate: OutputSampleBufferCapturer(
                faceDetector: faceDetector,
                videoChunker: videoChunker
            )
        )

        self._viewModel = StateObject(
            wrappedValue: .init(
                faceDetector: faceDetector,
                faceInOvalMatching: faceInOvalStateMatching,
                captureSession: captureSession,
                videoChunker: videoChunker,
                closeButtonAction: { onCompletion(.failure(.userCancelled)) },
                sessionID: sessionID,
                isPreviewScreenEnabled: !disableStartView,
                cameraPosition: cameraPosition
            )
        )
    }
    
    init(
        sessionID: String,
        credentialsProvider: AWSCredentialsProvider? = nil,
        region: String,
        disableStartView: Bool = false,
        cameraPosition: LivenessCaptureDevicePosition,
        isPresented: Binding<Bool>,
        onCompletion: @escaping (Result<Void, FaceLivenessDetectionError>) -> Void,
        captureSession: LivenessCaptureSession
    ) {
        self.disableStartView = disableStartView
        self._isPresented = isPresented
        self.onCompletion = onCompletion
        self.cameraPosition = cameraPosition

        self.sessionTask = Task {
            let session = try await AWSPredictionsPlugin.startFaceLivenessSession(
                withID: sessionID,
                credentialsProvider: credentialsProvider,
                region: region,
                completion: map(detectionCompletion: onCompletion)
            )
            return session
        }

        let faceInOvalStateMatching = FaceInOvalMatching(
            instructor: Instructor()
        )

        self._viewModel = StateObject(
            wrappedValue: .init(
                faceDetector: captureSession.outputSampleBufferCapturer!.faceDetector,
                faceInOvalMatching: faceInOvalStateMatching,
                captureSession: captureSession,
                videoChunker: captureSession.outputSampleBufferCapturer!.videoChunker,
                closeButtonAction: { onCompletion(.failure(.userCancelled)) },
                sessionID: sessionID,
                isPreviewScreenEnabled: !disableStartView,
                cameraPosition: cameraPosition
            )
        )
    }

    public var body: some View {
        switch displayState {
        case .awaitingChallengeType:
            LoadingPageView()
            .onAppear {
                Task {
                    do {
                        let session = try await sessionTask.value
                        viewModel.livenessService = session
                        viewModel.registerServiceEvents(onChallengeTypeReceived: { challenge in
                            self.displayState = DisplayState.awaitingLivenessSession(challenge)
                        })
                        viewModel.initializeLivenessStream()
                    } catch {
                        throw FaceLivenessDetectionError.accessDenied
                    }
                    
                    DispatchQueue.main.async {
                        if let faceDetector = viewModel.faceDetector as? FaceDetectorShortRange.Model {
                            faceDetector.setFaceDetectionSessionConfigurationWrapper(configuration: viewModel)
                        }
                    }
                }
            }
            .onReceive(viewModel.$livenessState) { output in
                switch output.state {
                case .encounteredUnrecoverableError(let error):
                    let closeCode = error.webSocketCloseCode ?? .normalClosure
                    viewModel.livenessService?.closeSocket(with: closeCode)
                    isPresented = false
                    onCompletion(.failure(mapError(error)))
                default:
                    break
                }
            }
        case .awaitingLivenessSession(let challenge):
        case .awaitingChallengeType:
            LoadingPageView()
            .onAppear {
                Task {
                    do {
                        let session = try await sessionTask.value
                        viewModel.livenessService = session
                        viewModel.registerServiceEvents(onChallengeTypeReceived: { challenge in
                            self.displayState = DisplayState.awaitingLivenessSession(challenge)
                        })
                        viewModel.initializeLivenessStream()
                    } catch {
                        throw FaceLivenessDetectionError.accessDenied
                    }
                    
                    DispatchQueue.main.async {
                        if let faceDetector = viewModel.faceDetector as? FaceDetectorShortRange.Model {
                            faceDetector.setFaceDetectionSessionConfigurationWrapper(configuration: viewModel)
                        }
                    }
                }
            }
            .onReceive(viewModel.$livenessState) { output in
                switch output.state {
                case .encounteredUnrecoverableError(let error):
                    let closeCode = error.webSocketCloseCode ?? .normalClosure
                    viewModel.livenessService?.closeSocket(with: closeCode)
                    isPresented = false
                    onCompletion(.failure(mapError(error)))
                default:
                    break
                }
            }
        case .awaitingLivenessSession(let challenge):
            Color.clear
                .onAppear {
                    Task {
                        do {
                            let newState = disableStartView
                            ? DisplayState.displayingLiveness
                            : DisplayState.displayingGetReadyView(challenge, cameraPosition)
                            guard self.displayState != newState else { return }
                            self.displayState = newState
                        }
                    }
                }

        case .displayingGetReadyView(let challenge, let cameraPosition):
            GetReadyPageView(
                onBegin: {
                    guard displayState != .displayingLiveness else { return }
                    displayState = .displayingLiveness
                },
                beginCheckButtonDisabled: false,
                challenge: challenge,
                cameraPosition: cameraPosition
            )
            .onAppear {
                DispatchQueue.main.async {
                    UIScreen.main.brightness = 1.0
                }
            }
        case .displayingLiveness:
            _FaceLivenessDetectionView(
                viewModel: viewModel,
                videoView: {
                    CameraView(
                        faceLivenessDetectionViewModel: viewModel
                    )
                }
            )
            .onAppear {
                DispatchQueue.main.async {
                    UIScreen.main.brightness = 1.0
                }
            }
            .onDisappear() {
                viewModel.stopRecording()
            }
            .onReceive(viewModel.$livenessState) { output in
                switch output.state {
                case .completed:
                    isPresented = false
                    onCompletion(.success(()))
                case .encounteredUnrecoverableError(let error):
                    let closeCode = error.webSocketCloseCode ?? .normalClosure
                    viewModel.livenessService?.closeSocket(with: closeCode)
                    isPresented = false
                    onCompletion(.failure(mapError(error)))
                default:
                    break
                }
            }
        case .awaitingCameraPermission:
            CameraPermissionView(displayingCameraPermissionsNeededAlert: $displayingCameraPermissionsNeededAlert)
                .onAppear {
                    checkCameraPermission()
                }
        }
    }

    func mapError(_ livenessError: LivenessStateMachine.LivenessError) -> FaceLivenessDetectionError {
        switch livenessError {
        case .userCancelled, .viewResignation:
            return .userCancelled
        case .timedOut:
            return .faceInOvalMatchExceededTimeLimitError
        case .socketClosed:
            return .socketClosed
        case .cameraNotAvailable:
            return .cameraNotAvailable
        case .invalidCameraPositionSelecteed:
            return .invalidCameraPositionSelected
        default:
            return .cameraPermissionDenied
        }
    }

    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(
            for: .video,
            completionHandler: { accessGranted in
                guard accessGranted == true else { return }
                guard let challenge = viewModel.challenge else { return }
                displayState = .awaitingLivenessSession(challenge)
            }
        )

    }

    private func alertCameraAccessNeeded() {
        displayingCameraPermissionsNeededAlert = true
    }
    
    private func checkCameraPermission() {
        let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch cameraAuthorizationStatus {
        case .notDetermined:
            requestCameraPermission()
        case .restricted, .denied:
            alertCameraAccessNeeded()
        case .authorized:
            guard let challenge = viewModel.challenge else { return }
            displayState = .awaitingLivenessSession(challenge)
        @unknown default:
            break
        }
    }
}

enum DisplayState: Equatable {
    case awaitingChallengeType
    case awaitingLivenessSession(Challenge)
    case displayingGetReadyView(Challenge, LivenessCaptureDevicePosition)
    case displayingLiveness
    case awaitingCameraPermission
    
    static func == (lhs: DisplayState, rhs: DisplayState) -> Bool {
        switch (lhs, rhs) {
        case (.awaitingChallengeType, .awaitingChallengeType):
            return true
        case (let .awaitingLivenessSession(c1), let .awaitingLivenessSession(c2)):
            return c1.type == c2.type && c1.version == c2.version
        case (let .displayingGetReadyView(c1, position1), let .displayingGetReadyView(c2, position2)):
            return c1.type == c2.type && c1.version == c2.version && position1 == position2
        case (.displayingLiveness, .displayingLiveness):
            return true
        case (.awaitingCameraPermission, .awaitingCameraPermission):
            return true
        default:
            return false
        }
    }
}

enum InstructionState {
    case none
    case display(text: String)
}

private func map(detectionCompletion: @escaping (Result<Void, FaceLivenessDetectionError>) -> Void) -> ((Result<Void, FaceLivenessSessionError>) -> Void) {
    { result in
        switch result {
        case .success:
            detectionCompletion(.success(()))
        case .failure(.invalidRegion):
            detectionCompletion(.failure(.invalidRegion))
        case .failure(.accessDenied):
            detectionCompletion(.failure(.accessDenied))
        case .failure(.validation):
            detectionCompletion(.failure(.validation))
        case .failure(.internalServer):
            detectionCompletion(.failure(.internalServer))
        case .failure(.throttling):
            detectionCompletion(.failure(.throttling))
        case .failure(.serviceQuotaExceeded):
            detectionCompletion(.failure(.serviceQuotaExceeded))
        case .failure(.serviceUnavailable):
            detectionCompletion(.failure(.serviceUnavailable))
        case .failure(.sessionNotFound):
            detectionCompletion(.failure(.sessionNotFound))
        case .failure(.invalidSignature):
            detectionCompletion(.failure(.invalidSignature))
        default:
            detectionCompletion(.failure(.unknown))
        }
    }
}
