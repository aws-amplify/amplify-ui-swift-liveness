//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
import FaceLiveness
import Amplify

class ExampleLivenessViewModel: ObservableObject {
    @Published var presentationState = PresentationState.liveness
    let sessionID: String

    init(sessionID: String) {
        self.sessionID = sessionID
    }

    func fetchLivenessResult() async throws -> LivenessResultContentView.Result {
        guard let url = URL(string: "https://c18b-181-236-137-100.ngrok-free.app/liveness/result/\(sessionID)") else {
            throw URLError(.badURL)
        }
        
        // Configura la petición GET
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Realiza la llamada asíncrona al endpoint
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Decodifica la respuesta en el modelo LivenessResultContentView.Result
        let livenessResult = try JSONDecoder().decode(LivenessResult.self, from: data)
        let score = LivenessResultContentView.Result(livenessResult: livenessResult)
        return score
    }

    enum PresentationState: Equatable {
        case liveness, result, error(FaceLivenessDetectionError)
    }
}
