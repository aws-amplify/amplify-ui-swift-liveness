//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
import FaceLiveness

struct RootView: View {
    @EnvironmentObject var sceneDelegate: SceneDelegate
    @State var sessionID = ""
    @State var containerViewState = ContainerViewState.startSession

    var body: some View {
        switch containerViewState {
        case .liveness:
            ExampleLivenessView(
                sessionID: sessionID,
                containerViewState: $containerViewState
            )
        case .startSession:
            StartSessionView(
                sessionID: $sessionID,
                containerViewState: $containerViewState
            )
            .background(Color.dynamicColors(light: .white, dark: .secondarySystemBackground))
            .edgesIgnoringSafeArea(.all)
        }
    }
}

enum ContainerViewState: Hashable {
    case liveness(LivenessCamera)
    case startSession
}
