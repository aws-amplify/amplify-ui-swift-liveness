//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var sceneDelegate: SceneDelegate
    @StateObject var viewModel = RootViewModel()

    var body: some View {
        if viewModel.isPresentingContainerView {
            ExampleLivenessView(
                sessionID: viewModel.sessionID,
                isPresented: $viewModel.isPresentingContainerView
            )
        } else {
            StartSessionView(
                sessionID: $viewModel.sessionID,
                isPresentingContainerView: $viewModel.isPresentingContainerView
            )
            .background(Color.dynamicColors(light: .white, dark: .secondarySystemBackground))
            .edgesIgnoringSafeArea(.all)
        }
    }
}
