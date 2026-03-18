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

    override func draw(_ rect: CGRect) {
        let mask = UIBezierPath(rect: bounds)
        let oval = UIBezierPath(ovalIn: ovalFrame)
        mask.append(oval.reversing())

        // X Figma design: black overlay instead of white
        UIColor.black.setFill()
        mask.fill()

        // White oval stroke
        UIColor.clear.setFill()
        UIColor.white.setStroke()
        oval.lineWidth = 3
        oval.stroke()
    }

    required init?(coder: NSCoder) { nil }
}
