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
    @State var displayState: DisplayState = .awaitingLivenessSession
    @State var displayingCameraPermissionsNeededAlert = false

    let disableStartView: Bool
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
        self.disableStartView = disableStartView
        self._isPresented = isPresented
        self.onCompletion = onCompletion

        self.sessionTask = Task {
            let session = try await AWSPredictionsPlugin.startFaceLivenessSession(
                withID: sessionID,
                credentialsProvider: credentialsProvider,
                region: region,
                options: .init(),
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
        self.disableStartView = disableStartView
        self._isPresented = isPresented
        self.onCompletion = onCompletion

        self.sessionTask = Task {
            let session = try await AWSPredictionsPlugin.startFaceLivenessSession(
                withID: sessionID,
                credentialsProvider: credentialsProvider,
                region: region,
                options: .init(),
                completion: map(detectionCompletion: onCompletion)
            )
            return session
        }

        let faceInOvalStateMatching = FaceInOvalMatching(
            instructor: Instructor()
        )

        self._viewModel = StateObject(
            wrappedValue: .init(
                faceDetector: captureSession.outputDelegate.faceDetector,
                faceInOvalMatching: faceInOvalStateMatching,
                captureSession: captureSession,
                videoChunker: captureSession.outputDelegate.videoChunker,
                closeButtonAction: { onCompletion(.failure(.userCancelled)) },
                sessionID: sessionID
            )
        )
    }

    public var body: some View {
        switch displayState {
        case .awaitingLivenessSession:
            Color.clear
                .onAppear {
                    Task {
                        do {
                            let session = try await sessionTask.value
                            viewModel.livenessService = session
                            viewModel.registerServiceEvents()

                            self.displayState = disableStartView
                            ? .displayingLiveness
                            : .displayingGetReadyView
                        } catch {
                            throw FaceLivenessDetectionError.accessDenied
                        }
                    }
                }

        case .displayingGetReadyView:
            GetReadyPageView(
                displayingCameraPermissionsNeededAlert: $displayingCameraPermissionsNeededAlert,
                onBegin: beginButtonTapped,
                beginCheckButtonDisabled: false
            )
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
            .onReceive(viewModel.$livenessState) { output in
                switch output.state {
                case .completed:
                    isPresented = false
                    onCompletion(.success(()))
                case .encounteredUnrecoverableError(let error):
                    let closeCode = error.webSocketCloseCode ?? .normalClosure
                    viewModel.livenessService.closeSocket(with: closeCode)
                    isPresented = false
                    onCompletion(.failure(mapError(error)))
                default:
                    break
                }
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
                displayState = .displayingLiveness
                DispatchQueue.main.async {
                    UIScreen.main.brightness = 1.0
                }
            }
        )

    }

    private func alertCameraAccessNeeded() {
        displayingCameraPermissionsNeededAlert = true
    }

    private func beginButtonTapped() {
        let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch cameraAuthorizationStatus {
        case .notDetermined:
            requestCameraPermission()
        case .authorized:
            displayState = .displayingLiveness
        case .restricted, .denied:
            alertCameraAccessNeeded()
        @unknown default:
            break
        }
    }
}

enum DisplayState {
    case awaitingLivenessSession
    case displayingGetReadyView
    case displayingLiveness
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
