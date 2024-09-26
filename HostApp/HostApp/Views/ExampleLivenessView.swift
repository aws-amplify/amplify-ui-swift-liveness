//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
import FaceLiveness

struct ExampleLivenessView: View {
    @Binding var containerViewState: ContainerViewState
    @ObservedObject var viewModel: ExampleLivenessViewModel

    init(sessionID: String, containerViewState: Binding<ContainerViewState>) {
        self._containerViewState = containerViewState
        if case let .liveness(selectedCamera) = _containerViewState.wrappedValue {
            self.viewModel = .init(sessionID: sessionID, presentationState: .liveness(selectedCamera))
        } else {
            self.viewModel = .init(sessionID: sessionID)
        }
    }

    var body: some View {
        switch viewModel.presentationState {
        case .liveness(let camera):
            FaceLivenessDetectorView(
                sessionID: viewModel.sessionID,
                region: "us-east-1",
                challengeOptions: .init(faceMovementChallengeOption: FaceMovementChallengeOption(camera: camera),
                                        faceMovementAndLightChallengeOption: FaceMovementAndLightChallengeOption()),
                isPresented:  Binding(
                    get: { viewModel.presentationState == .liveness(camera) },
                    set: { _ in }
                ),
                onCompletion: { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            withAnimation { viewModel.presentationState = .result }
                        case .failure(.sessionNotFound), .failure(.cameraPermissionDenied), .failure(.accessDenied):
                            viewModel.presentationState = .liveness(camera)
                            containerViewState = .startSession
                        case .failure(.userCancelled):
                            viewModel.presentationState = .liveness(camera)
                            containerViewState = .startSession
                        case .failure(.sessionTimedOut):
                            viewModel.presentationState = .error(.sessionTimedOut)
                        case .failure(.socketClosed):
                            viewModel.presentationState = .error(.socketClosed)
                        case .failure(.countdownNoFace), .failure(.countdownFaceTooClose), .failure(.countdownMultipleFaces):
                            viewModel.presentationState = .error(.countdownFaceTooClose)
                        case .failure(.invalidSignature):
                            viewModel.presentationState = .error(.invalidSignature)
                        case .failure(.faceInOvalMatchExceededTimeLimitError):
                            viewModel.presentationState = .error(.faceInOvalMatchExceededTimeLimitError)
                        case .failure(.internalServer):
                            viewModel.presentationState = .error(.internalServer)
                        case .failure(.cameraNotAvailable):
                            viewModel.presentationState = .error(.cameraNotAvailable)
                        default:
                            viewModel.presentationState = .liveness(camera)
                        }
                    }
                }
            )
            .id(containerViewState)
        case .result:
            LivenessResultView(
                sessionID: viewModel.sessionID,
                onTryAgain: { containerViewState = .startSession },
                content: {
                    LivenessResultContentView(fetchResults: viewModel.fetchLivenessResult)
                }
            )
            .animation(.default, value: viewModel.presentationState)
        case .error(let detectionError):
            LivenessResultView(
                sessionID: viewModel.sessionID,
                onTryAgain: { containerViewState = .startSession },
                content: {
                    switch detectionError {
                    case .socketClosed:
                        LivenessCheckErrorContentView.sessionTimeOut
                    case .sessionTimedOut:
                        LivenessCheckErrorContentView.faceMatchTimeOut
                    case .countdownNoFace, .countdownFaceTooClose, .countdownMultipleFaces:
                        LivenessCheckErrorContentView.failedDuringCountdown
                    case .invalidSignature:
                        LivenessCheckErrorContentView.invalidSignature
                    case .cameraNotAvailable:
                        LivenessCheckErrorContentView.cameraNotAvailable
                    default:
                        LivenessCheckErrorContentView.unexpected
                    }
                }
            )
            .animation(.default, value: viewModel.presentationState)
        }
    }
}
