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
    @Binding var isPresentingContainerView: Bool

    var body: some View {
        VStack {
            Spacer()
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
                    viewModel.createSession {
                        sessionID = $0
                        isPresentingContainerView = true
                    }
                },
                enabled: true
            )

            Spacer()
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

