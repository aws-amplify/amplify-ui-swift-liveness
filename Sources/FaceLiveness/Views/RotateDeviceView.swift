//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

/// Shown in place of the liveness flow while the interface is not portrait.
///
/// The check only supports portrait (see `LivenessOrientation`), so this asks the user to
/// rotate rather than showing a sideways camera feed. The close button is not optional: a
/// host that only supports landscape would otherwise leave the user with no way out.
struct RotateDeviceView: View {
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.livenessBackground
                .edgesIgnoringSafeArea(.all)

            VStack {
                HStack {
                    Spacer()
                    CloseButton(action: onClose)
                }
                .padding()

                Spacer()

                VStack {
                    Text(LocalizedStrings.orientation_prompt_title)
                        .font(.title2)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                        .padding(8)

                    Text(LocalizedStrings.orientation_prompt_description)
                        .multilineTextAlignment(.center)
                        .padding(8)
                }
                .foregroundColor(.livenessLabel)
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
