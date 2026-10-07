//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
import Amplify

struct StartSessionView: View {
    @EnvironmentObject var sceneDelegate: SceneDelegate
    @ObservedObject var viewModel = StartSessionViewModel()
    @Binding var sessionID: String
    @Binding var containerViewState: ContainerViewState
    @State private var showAlert = false
    @AppStorage(LivenessThemeOption.storageKey) private var themeOption = LivenessThemeOption.standard
    @AppStorage(LivenessChallengeOption.storageKey) private var challengeOption = LivenessChallengeOption.light

    var body: some View {
        VStack {
            Spacer()
            Picker("Liveness theme", selection: $themeOption) {
                ForEach(LivenessThemeOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Picker("Liveness challenge", selection: $challengeOption) {
                ForEach(LivenessChallengeOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding([.leading, .trailing, .bottom])

            button(
                text: viewModel.presentationState.buttonText,
                backgroundColor: viewModel.presentationState.buttonBackgroundColor,
                action: viewModel.presentationState.buttonAction,
                enabled: viewModel.presentationState.buttonEnabled
            )

            button(
                text: "Create Liveness Session",
                backgroundColor: .dynamicColors(
                    light: .hex("#047D95"),
                    dark: .hex("#7dd6e8")
                ),
                action: {
                    viewModel.createSession(challenge: challengeOption) { sessionId, err in
                        if let sessionId = sessionId {
                            sessionID = sessionId
                            // modify camera preference for `FaceMovementChallenge`
                            containerViewState = .liveness(.front)
                        }

                        showAlert = err != nil
                    }
                },
                enabled: viewModel.isSignedIn
            )
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Error Creating Liveness Session"),
                    message: Text("Unable to create a liveness session id.  Please try again."),
                    dismissButton: .default(
                                    Text("OK"),
                                    action: {
                                        containerViewState = .startSession
                                    }
                    )
                )
            }

            Spacer()
            HStack {
                Spacer()
                Text("v0.1.19")
                    .font(.callout)
                    .padding()
            }
            .padding()
        }
        .onAppear { viewModel.setup() }
    }

    func button(
        text: String,
        backgroundColor: Color,
        action: @escaping () -> Void,
        enabled: Bool
    ) -> some View {
        Button(
            action: action,
            label: {
                Text(text)
                    .foregroundColor(.dynamicColors(light: .white, dark: .black))
                    .frame(maxWidth: .infinity)
            }
        )
        .frame(height: 52)
        ._background {
            backgroundColor.opacity(enabled ? 1.0 : 0.6)
        }
        .cornerRadius(14)
        .padding(.leading)
        .padding(.trailing)
        .padding(.bottom, 16)
        .disabled(!enabled)
    }
}

/// The challenge the next session is created with, picked on the start screen.
enum LivenessChallengeOption: String, CaseIterable, Identifiable {
    case light = "Light"
    case noLight = "No light"

    static let storageKey = "livenessChallengeOption"

    var id: Self { self }

    /// The challenge type the backend lists as the session's only challenge preference.
    var challengeType: String {
        switch self {
        case .light:
            return "FaceMovementAndLightChallenge"
        case .noLight:
            return "FaceMovementChallenge"
        }
    }
}
