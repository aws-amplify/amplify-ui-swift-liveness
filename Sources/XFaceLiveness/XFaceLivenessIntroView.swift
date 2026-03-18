//
//  XFaceLivenessIntroView.swift
//  XFaceLiveness
//
//  Created by Ruslan Serebriakov on 3/17/26.
//  Copyright © 2026 X Corp. All rights reserved.
//

import SwiftUI

struct XFaceLivenessIntroView: View {

    let onTakeSelfie: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                scanIcon
                    .padding(.bottom, 24)

                titleText
                    .padding(.bottom, 12)

                descriptionText
                    .padding(.horizontal, 32)

                Spacer()

                photosNotSavedLabel
                    .padding(.bottom, 16)

                takeSelfieButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var scanIcon: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                .frame(width: 64, height: 64)

            Image(systemName: "faceid")
                .font(.system(size: 28))
                .foregroundColor(.white)
        }
    }

    private var titleText: some View {
        Text("Let's confirm you are\nhuman")
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
    }

    private var descriptionText: some View {
        Text("A selfie is required. This step verifies that you are human and ensures your account remains in good standing.")
            .font(.system(size: 15))
            .foregroundColor(Color.white.opacity(0.6))
            .multilineTextAlignment(.center)
    }

    private var photosNotSavedLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.4))

            Text("Photos are not saved")
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.4))
        }
    }

    private var takeSelfieButton: some View {
        Button(action: onTakeSelfie) {
            Text("Take selfie")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 25))
        }
    }
}
