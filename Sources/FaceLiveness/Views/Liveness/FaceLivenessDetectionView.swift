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
    let facelivenessDetectorViewId: String
    let onCompletion: (Result<Void, FaceLivenessDetectionError>) -> Void

    let sessionTask: Task<FaceLivenessSession, Error>

    public init(
        sessionID: String,
        credentialsProvider: AWSCredentialsProvider? = nil,
        region: String,
        disableStartView: Bool = false,
        isPresented: Binding<Bool>,
        onCompletion: @escaping (Result<Void, FaceLivenessDetectionError>) -> Void
    ) {
        let viewId = UUID().uuidString
        self.facelivenessDetectorViewId = viewId
        self.disableStartView = disableStartView
        self._isPresented = isPresented
        self.onCompletion = onCompletion

        self.sessionTask = Task {
            let session = try await AWSPredictionsPlugin.startFaceLivenessSession(
                withID: sessionID,
                credentialsProvider: credentialsProvider,
                region: region,
                options: .init(faceLivenessDetectorViewId: viewId,
                               preCheckViewEnabled: !disableStartView),
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

        let avCpatureDevice = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front
        ).devices.first

        let captureSession = LivenessCaptureSession(
            captureDevice: .init(avCaptureDevice: avCpatureDevice),
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
                sessionID: sessionID
            )
        )
    }
    
    init(
        sessionID: String,
        credentialsProvider: AWSCredentialsProvider? = nil,
        region: String,
        disableStartView: Bool = false,
        isPresented: Binding<Bool>,
        onCompletion: @escaping (Result<Void, FaceLivenessDetectionError>) -> Void,
        captureSession: LivenessCaptureSession
    ) {
        let viewId = UUID().uuidString
        self.facelivenessDetectorViewId = viewId
        self.disableStartView = disableStartView
        self._isPresented = isPresented
        self.onCompletion = onCompletion

        self.sessionTask = Task {
            let session = try await AWSPredictionsPlugin.startFaceLivenessSession(
                withID: sessionID,
                credentialsProvider: credentialsProvider,
                region: region,
                options: .init(faceLivenessDetectorViewId: viewId,
                               preCheckViewEnabled: !disableStartView),
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
                sessionID: sessionID
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
                        viewModel.registerServiceEvents(onChallengeTypeReceived: {
                            self.displayState = DisplayState.awaitingLivenessSession
                        })
                        viewModel.initializeLivenessStream()
                    } catch {
                        throw FaceLivenessDetectionError.accessDenied
                    }
                }
            }
        case .awaitingLivenessSession:
            Color.clear
                .onAppear {
                    Task {
                        do {
                            let newState = disableStartView
                            ? DisplayState.displayingLiveness
                            : DisplayState.displayingGetReadyView
                            guard self.displayState != newState else { return }
                            self.displayState = newState
                        }
                    }
                }

        case .displayingGetReadyView:
            GetReadyPageView(
                onBegin: {
                    guard displayState != .displayingLiveness else { return }
                    displayState = .displayingLiveness
                },
                beginCheckButtonDisabled: false,
                challenge: viewModel.challenge!
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
        case .userCancelled:
            return .userCancelled
        case .timedOut:
            return .sessionTimedOut
        case .socketClosed:
            return .socketClosed
        default:
            return .cameraPermissionDenied
        }
    }

    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(
            for: .video,
            completionHandler: { accessGranted in
                guard accessGranted == true else { return }
                displayState = .awaitingLivenessSession
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
            displayState = .awaitingLivenessSession
        @unknown default:
            break
        }
    }
}

enum DisplayState {
    case awaitingLivenessSession
    case displayingGetReadyView
    case displayingLiveness
    case awaitingCameraPermission
    case awaitingChallengeType
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
        default:
            detectionCompletion(.failure(.unknown))
        }
    }
}
