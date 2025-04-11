//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var sceneDelegate: SceneDelegate
    @State var sessionID = ""
    @State var isPresentingContainerView = false

    var body: some View {
        if isPresentingContainerView {
            ExampleLivenessView(
                sessionID: sessionID,
                isPresented: $isPresentingContainerView
            )
        } else {
            StartSessionView(
                sessionID: $sessionID,
                isPresentingContainerView: $isPresentingContainerView
            )
            .background(Color.dynamicColors(light: .white, dark: .secondarySystemBackground))
            .edgesIgnoringSafeArea(.all)
        }
    }
}
