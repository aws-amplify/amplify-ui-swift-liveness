//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import UIKit
import SwiftUI

extension Color {
    static func dynamicColors(light: Color, dark: Color) -> Color {
        Color(
            UIColor(
                dynamicProvider: { traitCollection in
                    switch traitCollection.userInterfaceStyle {
                    case .dark: return UIColor(dark)
                    default: return UIColor(light)
                    }
                }
            )
        )
    }
}
