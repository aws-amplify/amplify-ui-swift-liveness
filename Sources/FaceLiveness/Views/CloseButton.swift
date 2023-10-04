//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(
            action: action,
            label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.livenessLabel)
                    .frame(width: 44, height: 44)
                    .background(Color.livenessBackground)
                    .clipShape(Circle())
                    .accessibilityLabel(Text(LocalizedStrings.close_button_a11y))
            }
        )
    }
}

struct CloseButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray
            CloseButton(action: {})
        }
    }
}
