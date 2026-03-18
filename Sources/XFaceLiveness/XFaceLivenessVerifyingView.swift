//
//  XFaceLivenessVerifyingView.swift
//  XFaceLiveness
//
//  Created by Ruslan Serebriakov on 3/17/26.
//  Copyright © 2026 X Corp. All rights reserved.
//

import SwiftUI

struct XFaceLivenessVerifyingView: View {

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)

                Text("Verifying you are a human...")
                    .font(.system(size: 17))
                    .foregroundColor(.white)
            }
        }
        .preferredColorScheme(.dark)
    }
}