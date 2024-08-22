//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

struct LivenessResult: Codable {
    let auditImageBytes: String?
    let confidenceScore: Double
    let isLive: Bool
    let challenge: Challenge?
}

extension LivenessResult: CustomDebugStringConvertible {
    var debugDescription: String {
        """
        LivenessResult
            - confidenceScore: \(confidenceScore)
            - isLive: \(isLive)
            - auditImageBytes: \(auditImageBytes == nil ? "nil" : "<placeholder>")
            - challengeType: \(String(describing: challenge?.type))
            - challengeVersion: \(String(describing: challenge?.version))
        """
    }
}
