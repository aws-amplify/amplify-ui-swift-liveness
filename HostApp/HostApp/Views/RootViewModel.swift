//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
import Amplify

class RootViewModel: ObservableObject {
    @MainActor @Published var sessionID = ""
    @Published var isPresentingContainerView = false

    func createSession() {
        Task { @MainActor in
            let request = RESTRequest(
                apiName: "liveness",
                path: "/liveness/create"
            )

            do {
                let data = try await Amplify.API.post(request: request)
                let response = try JSONDecoder().decode(
                    CreateSessionResponse.self,
                    from: data
                )
                sessionID = response.sessionId
                isPresentingContainerView = true
            } catch {
                print("Error creating session", error)
            }
        }
    }

    func setup(_ window: UIWindow?) {
        Task {
            let session = try await Amplify.Auth.fetchAuthSession()
            if session.isSignedIn {
                createSession()
            } else {
                let signInResult = try await Amplify.Auth.signInWithWebUI(
                    presentationAnchor: window!
                )
                if signInResult.isSignedIn {
                    createSession()
                } else {
                    setup(window)
                }
            }
        }
    }
}
