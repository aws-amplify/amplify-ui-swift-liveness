//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
import Amplify

class StartSessionViewModel: ObservableObject {
    @Published var presentationState: StartSessionView.PresentationState = .loading
    var window: UIWindow?

    var isSignedIn: Bool {
        presentationState == .signedIn {}
    }

    func setup() {
        Task { @MainActor in
            presentationState = .loading
            let session = try await Amplify.Auth.fetchAuthSession()
            presentationState = session.isSignedIn
            ? .signedIn(action: signOut)
            : .signedOut(action: signIn)
        }
    }

    func createSession(_ completion: @escaping (String) -> Void) {
        Task { @MainActor in
            presentationState = .loading
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
                completion(response.sessionId)
            } catch {
                print("Error creating session", error)
            }
        }
    }

    func signIn() {
        Task { @MainActor in
            presentationState = .loading
            let signInResult = try await Amplify.Auth.signInWithWebUI(
                presentationAnchor: window
            )
            if signInResult.isSignedIn {
                presentationState = .signedIn(action: signOut)
            }
        }
    }

    func signOut() {
        Task { @MainActor in
            presentationState = .loading
            _ = await Amplify.Auth.signOut()
            presentationState = .signedOut(action: signIn)
        }
    }
}
