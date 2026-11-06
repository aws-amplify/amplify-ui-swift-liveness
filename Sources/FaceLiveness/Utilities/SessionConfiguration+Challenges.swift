//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

extension FaceLivenessSession.SessionConfiguration {
    var ovalMatchChallenge: FaceLivenessSession.OvalMatchChallenge {
        switch self {
        case .faceMovement(let challenge):
            return challenge
        case .faceMovementAndLight(_, let challenge):
            return challenge
        }
    }

    /// The colors to display, for a face movement and light challenge.
    var colorChallenge: FaceLivenessSession.ColorChallenge? {
        switch self {
        case .faceMovement:
            return nil
        case .faceMovementAndLight(let challenge, _):
            return challenge
        }
    }
}
