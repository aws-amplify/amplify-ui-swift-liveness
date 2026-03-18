//
//  XFaceLivenessFlowView.swift
//  XFaceLiveness
//
//  Created by Ruslan Serebriakov on 3/17/26.
//  Copyright © 2026 X Corp. All rights reserved.
//

import SwiftUI

enum XFaceLivenessFlowState {
    case intro
    case liveness
    case verifying
    case failure(attempt: Int)
}

struct XFaceLivenessFlowView: View {

    let sessionID: String
    let region: String
    let onSuccess: () -> Void
    let onDismiss: () -> Void

    @State private var flowState: XFaceLivenessFlowState = .intro
    @State private var attemptCount = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch flowState {
            case .intro:
                XFaceLivenessIntroView(onTakeSelfie: startLivenessCheck)
                    .transition(.opacity)

            case .liveness:
                XFaceLivenessDetectorWrapper(
                    sessionID: sessionID,
                    region: region,
                    onSuccess: handleLivenessSDKSuccess,
                    onFailure: handleFailure
                )
                .transition(.opacity)

            case .verifying:
                XFaceLivenessVerifyingView()
                    .transition(.opacity)

            case .failure(let attempt):
                XFaceLivenessFailureView(
                    isSecondAttempt: attempt >= 2,
                    onTryAgain: retryLivenessCheck,
                    onGetHelp: openHelpCenter,
                    onDismiss: onDismiss
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: stateKey)
    }

    private var stateKey: String {
        switch flowState {
        case .intro: return "intro"
        case .liveness: return "liveness"
        case .verifying: return "verifying"
        case .failure(let attempt): return "failure-\(attempt)"
        }
    }

    private func startLivenessCheck() {
        attemptCount += 1
        flowState = .liveness
    }

    /// Called when the AWS SDK finishes capturing — now validate server-side
    private func handleLivenessSDKSuccess() {
        guard let validator = XFaceLivenessStartup.resultsValidator else {
            // No validator provided — treat SDK success as final success
            onSuccess()
            return
        }

        // Show verifying screen while we poll the backend
        flowState = .verifying

        validator(sessionID) { succeeded in
            DispatchQueue.main.async {
                if succeeded {
                    onSuccess()
                } else {
                    flowState = .failure(attempt: attemptCount)
                }
            }
        }
    }

    private func handleFailure() {
        flowState = .failure(attempt: attemptCount)
    }

    private func retryLivenessCheck() {
        attemptCount += 1
        flowState = .liveness
    }

    private func openHelpCenter() {
        let helpURL = URL(string: "https://help.x.com/en/rules-and-policies/account-restoration")
        if let helpURL {
            UIApplication.shared.open(helpURL)
        }
    }
}
