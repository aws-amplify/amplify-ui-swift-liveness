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
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(LivenessThemeOption.storageKey) private var themeOption = LivenessThemeOption.standard

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
                challengeOptions: .init(faceMovementChallengeOption: FaceMovementChallengeOption(camera: camera)),
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
                        case .failure(.sessionInterrupted):
                            // The check was interrupted (e.g. incoming call, backgrounding)
                            // rather than deliberately cancelled.
                            viewModel.presentationState = .error(.sessionInterrupted)
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
                        case .failure(.validation):
                            viewModel.presentationState = .error(.validation)
                        case .failure(.faceInOvalMatchExceededTimeLimitError):
                            viewModel.presentationState = .error(.faceInOvalMatchExceededTimeLimitError)
                        case .failure(_):
                            viewModel.presentationState = .error(.unknown)
                        }
                    }
                }
            )
            .faceLivenessDetectorTheme(themeOption.theme(for: colorScheme))
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
                    case .faceInOvalMatchExceededTimeLimitError:
                        LivenessCheckErrorContentView.faceMatchTimeOut
                    case .countdownNoFace, .countdownFaceTooClose, .countdownMultipleFaces:
                        LivenessCheckErrorContentView.failedDuringCountdown
                    case .invalidSignature:
                        LivenessCheckErrorContentView.invalidSignature
                    case .cameraNotAvailable:
                        LivenessCheckErrorContentView.cameraNotAvailable
                    case .validation:
                        LivenessCheckErrorContentView.validation
                    case .sessionInterrupted:
                        LivenessCheckErrorContentView.sessionInterrupted
                    default:
                        LivenessCheckErrorContentView.unexpected
                    }
                }
            )
            .animation(.default, value: viewModel.presentationState)
        }
    }
}

/// The theme applied to the liveness views, picked on the start screen.
enum LivenessThemeOption: String, CaseIterable, Identifiable {
    case standard = "Default"
    case brand = "Brand"

    static let storageKey = "livenessThemeOption"

    var id: Self { self }

    /// Returns the same instance for the same option and appearance, so the liveness views only
    /// update when one of them changes. Passing a new instance is what updates them: switching the
    /// device between light and dark mode during a check re-themes the check straight away.
    @MainActor
    func theme(for colorScheme: ColorScheme) -> FaceLivenessDetectorTheme {
        switch self {
        case .standard:
            return LivenessThemes.standard
        case .brand:
            return colorScheme == .dark ? LivenessThemes.brandDark : LivenessThemes.brandLight
        }
    }
}

@MainActor
private enum LivenessThemes {
    /// Follows the system appearance by itself, so it never needs replacing.
    static let standard = FaceLivenessDetectorTheme()
    static let brandLight = brand(for: .light)
    static let brandDark = brand(for: .dark)

    /// Starts from the given appearance's default colors and overrides the brand's.
    private static func brand(for colorScheme: ColorScheme) -> FaceLivenessDetectorTheme {
        let theme = FaceLivenessDetectorTheme(colorScheme: colorScheme)
        let isDark = colorScheme == .dark
        theme.colors.primary = isDark ? .hex("#C9A7F5") : .hex("#5B2C83")
        theme.colors.onPrimary = isDark ? .hex("#1A0B2E") : .white
        theme.colors.error = isDark ? .hex("#FFB4AB") : .hex("#B3261E")
        theme.colors.onError = isDark ? .hex("#690005") : .white
        // A smaller instruction font, so longer translations fit on one line
        theme.fonts.title = .title2.weight(.semibold)
        return theme
    }
}
