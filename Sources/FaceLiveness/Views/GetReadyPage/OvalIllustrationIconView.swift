//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct OvalIllustrationIconView: View {
    let systemName: String
    let iconColor: Color
    let backgroundColor: Color

    init(
        systemName: String,
        iconColor: Color = .white,
        backgroundColor: Color
    ) {
        self.systemName = systemName
        self.iconColor = iconColor
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 12, weight: .heavy))
            .foregroundColor(iconColor)
            .frame(width: 15, height: 15)
            .padding(5)
            .background(backgroundColor)
    }

    static func checkmark(backgroundColor: Color) -> Self {
        OvalIllustrationIconView(
            systemName: "checkmark",
            backgroundColor: backgroundColor
        )
    }

    static func xmark(backgroundColor: Color) -> Self {
        OvalIllustrationIconView(
            systemName: "xmark",
            backgroundColor: backgroundColor
        )
    }
}
