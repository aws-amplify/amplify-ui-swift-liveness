//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
import UIKit

extension Color {
    static func hex(_ hex: String) -> Color {
        Color(UIColor.hex(hex))
    }
}
