//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct InstructionView: View {
    @Environment(\.faceLivenessDetectorTheme) private var theme
    let text: String
    let backgroundColor: Color
    /// Defaults to the theme's `onBackground` color.
    var textColor: Color?
    /// Defaults to the theme's `body` font.
    var font: Font?

    var body: some View {
        Text(text)
            .foregroundColor(textColor ?? theme.colors.onBackground)
            .font(font ?? theme.fonts.body)
            .padding(12)
            .background(backgroundColor)
            .cornerRadius(8)
    }
}
