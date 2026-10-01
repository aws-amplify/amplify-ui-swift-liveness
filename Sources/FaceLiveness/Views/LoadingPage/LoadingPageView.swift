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
                ProgressView()
                    .tint(theme.colors.primary)
                Text(LocalizedStrings.challenge_connecting)
                    .font(theme.fonts.body)
                    .foregroundColor(theme.colors.onBackground)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colors.background.edgesIgnoringSafeArea(.all))
    }
}

struct LoadingPageView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingPageView()
    }
}
