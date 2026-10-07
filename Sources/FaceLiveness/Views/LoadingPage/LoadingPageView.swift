//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct LoadingPageView: View {
    @Environment(\.faceLivenessDetectorTheme) private var theme

    var body: some View {
        VStack {
            HStack(spacing: 5) {
                // `.tint(_:)` doesn't color the circular style on iOS 15
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: theme.colors.primary))
                Text(LocalizedStrings.challenge_connecting)
                    .font(theme.fonts.body)
                    .foregroundColor(theme.colors.onBackground)
            }
        }
    }
}

struct LoadingPageView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingPageView()
    }
}
