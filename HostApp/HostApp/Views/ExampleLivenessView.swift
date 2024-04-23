//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
import FaceLiveness

struct ExampleLivenessView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: ExampleLivenessViewModel

    init(sessionID: String, isPresented: Binding<Bool>) {
        self.viewModel = .init(sessionID: sessionID)
        self._isPresented = isPresented
    }

    var body: some View {
        switch viewModel.presentationState {
        case .liveness:
            FaceLivenessDetectorView(
                sessionID: viewModel.sessionID,
                region: "us-east-1",
                isPresented:  Binding(
                    get: { viewModel.presentationState == .liveness },
                    set: { _ in }
                ),
                onCompletion: { result in
                    switch result {
                    case .success:
                        withAnimation { viewModel.presentationState = .result }
                    case .failure(.sessionNotFound), .failure(.cameraPermissionDenied), .failure(.accessDenied):
                        viewModel.presentationState = .liveness
                        isPresented = false
                    case .failure(.userCancelled):
                        viewModel.presentationState = .liveness
                        isPresented = false
                    case .failure(.sessionTimedOut):
                        viewModel.presentationState = .error(.sessionTimedOut)
                    case .failure(.socketClosed):
                        viewModel.presentationState = .error(.socketClosed)
                    case .failure(.countdownNoFace), .failure(.countdownFaceTooClose), .failure(.countdownMultipleFaces):
                        viewModel.presentationState = .error(.countdownFaceTooClose)
                    case .failure(.invalidSignature):
                        viewModel.presentationState = .error(.invalidSignature)
                    default:
                        viewModel.presentationState = .liveness
                    }
                }
            )
            .id(isPresented)
        case .result:
            LivenessResultView(
                sessionID: viewModel.sessionID,
                onTryAgain: { isPresented = false },
                content: {
                    LivenessResultContentView(fetchResults: viewModel.fetchLivenessResult)
                }
            )
            .animation(.default, value: viewModel.presentationState)
        case .error(let detectionError):
            LivenessResultView(
                sessionID: viewModel.sessionID,
                onTryAgain: { isPresented = false },
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
                    default:
                        LivenessCheckErrorContentView.unexpected
                    }
                }
            )
            .animation(.default, value: viewModel.presentationState)
        }
    }
}
