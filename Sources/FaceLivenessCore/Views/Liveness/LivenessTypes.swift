//
//  LivenessTypes.swift
//  FaceLivenessCore
//
//  Extracted from FaceLivenessDetectionView.swift
//
//  Copyright Amazon.com Inc. or its affiliates.
//  All Rights Reserved.
//
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

public enum LivenessCamera {
    case front
    case back
}

public struct ChallengeOptions {
    let faceMovementChallengeOption: FaceMovementChallengeOption
    let faceMovementAndLightChallengeOption: FaceMovementAndLightChallengeOption

    public init(faceMovementChallengeOption: FaceMovementChallengeOption = .init(camera: .front),
                faceMovementAndLightChallengeOption: FaceMovementAndLightChallengeOption = .init()) {
        self.faceMovementChallengeOption = faceMovementChallengeOption
        self.faceMovementAndLightChallengeOption = faceMovementAndLightChallengeOption
    }
}

public struct FaceMovementChallengeOption {
    let challenge: Challenge
    let camera: LivenessCamera

    public init(camera: LivenessCamera) {
        self.challenge = .faceMovementChallenge("1.0.0")
        self.camera = camera
    }
}

public struct FaceMovementAndLightChallengeOption {
    let challenge: Challenge
    let camera: LivenessCamera

    public init() {
        self.challenge = .faceMovementAndLightChallenge("2.0.0")
        self.camera = .front
    }
}