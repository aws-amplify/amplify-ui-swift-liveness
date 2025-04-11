//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

extension Color {
    static func dynamicColors(light: UIColor, dark: UIColor) -> Color {
        Color(
            UIColor(
                dynamicProvider: { traitCollection in
                    switch traitCollection.userInterfaceStyle {
                    case .dark: return dark
                    default: return light
                    }
                }
            )
        )
    }
}
