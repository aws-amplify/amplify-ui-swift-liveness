//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

struct LivenessResult: Codable {
    let auditImageBytes: String?
    let confidenceScore: Double
    let isLive: Bool
}

extension LivenessResult: CustomDebugStringConvertible {
    var debugDescription: String {
        """
        LivenessResult
            - confidenceScore: \(confidenceScore)
            - isLive: \(isLive)
            - auditImageBytes: \(auditImageBytes == nil ? "nil" : "<placeholder>")
        """
    }
}
