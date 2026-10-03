//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import UIKit

/// The face guide: an opaque white overlay with the oval cut out, covering the whole view.
///
/// It works out where the camera preview sits from its own bounds each time it lays out, so it
/// stays aligned with the preview as its superview resizes. It renders with shape layers rather
/// than drawing a bitmap, so resizing doesn't reallocate a screen-sized backing store.
class OvalView: UIView {
    /// The oval, relative to the camera preview's origin.
    let ovalFrame: CGRect

    private let outlineLayer = CAShapeLayer()
    private let outlineMask = CAShapeLayer()

    override class var layerClass: AnyClass { CAShapeLayer.self }

    private var overlayLayer: CAShapeLayer {
        layer as! CAShapeLayer
    }

    init(frame: CGRect, ovalFrame: CGRect) {
        self.ovalFrame = ovalFrame
        super.init(frame: frame)
        backgroundColor = .clear

        overlayLayer.fillColor = UIColor.white.cgColor
        overlayLayer.fillRule = .evenOdd

        // A 4pt outline whose inner half is cut away with the oval
        outlineLayer.fillColor = nil
        outlineLayer.strokeColor = UIColor.hex("#AEB3B7").cgColor
        outlineLayer.lineWidth = 4
        outlineMask.fillColor = UIColor.black.cgColor
        outlineMask.fillRule = .evenOdd
        outlineLayer.mask = outlineMask
        layer.addSublayer(outlineLayer)
    }

    /// ``ovalFrame`` in this view's coordinates, for where the preview sits at the view's current
    /// size.
    var ovalFrameInView: CGRect {
        let previewOrigin = LivenessPreviewGeometry.previewRect(fittingIn: bounds.size).origin
        return ovalFrame.offsetBy(dx: previewOrigin.x, dy: previewOrigin.y)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let oval = UIBezierPath(ovalIn: ovalFrameInView)
        let overlay = UIBezierPath(rect: bounds)
        overlay.append(oval)

        // resizes should move the guide, not animate it
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        overlayLayer.path = overlay.cgPath
        outlineLayer.frame = bounds
        outlineLayer.path = oval.cgPath
        outlineMask.frame = bounds
        outlineMask.path = overlay.cgPath
        CATransaction.commit()
    }

    required init?(coder: NSCoder) { nil }
}
