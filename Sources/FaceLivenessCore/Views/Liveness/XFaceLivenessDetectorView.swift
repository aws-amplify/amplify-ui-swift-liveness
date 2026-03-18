//
//  XFaceLivenessDetectorView.swift
//  XFaceLiveness
//
//  Created by Ruslan Serebriakov on 3/17/26.
//  Copyright © 2026 X Corp. All rights reserved.
//

import SwiftUI
import UIKit
import AWSClientRuntime
import protocol AWSPluginsCore.AWSCredentialsProvider
import AWSPredictionsPlugin
import AVFoundation
import Amplify
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

public struct XFaceLivenessDetectorView: View {
    @StateObject var viewModel: FaceLivenessDetectionViewModel
    @Binding var isPresented: Bool
    @State var displayState: XDisplayState = .awaitingChallengeType
    @State var displayingCameraPermissionsNeededAlert = false

    let disableStartView: Bool
    let challengeOptions: ChallengeOptions
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
                completion: xMapDetectionCompletion(onCompletion)
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
                completion: xMapDetectionCompletion(onCompletion)
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
                videoChunker: captureSession.outputSampleBufferCapturer!.videoChunker,
                closeButtonAction: { onCompletion(.failure(.userCancelled)) },
                sessionID: sessionID,
                isPreviewScreenEnabled: !disableStartView,
                challengeOptions: challengeOptions
            )
        )
    }

    public var body: some View {
        switch displayState {
        case .awaitingChallengeType:
            XLoadingOverlayView()
            .onAppear {
                Task {
                    do {
                        let session = try await sessionTask.value
                        viewModel.livenessService = session
                        viewModel.registerServiceEvents(onChallengeTypeReceived: { challenge in
                            self.displayState = XDisplayState.awaitingCameraPermission(challenge)
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
            .onReceive(viewModel.$livenessState) { output in
                switch output.state {
                case .encounteredUnrecoverableError(let error):
                    let closeCode = error.webSocketCloseCode ?? .normalClosure
                    viewModel.livenessService?.closeSocket(with: closeCode)
                    isPresented = false
                    onCompletion(.failure(xMapError(error)))
                default:
                    break
                }
            }
        case .awaitingCameraPermission(let challenge):
            XLoadingOverlayView()
                .alert(isPresented: $displayingCameraPermissionsNeededAlert) {
                    Alert(
                        title: Text("Camera Access Required"),
                        message: Text("Please enable camera access in Settings to use Face Liveness."),
                        primaryButton: .default(Text("Settings")) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        },
                        secondaryButton: .cancel()
                    )
                }
                .onAppear {
                    checkCameraPermission(for: challenge)
                }
        case .awaitingLivenessSession:
            XLoadingOverlayView()
                .onAppear {
                    Task {
                        let newState = XDisplayState.displayingLiveness
                        guard self.displayState != newState else { return }
                        self.displayState = newState
                    }
                }
        case .displayingLiveness:
            XFaceLivenessDetectionView(
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
                    onCompletion(.failure(xMapError(error)))
                default:
                    break
                }
            }
        }
    }

    private func xMapError(_ livenessError: LivenessStateMachine.LivenessError) -> FaceLivenessDetectionError {
        switch livenessError {
        case .userCancelled, .viewResignation:
            return .userCancelled
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

// MARK: - X Loading Overlay View

/// A dark-themed loading view that shows the same UI as the detection view
/// (oval cutout with instruction pill) to ensure smooth visual transition
struct XLoadingOverlayView: View {
    private let ovalWidth: CGFloat = 250
    private let ovalHeight: CGFloat = 344
    
    var body: some View {
        GeometryReader { geometry in
            let ovalCenter = CGPoint(
                x: geometry.size.width / 2,
                y: geometry.size.height * 0.42
            )
            let ovalSize = CGSize(width: ovalWidth, height: ovalHeight)
            let ovalTopY = ovalCenter.y - ovalHeight / 2
            
            ZStack {
                // Black background
                Color.black
                    .ignoresSafeArea()
                
                // Dark overlay with oval cutout
                XOvalCutoutOverlay(ovalSize: ovalSize, ovalCenter: ovalCenter)
                    .fill(Color.black, style: FillStyle(eoFill: true))
                
                // White oval stroke
                Ellipse()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: ovalWidth, height: ovalHeight)
                    .position(ovalCenter)
                
                // Instruction pill - positioned 30px above the oval
                Text("Put your face in the circle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.white))
                    .position(x: geometry.size.width / 2, y: ovalTopY - 30)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - X Display State

enum XDisplayState: Equatable {
    case awaitingChallengeType
    case awaitingCameraPermission(Challenge)
    case awaitingLivenessSession(Challenge)
    case displayingLiveness

    static func == (lhs: XDisplayState, rhs: XDisplayState) -> Bool {
        switch (lhs, rhs) {
        case (.awaitingChallengeType, .awaitingChallengeType):
            return true
        case (let .awaitingLivenessSession(c1), let .awaitingLivenessSession(c2)):
            return c1 == c2
        case (.displayingLiveness, .displayingLiveness):
            return true
        case (.awaitingCameraPermission, .awaitingCameraPermission):
            return true
        default:
            return false
        }
    }
}

// MARK: - Helper

private func xMapDetectionCompletion(_ detectionCompletion: @escaping (Result<Void, FaceLivenessDetectionError>) -> Void) -> ((Result<Void, FaceLivenessSessionError>) -> Void) {
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
