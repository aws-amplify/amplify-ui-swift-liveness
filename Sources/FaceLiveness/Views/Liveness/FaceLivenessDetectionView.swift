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

enum CountdownDisplayState {
    case waitingToDisplay
    case displaying
    case finishedDisplaying
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

func log(_ value: Any, _ label: String = "", file: String = #fileID, function: String = #function, line: Int = #line) {
    print(">> [\(file):\(line)] [\(function)] [\(label)] \(value)")
}

fileprivate func map(detectionCompletion: @escaping (Result<Void, FaceLivenessDetectionError>) -> Void) -> ((Result<Void, FaceLivenessSessionError>) -> Void) {
    { result in
        switch result {
        case .success:
            detectionCompletion(.success(()))
        case .failure(.invalidRegion):
            detectionCompletion(.failure(.invalidRegion))
        case .failure(.accessDenied):
            detectionCompletion(.failure(.accessDenied))
        default:
            detectionCompletion(.failure(.unknown))
        }
    }
}

public struct FaceLivenessDetectionView: View {
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
                region: region,
                options: .init(),
                completion: map(detectionCompletion: onCompletion)
            )
            return session
        }

        let faceDetector = try! FaceDetectorShortRange.Model()
        log(faceDetector, "faceDetector")

        let faceInOvalStateMatching = FaceInOvalMatching(
            instructor: Instructor()
        )
        log(faceInOvalStateMatching, "faceInOvalStateMatching")

        let videoChunker = VideoChunker(
            assetWriter: LivenessAVAssetWriter(),
            assetWriterDelegate: VideoChunker.AssetWriterDelegate(),
            assetWriterInput: LivenessAVAssetWriterInput()
        )
        log(videoChunker, "videoChunker")


        let avCpatureDevice = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front
        ).devices.first! // TODO: Handle gracefully

        log(avCpatureDevice, "avCpatureDevice")

        let captureSession = LivenessCaptureSession(
            captureDevice: .init(avCaptureDevice: avCpatureDevice),
            outputDelegate: OutputSampleBufferCapturer(
                faceDetector: faceDetector,
                videoChunker: videoChunker
            )
        )
        log(captureSession, "captureSession")

        self._viewModel = StateObject(
            wrappedValue: .init(
                faceDetector: faceDetector,
                faceInOvalMatching: faceInOvalStateMatching,
                captureSession: captureSession,
                videoChunker: videoChunker,
                closeButtonAction: {},
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
                            self.displayState = .displayingGetReadyView
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
            .onReceive(viewModel.$livenessState) { output in
                switch output.state {
                case .completed:
                    isPresented = false
                    onCompletion(.success(()))
                case .encounteredUnrecoverableError(let error):
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
        case .invalidFaceMovementDuringCountdown:
            return .countdownFaceTooClose
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
            UIScreen.main.brightness = 1.0
        case .restricted, .denied:
            alertCameraAccessNeeded()
        @unknown default:
            break
        }
    }
}

//struct RekognitionLivenessCredentialsProvider: LivenessCredentialsProvider {
//    let accessKey: String
//    let secretKey: String
//    let sessionToken: String
//
//    init(credentialsProvider: CredentialsProvider) {
//        self.accessKey = ""
//        self.secretKey = ""
//        self.sessionToken = ""
//    }
//}

//extension LivenessCredentialsProvider where Self == MockLivenessCredentialsProvider {
//    static var mock: Self {
//        .init(
//            accessKey: "AKIDEXAMPLE",
//            secretKey: "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
//            sessionToken: "example"
//        )
//    }
//}
//
//struct MockLivenessCredentialsProvider: LivenessCredentialsProvider {
//    let accessKey: String
//    let secretKey: String
//    let sessionToken: String
//
//    init(accessKey: String, secretKey: String, sessionToken: String) {
//        self.accessKey = accessKey
//        self.secretKey = secretKey
//        self.sessionToken = sessionToken
//    }
//}
