//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import UIKit

extension UIColor {
    static func hex(_ hex: String) -> UIColor {
        assert(hex.hasPrefix("#"))

        let hex = String(hex.dropFirst())
        assert(hex.count == 6)

        let scanner = Scanner(string: hex)
        var hexNumber: UInt64 = 0

        precondition(scanner.scanHexInt64(&hexNumber))
        let r, g, b, a: CGFloat
        r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255
        g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255
        b = CGFloat((hexNumber & 0x0000FF)) / 255
        a = 1.0

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
