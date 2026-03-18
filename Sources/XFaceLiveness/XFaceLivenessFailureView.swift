//
//  XFaceLivenessFailureView.swift
//  XFaceLiveness
//
//  Created by Ruslan Serebriakov on 3/17/26.
//  Copyright © 2026 X Corp. All rights reserved.
//

import SwiftUI

struct XFaceLivenessFailureView: View {

    let isSecondAttempt: Bool
    let onTryAgain: () -> Void
    let onGetHelp: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    closeButton
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                }

                Spacer()

                errorIcon
                    .padding(.bottom, 20)

                titleText
                    .padding(.bottom, 8)

                subtitleText

                Spacer()

                actionButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, isSecondAttempt ? 12 : 16)

                if isSecondAttempt {
                    helpCenterLink
                        .padding(.bottom, 16)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.1))
                .clipShape(Circle())
        }
    }

    private var errorIcon: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.15))
                .frame(width: 56, height: 56)

            Image(systemName: "xmark")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.red)
        }
    }

    private var titleText: some View {
        let title = isSecondAttempt ? "Let's try that again" : "Verification failed"
        return Text(title)
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
    }

    private var subtitleText: some View {
        Text("We couldn't verify you're human.")
            .font(.system(size: 15))
            .foregroundColor(Color.white.opacity(0.6))
            .multilineTextAlignment(.center)
    }

    private var actionButton: some View {
        Group {
            if isSecondAttempt {
                getHelpButton
            } else {
                tryAgainButton
            }
        }
    }

    private var tryAgainButton: some View {
        Button(action: onTryAgain) {
            Text("Try again")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        }
    }

    private var getHelpButton: some View {
        Button(action: onGetHelp) {
            Text("Get Help")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 25))
        }
    }

    private var helpCenterLink: some View {
        Button(action: onGetHelp) {
            Text("Help Center: Appeal a suspended account")
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.4))
        }
    }
}
