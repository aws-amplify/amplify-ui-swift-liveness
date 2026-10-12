//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
import AWSClientRuntime
// Re-exported so consumers can use the credentials-provider initializer with
// only `import FaceLiveness`.
@_exported import protocol AWSPluginsCore.AWSCredentialsProvider
@_exported import protocol AWSPluginsCore.AWSCredentials
@_exported import protocol AWSPluginsCore.AWSTemporaryCredentials
import AWSPredictionsPlugin
import AVFoundation
import Amplify
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

public struct FaceLivenessDetectorView: View {
    @StateObject var viewModel: FaceLivenessDetectionViewModel
    @Binding var isPresented: Bool
    @State var displayState: DisplayState = .awaitingChallengeType
    @State var displayingCameraPermissionsNeededAlert = false
    @State private var screenState = ScreenState()
    @StateObject private var orientationObserver = InterfaceOrientationObserver()
    @SwiftUI.Environment(\.faceLivenessDetectorTheme) private var theme

    /// The screen settings the check overrides, as they were before, so they can be restored.
    private final class ScreenState {
        var originalBrightness: CGFloat?
        var originalIsIdleTimerDisabled: Bool?
    }

    let disableStartView: Bool
    let challengeOptions: ChallengeOptions
    var cancelButtonOptions = CancelButtonOptions()
    let onCompletion: (Result<Void, FaceLivenessDetectionError>) -> Void

    let sessionTask: Task<FaceLivenessSession, Error>

    public init(
        sessionID: String,
        credentialsProvider: AWSCredentialsProvider? = nil,
        region: String,
        disableStartView: Bool = false,
        challengeOptions: ChallengeOptions = .init(),
        isPresented: Binding<Bool>,
        onCompletion: @escaping (Result<Void, FaceLivenessDetectionError>) -> Void
    ) {        
        self.disableStartView = disableStartView
        self._isPresented = isPresented
        self.onCompletion = onCompletion
        self.challengeOptions = challengeOptions

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
        let faceInOvalStateMatching = FaceInOvalMatching()

        let videoChunker = VideoChunker(
            assetWriter: LivenessAVAssetWriter(),
            assetWriterDelegate: VideoChunker.AssetWriterDelegate(),
            assetWriterInput: LivenessAVAssetWriterInput()
        )

        self._viewModel = StateObject(
            wrappedValue: .init(
                faceDetector: faceDetector,
                faceInOvalMatching: faceInOvalStateMatching,
                videoChunker: videoChunker,
                closeButtonAction: { onCompletion(.failure(.userCancelled)) },
                sessionID: sessionID,
                isPreviewScreenEnabled: !disableStartView,
                challengeOptions: challengeOptions
            )
        )
    }
    
    init(
        sessionID: String,
        credentialsProvider: AWSCredentialsProvider? = nil,
        region: String,
        disableStartView: Bool = false,
        challengeOptions: ChallengeOptions = .init(),
        isPresented: Binding<Bool>,
        onCompletion: @escaping (Result<Void, FaceLivenessDetectionError>) -> Void,
        captureSession: LivenessCaptureSession
    ) {
        self.disableStartView = disableStartView
        self._isPresented = isPresented
        self.onCompletion = onCompletion
        self.challengeOptions = challengeOptions

        self.sessionTask = Task {
            let session = try await AWSPredictionsPlugin.startFaceLivenessSession(
                withID: sessionID,
                credentialsProvider: credentialsProvider,
                region: region,
                completion: map(detectionCompletion: onCompletion)
            )
            return session
        }

        let faceInOvalStateMatching = FaceInOvalMatching()

        self._viewModel = StateObject(
            wrappedValue: .init(
                faceDetector: captureSession.outputSampleBufferCapturer!.faceDetector,
                faceInOvalMatching: faceInOvalStateMatching,
                videoChunker: captureSession.outputSampleBufferCapturer!.videoChunker,
                closeButtonAction: { onCompletion(.failure(.userCancelled)) },
                sessionID: sessionID,
                isPreviewScreenEnabled: !disableStartView,
                challengeOptions: challengeOptions
            )
        )
    }

    public var body: some View {
        ZStack {
            // `RotateDeviceView` covers the content but not the accessibility tree
            content
                .accessibilityHidden(orientationObserver.decision == .blockUntilPortrait)

            if orientationObserver.decision == .blockUntilPortrait {
                RotateDeviceView(cancelButtonOptions: cancelButtonOptions, onClose: cancelFromRotatePrompt)
            }
        }
        // one full-screen fill for every state, so the app's own background never shows, even
        // around a state whose content is smaller than the screen
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colors.background.edgesIgnoringSafeArea(.all))
        .background(
            InterfaceOrientationReader(
                onTransition: orientationObserver.beginTransition(with:),
                onSettled: orientationObserver.settle(in:)
            )
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        )
        .onChange(of: orientationObserver.orientation) { _ in
            interruptCheckIfOrientationUnsupported()
            advanceIfWaitingOnPortrait()
        }
        .onReceive(viewModel.$livenessState) { output in
            // one observer for every display state, so any exit that reaches a terminal
            // state dismisses and fires the host's completion exactly once
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
        .onDisappear {
            restoreScreen()
            // the get ready screen leaves the camera running for the check, so stop it here
            // in case the app removes the detector before the check starts
            viewModel.stopRecording()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch displayState {
        case .awaitingChallengeType:
            LoadingPageView()
            .onAppear {
                Task {
                    do {
                        let session = try await sessionTask.value
                        viewModel.livenessService = session
                        viewModel.registerServiceEvents(onChallengeTypeReceived: { challenge in
                            self.displayState = DisplayState.awaitingCameraPermission(challenge)
                        })
                        viewModel.initializeLivenessStream()
                    } catch let error as FaceLivenessDetectionError {
                        switch error {
                        case .unknown:
                            viewModel.livenessState.unrecoverableStateEncountered(.unknown)
                        case .sessionTimedOut,
                             .faceInOvalMatchExceededTimeLimitError,
                             .countdownFaceTooClose,
                             .countdownMultipleFaces,
                             .countdownNoFace:
                            viewModel.livenessState.unrecoverableStateEncountered(.timedOut)
                        case .cameraPermissionDenied:
                            viewModel.livenessState.unrecoverableStateEncountered(.missingVideoPermission)
                        case .userCancelled:
                            viewModel.livenessState.unrecoverableStateEncountered(.userCancelled)
                        case .socketClosed:
                            viewModel.livenessState.unrecoverableStateEncountered(.socketClosed)
                        case .cameraNotAvailable:
                            viewModel.livenessState.unrecoverableStateEncountered(.cameraNotAvailable)
                        default:
                            viewModel.livenessState.unrecoverableStateEncountered(.couldNotOpenStream)
                        }
                    } catch {
                        viewModel.livenessState.unrecoverableStateEncountered(.couldNotOpenStream)
                    }
                    
                    DispatchQueue.main.async {
                        if let faceDetector = viewModel.faceDetector as? FaceDetectorShortRange.Model {
                            faceDetector.setFaceDetectionSessionConfigurationWrapper(configuration: viewModel)
                        }
                    }
                }
            }
        case .awaitingCameraPermission(let challenge):
            CameraPermissionView(displayingCameraPermissionsNeededAlert: $displayingCameraPermissionsNeededAlert)
                .onAppear {
                    checkCameraPermission(for: challenge)
                }
        case .awaitingLivenessSession:
            Color.clear
                .onAppear {
                    advanceIfWaitingOnPortrait()
                }
        case .displayingGetReadyView(let challenge, let cameraPosition):
            GetReadyPageView(
                onBegin: {
                    // the check must not start underneath the rotate prompt
                    guard displayState != .displayingLiveness,
                          orientationObserver.decision == .proceed
                    else { return }
                    displayState = .displayingLiveness
                },
                beginCheckButtonDisabled: false,
                challenge: challenge,
                cameraPosition: cameraPosition,
                sharedCaptureSession: viewModel.captureSession
            )
            .onAppear {
                setScreenForCheck()
            }
        case .displayingLiveness:
            _FaceLivenessDetectionView(
                viewModel: viewModel,
                cancelButtonOptions: cancelButtonOptions,
                videoView: {
                    CameraView(
                        faceLivenessDetectionViewModel: viewModel
                    )
                }
            )
            .onAppear {
                setScreenForCheck()
            }
            .onDisappear() {
                viewModel.stopRecording()
            }
        }
    }

    /// Advances from `.awaitingLivenessSession` to the get ready screen (or straight to the
    /// check) once the interface is portrait. Holding here keeps the session reusable.
    private func advanceIfWaitingOnPortrait() {
        guard case .awaitingLivenessSession(let challenge) = displayState else { return }
        guard orientationObserver.decision == .proceed else { return }

        let newState = disableStartView
        ? DisplayState.displayingLiveness
        : DisplayState.displayingGetReadyView(challenge, challengeOptions.camera(for: challenge))
        guard self.displayState != newState else { return }
        self.displayState = newState
    }

    /// Ends a running check when the interface leaves portrait, the same way scene deactivation
    /// does. Deferred so the state change lands outside the view update.
    private func interruptCheckIfOrientationUnsupported() {
        guard orientationObserver.decision == .blockUntilPortrait,
              displayState == .displayingLiveness
        else { return }

        DispatchQueue.main.async {
            viewModel.endCheck(with: .viewResignation)
        }
    }

    /// Cancels from the rotate prompt through the state machine, like the close button, so a
    /// pending rotation interrupt finds the check already finished.
    private func cancelFromRotatePrompt() {
        viewModel.endCheck(with: .userCancelled)
    }

    /// Sets the screen to maximum brightness and stops it dimming or locking while the
    /// liveness views are shown, capturing the original settings once so they can be restored
    /// on exit. The screen's light is part of the check, and in a dark room it's the only
    /// light on the user's face, so the system dimming the screen would lose the face.
    private func setScreenForCheck() {
        DispatchQueue.main.async {
            if screenState.originalBrightness == nil {
                screenState.originalBrightness = UIScreen.main.brightness
            }
            if screenState.originalIsIdleTimerDisabled == nil {
                screenState.originalIsIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
            }
            UIScreen.main.brightness = 1.0
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }

    /// Restores the settings captured in `setScreenForCheck()`. Invoked when the view leaves
    /// the hierarchy, so it runs on every exit path (success, cancel, error).
    private func restoreScreen() {
        DispatchQueue.main.async {
            if let originalBrightness = screenState.originalBrightness {
                UIScreen.main.brightness = originalBrightness
                screenState.originalBrightness = nil
            }
            if let originalIsIdleTimerDisabled = screenState.originalIsIdleTimerDisabled {
                UIApplication.shared.isIdleTimerDisabled = originalIsIdleTimerDisabled
                screenState.originalIsIdleTimerDisabled = nil
            }
        }
    }

    func mapError(_ livenessError: LivenessStateMachine.LivenessError) -> FaceLivenessDetectionError {
        switch livenessError {
        case .userCancelled:
            return .userCancelled
        case .viewResignation:
            return .sessionInterrupted
        case .timedOut:
            return .faceInOvalMatchExceededTimeLimitError
        case .couldNotOpenStream, .socketClosed:
            return .socketClosed
        case .cameraNotAvailable:
            return .cameraNotAvailable
        default:
            return .cameraPermissionDenied
        }
    }

    private func requestCameraPermission(for challenge: Challenge) {
        AVCaptureDevice.requestAccess(
            for: .video,
            completionHandler: { accessGranted in
                guard accessGranted == true else { return }
                displayState = .awaitingLivenessSession(challenge)
            }
        )
    }

    private func alertCameraAccessNeeded() {
        displayingCameraPermissionsNeededAlert = true
    }
    
    private func checkCameraPermission(for challenge: Challenge) {
        let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch cameraAuthorizationStatus {
        case .notDetermined:
            requestCameraPermission(for: challenge)
        case .restricted, .denied:
            alertCameraAccessNeeded()
        case .authorized:
            displayState = .awaitingLivenessSession(challenge)
        @unknown default:
            break
        }
    }
}

enum DisplayState: Equatable {
    case awaitingChallengeType
    case awaitingCameraPermission(Challenge)
    case awaitingLivenessSession(Challenge)
    case displayingGetReadyView(Challenge, LivenessCamera)
    case displayingLiveness
    
    static func == (lhs: DisplayState, rhs: DisplayState) -> Bool {
        switch (lhs, rhs) {
        case (.awaitingChallengeType, .awaitingChallengeType):
            return true
        case (let .awaitingLivenessSession(c1), let .awaitingLivenessSession(c2)):
            return c1 == c2
        case (let .displayingGetReadyView(c1, position1), let .displayingGetReadyView(c2, position2)):
            return c1 == c2 && position1 == position2
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

public enum LivenessCamera {
    case front
    case back
}

public struct ChallengeOptions {
    let faceMovementChallengeOption: FaceMovementChallengeOption
    let faceMovementAndLightChallengeOption: FaceMovementAndLightChallengeOption
    
    public init(faceMovementChallengeOption: FaceMovementChallengeOption = .init(camera: .front),
                faceMovementAndLightChallengeOption: FaceMovementAndLightChallengeOption = .init()) {
        self.faceMovementChallengeOption = faceMovementChallengeOption
        self.faceMovementAndLightChallengeOption = faceMovementAndLightChallengeOption
    }

    /// The camera configured for `challenge`.
    func camera(for challenge: Challenge) -> LivenessCamera {
        switch challenge {
        case .faceMovementChallenge:
            return faceMovementChallengeOption.camera
        case .faceMovementAndLightChallenge:
            return faceMovementAndLightChallengeOption.camera
        }
    }
}

public struct FaceMovementChallengeOption {
    let challenge: Challenge
    let camera: LivenessCamera
    
    public init(camera: LivenessCamera) {
        self.challenge = .faceMovementChallenge("1.0.0")
        self.camera = camera
    }
}

public struct FaceMovementAndLightChallengeOption {
    let challenge: Challenge
    let camera: LivenessCamera
    
    public init() {
        self.challenge = .faceMovementAndLightChallenge("2.0.0")
        self.camera = .front
    }
}
