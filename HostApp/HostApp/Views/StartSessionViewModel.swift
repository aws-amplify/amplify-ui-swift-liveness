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
            do {
                let session = try await Amplify.Auth.fetchAuthSession()
                presentationState = session.isSignedIn
                ? .signedIn(action: signOut)
                : .signedOut(action: signIn)
            } catch {
                presentationState = .signedOut(action: signIn)
                print("Error fetching auth session", error)
            }

        }
    }

    func createSession(_ completion: @escaping (String?, Error?) -> Void) {
        Task { @MainActor in
            let currentPresentationState = presentationState
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
                presentationState = currentPresentationState
                completion(response.sessionId, nil)
            } catch {
                presentationState = currentPresentationState
                print("Error creating session", error)
                completion(nil, error)
            }
        }
    }

    func signIn() {
        Task { @MainActor in
            presentationState = .loading
            do {
                let signInResult = try await Amplify.Auth.signInWithWebUI(presentationAnchor: window)
                if signInResult.isSignedIn {
                    presentationState = .signedIn(action: signOut)
                }
            } catch {
                print("Error signing in with web UI", error)
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
