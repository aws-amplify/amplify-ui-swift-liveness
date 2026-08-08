//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct InstructionView: View {
    let text: String
    let backgroundColor: Color
    var textColor: Color = .livenessLabel
    var font: Font = .title
    var useCapsuleShape: Bool = false
    var cornerRadius: CGFloat = 8
    var padding: EdgeInsets = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)

    var body: some View {
        Text(text)
            .foregroundColor(textColor)
            .font(font)
            .multilineTextAlignment(.center)
            .padding(padding)
            .background(backgroundShape)
    }

    @ViewBuilder
    private var backgroundShape: some View {
        if useCapsuleShape {
            Capsule().fill(backgroundColor)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(backgroundColor)
        }
    }
}
