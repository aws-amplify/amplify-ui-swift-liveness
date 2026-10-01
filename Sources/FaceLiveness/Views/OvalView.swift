//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import UIKit

class OvalView: UIView {
    let ovalFrame: CGRect

    init(frame: CGRect, ovalFrame: CGRect) {
        self.ovalFrame = ovalFrame
        super.init(frame: frame)
        backgroundColor = .clear
    }

    /// The face guide outline color, `#AEB3B7`.
    private static let strokeColor = UIColor(red: 0xAE / 255, green: 0xB3 / 255, blue: 0xB7 / 255, alpha: 1)

    override func draw(_ rect: CGRect) {
        let mask = UIBezierPath(rect: bounds)
        let oval = UIBezierPath(ovalIn: ovalFrame)
        mask.append(oval.reversing())

        // An opaque white background with the oval cut out, and a 4pt outline whose inner
        // half is cut away with the oval.
        UIColor.white.setFill()
        mask.fill()

        mask.addClip()
        Self.strokeColor.setStroke()
        oval.lineWidth = 4
        oval.stroke()
    }

    required init?(coder: NSCoder) { nil }
}
