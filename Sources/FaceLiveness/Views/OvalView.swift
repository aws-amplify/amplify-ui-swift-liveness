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
    let maskColor: UIColor
    let ovalStrokeColor: UIColor
    let ovalStrokeWidth: CGFloat

    /// When `true`, forces white mask fill regardless of ``maskColor``.
    /// Used during the freshness color check to ensure the overlay colors
    /// blend correctly against a known white background.
    var forceWhiteFill = false

    init(
        frame: CGRect,
        ovalFrame: CGRect,
        maskColor: UIColor = UIColor.white.withAlphaComponent(0.9),
        strokeColor: UIColor = .white,
        strokeWidth: CGFloat = 8
    ) {
        self.ovalFrame = ovalFrame
        self.maskColor = maskColor
        self.ovalStrokeColor = strokeColor
        self.ovalStrokeWidth = strokeWidth
        super.init(frame: frame)
        backgroundColor = .clear
    }

    override func draw(_ rect: CGRect) {
        let mask = UIBezierPath(rect: bounds)
        let oval = UIBezierPath(ovalIn: ovalFrame)
        mask.append(oval.reversing())

        let fillColor = forceWhiteFill ? UIColor.white : maskColor
        fillColor.setFill()
        mask.fill()

        UIColor.clear.setFill()
        ovalStrokeColor.setStroke()
        oval.lineWidth = ovalStrokeWidth
        oval.stroke()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            setNeedsDisplay()
        }
    }

    required init?(coder: NSCoder) { nil }
}
