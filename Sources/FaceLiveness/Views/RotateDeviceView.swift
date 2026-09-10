//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

/// Shown in place of the liveness flow while the interface is not portrait. The close button
/// is the only exit for a host that supports landscape only.
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
