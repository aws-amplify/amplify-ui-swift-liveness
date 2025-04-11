//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
import Amplify
import Foundation

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
                //print("the session")
                //print(session)
                //print("okok")
                presentationState = session.isSignedIn
                ? .signedIn(action: signOut)
                : .signedOut(action: signIn)
            } catch {
                presentationState = .signedOut(action: signIn)
                print("Error fetching auth session", error)
            }

        }
    }
    
    struct StartResponse: Codable {
        let sid: String
    }

    func createSession(_ completion: @escaping (String?, Error?) -> Void) {
        Task { @MainActor in
            let currentPresentationState = presentationState
            presentationState = .loading

            do {
                // Configura la URL y la petición
                guard let url = URL(string: "https://c18b-181-236-137-100.ngrok-free.app/liveness/start") else {
                    throw URLError(.badURL)
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                // Si necesitas enviar un body (en este ejemplo se envía un JSON vacío)
                let body: [String: Any] = [:]
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                
                // Realiza la llamada asíncrona al API
                let (data, _) = try await URLSession.shared.data(for: request)
                
                // Decodifica la respuesta JSON y extrae el sId
                let decoder = JSONDecoder()
                let startResponse = try decoder.decode(StartResponse.self, from: data)
                print("respone: \(startResponse)")
                let sessionId = startResponse.sid
                
                presentationState = currentPresentationState
                completion(sessionId, nil)
            } catch {
                presentationState = currentPresentationState
                print("Error creating session:", error)
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
