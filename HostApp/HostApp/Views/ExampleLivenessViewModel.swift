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
    @Published var presentationState: PresentationState = .liveness(.front)
    let sessionID: String

    init(sessionID: String, presentationState: PresentationState = .liveness(.front)) {
        self.sessionID = sessionID
        self.presentationState = presentationState
    }

    func fetchLivenessResult() async throws -> LivenessResultContentView.Result {
        let request = RESTRequest(
            apiName: "liveness",
            path: "/liveness/\(sessionID)"
        )

        let data = try await Amplify.API.get(request: request)
        let result = try JSONDecoder().decode(LivenessResult.self, from: data)
        let score = LivenessResultContentView.Result(livenessResult: result)
        return score
    }

    enum PresentationState: Equatable {
        case liveness(LivenessCamera), result, error(FaceLivenessDetectionError)
    }
}
