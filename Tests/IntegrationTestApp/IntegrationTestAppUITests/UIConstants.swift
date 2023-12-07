//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

struct UIConstants {
    static let appName = "IntegrationTestApp"
    static let primaryButton = "Create Liveness Session"
 
    struct BeginCheck {
        static let primaryButton = "Start video check"
        static let warningTitle = "Photosensitivity Warning"
        static let warningDescription = "This check flashes different colors. Use caution if you are photosensitive."
        static let instruction = "Center your face"
    }

    struct LivenessCheck {
        static let moveInstruction = "Move closer"
        static let holdInstruction = "Hold still"
        static let closeButton = "Close"
    }

    struct LivenessResult {
        static let result = "Result:"
        static let confidence = "Liveness confidence score:"
        static let primaryButton = "Try Again"
    }
}

