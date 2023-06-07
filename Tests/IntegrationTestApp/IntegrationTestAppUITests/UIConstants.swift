//
//  UIConstants.swift
//  HostAppUITests
//
//  Created by Pham, Tuan on 6/1/23.
//
struct UIConstants {
    struct BeginCheck {
        static let primaryButton = "Begin Check"
        static let description = "You will go through a face verification process to prove that you are a real person. Your screen's brightness will temporarily be set to 100% for highest accuracy."
        static let warning = "Photosensitivity Warning, This check displays colored lights. Use caution if you are photosensitive."
        static let instruction = "Follow the instructions to complete the check:"
    }

    struct LivenessCheck {
        static let countdownInstruction = "Hold face position during countdown."
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

