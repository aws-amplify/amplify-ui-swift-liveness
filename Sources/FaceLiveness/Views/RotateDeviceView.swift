//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

/// Shown in place of the liveness flow while the interface is not portrait. Unless the app hides
/// it, the close button is the only exit for a host that supports landscape only.
struct RotateDeviceView: View {
    var cancelButtonOptions = CancelButtonOptions()
    @Environment(\.faceLivenessDetectorTheme) private var theme
    let onClose: () -> Void

    var body: some View {
        ZStack {
            theme.colors.background
                .edgesIgnoringSafeArea(.all)

            VStack {
                HStack {
                    Spacer()
                    CancelButton(options: cancelButtonOptions, action: onClose)
                }
                .padding()

                Spacer()

                VStack {
                    Text(LocalizedStrings.orientation_prompt_title)
                        .font(theme.fonts.title2)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                        .padding(8)

                    Text(LocalizedStrings.orientation_prompt_description)
                        .font(theme.fonts.body)
                        .multilineTextAlignment(.center)
                        .padding(8)
                }
                .foregroundColor(theme.colors.onBackground)
                .padding()

                Spacer()
            }
        }
    }
}

struct RotateDeviceView_Previews: PreviewProvider {
    static var previews: some View {
        RotateDeviceView(onClose: {})
    }
}
