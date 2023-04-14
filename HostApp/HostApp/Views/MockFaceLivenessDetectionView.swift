//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
import Primitives
import AWSClientRuntime
import AWSPluginsCore
import AWSPredictionsPlugin
import AVFoundation

fileprivate func websocket() -> WebSocket.Processor {
    WebSocket.Processor(
        receiveString: { _ in
            return true
        },
        receiveData: { _ in
            return true
        },
        failure: { _ in }
    )
}

public protocol LivenessCredentialsProvider {
    var accessKey: String { get }
    var secretKey: String { get }
    var sessionToken: String { get }
}

public enum CountdownDisplayState {
    case waitingToDisplay
    case displaying
    case finishedDisplaying
}

public class FaceLivenessDetectionViewModel: ObservableObject {
    @Published var readyForOval = false
    @Published var isRecording = false
    @Published var livenessState: LivenessStateMachine

    var camera: Camera? = nil
    let websocket: WebSocket.Processor
    var closeButtonAction: () -> Void
    let videoChunker: VideoChunker
    var credentialsProvider: LivenessCredentialsProvider
    let sessionID: String

    public init(
        viewModel: FaceLivenessDetectionViewModel,
        credentialsProvider: LivenessCredentialsProvider,
        stateMachine: LivenessStateMachine = .init(state: .initial),
        closeButtonAction: @escaping () -> Void,
        sessionID: String
    ) {
        self.websocket = FaceLiveness.websocket()
        self.closeButtonAction = closeButtonAction
        self.videoChunker = .init(
            assetWriter: .livenessStandard,
            assetWriterDelegate: VideoChunker.AssetWriterDelegate(
                frameProcessor: websocket
            ),
            assetWriterInput: .livenessStandard
        )
        self.credentialsProvider = credentialsProvider
        self.livenessState = stateMachine
        self.sessionID = sessionID
        self.closeButtonAction = {
            DispatchQueue.main.async {
                self.stopRecording()
                self.livenessState.unrecoverableStateEncountered(.userCancelled)
            }
        }
    }

    func stopRecording() {
        camera?.stopRunning()
    }

    func signerCredentials() -> Signer.Credential {
        .init(
            accessKey: credentialsProvider.accessKey,
            secretKey: credentialsProvider.secretKey,
            sessionToken: credentialsProvider.sessionToken
        )
    }
}

enum DisplayState {
    case displayingGetReadyView
    case displayingLiveness
}

public enum InstructionState {
    case none
    case display(text: String)
}

public struct FaceLivenessDetectionView: View {
    @ObservedObject var viewModel: FaceLivenessDetectionViewModel
    @Binding var isPresented: Bool
    @State var displayState: DisplayState = .displayingGetReadyView
    @State var displayingCameraPermissionsNeededAlert = false

    let disableStartView: Bool
    let onCompletion: (Result<Void, DetectionError>) -> Void

    public init(
        sessionID: String,
        credentialsProvider: LivenessCredentialsProvider? = nil,
        disableStartView: Bool = false,
        isPresented: Binding<Bool>,
        onCompletion: @escaping (Result<Void, DetectionError>) -> Void
    ) {
        self.disableStartView = disableStartView
        self._isPresented = isPresented
        self.onCompletion = onCompletion

        let credentialsProvider = credentialsProvider ?? .mock
//        RekognitionLivenessCredentialsProvider(
//            credentialsProvider: AWSAuthService().getCredentialsProvider()
//        )
        self.viewModel = .init(
            credentialsProvider: credentialsProvider,
            closeButtonAction: {},
            sessionID: sessionID
        )

    }

    public var body: some View {
        let _ = Self._printChanges()
//        if isPresented {
        switch displayState {
        case .displayingGetReadyView:
            GetReadyPageView(
                displayingCameraPermissionsNeededAlert: $displayingCameraPermissionsNeededAlert,
                onBegin: beginButtonTapped
            )
        case .displayingLiveness:
            _FaceLivenessDetectionView(
                viewModel: viewModel,
                videoView: {
                    _CameraView(
                        faceLivenessDetectionViewModel: viewModel
                    )
                }
            )
            .onReceive(viewModel.$livenessState) { output in
                switch output.state {
                case .completed:
                    isPresented = false
                    onCompletion(.success(()))
//                    viewModel
                case .encounteredUnrecoverableError(let error):
                    isPresented = false
                    onCompletion(.failure(mapError(error)))
                default:
                    break
                }
            }
        }
    }

    func mapError(_ livenessError: LivenessStateMachine.LivenessError) -> DetectionError {
        switch livenessError {
        case .userCancelled:
            return .userCancelled
        case .timedOut:
            return .sessionTimedOut
        default:
            return .cameraPermissionDenied
//            fatalError()
        }
    }

    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(
            for: .video,
            completionHandler: { accessGranted in
                guard accessGranted == true else { return }
                displayState = .displayingLiveness
                UIScreen.main.brightness = 1.0
                UIScreen.main.brightness = 0.99
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
            UIScreen.main.brightness = 0.99
        case .restricted, .denied:
            alertCameraAccessNeeded()
        @unknown default:
            break
        }
    }
}

struct RekognitionLivenessCredentialsProvider: LivenessCredentialsProvider {
    let accessKey: String
    let secretKey: String
    let sessionToken: String

    init(credentialsProvider: CredentialsProvider) {
        self.accessKey = ""
        self.secretKey = ""
        self.sessionToken = ""
    }
}

extension LivenessCredentialsProvider where Self == MockLivenessCredentialsProvider {
    static var mock: Self {
        .init(
            accessKey: "AKIDEXAMPLE",
            secretKey: "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
            sessionToken: "example"
        )
    }
}

struct MockLivenessCredentialsProvider: LivenessCredentialsProvider {
    let accessKey: String
    let secretKey: String
    let sessionToken: String

    init(accessKey: String, secretKey: String, sessionToken: String) {
        self.accessKey = accessKey
        self.secretKey = secretKey
        self.sessionToken = sessionToken
    }
}
