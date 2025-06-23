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
    let challenge: Event?
}

extension LivenessResult: CustomDebugStringConvertible {
    var debugDescription: String {
        """
        LivenessResult
            - confidenceScore: \(confidenceScore)
            - isLive: \(isLive)
            - auditImageBytes: \(auditImageBytes == nil ? "nil" : "<placeholder>")
            - challenge: type: \(String(describing: challenge?.type)) + " version: " + \(String(describing: challenge?.version))
        """
    }
}

struct Event: Codable {
    let version: String
    let type: ChallengeType

    enum CodingKeys: String, CodingKey {
        case version = "Version"
        case type = "Type"
    }
}
