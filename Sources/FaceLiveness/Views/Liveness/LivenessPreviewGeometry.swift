//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import CoreGraphics

/// The single source of truth for where the camera image sits on screen.
///
/// Everything the user sees during a liveness check has to agree on one rect: the camera
/// preview layer, the oval overlay drawn on top of it, the SwiftUI instruction overlay, and
/// the normalization of face landmarks that produces the coordinates sent to the service.
///
/// The camera is configured for a 3:4 (portrait) image and the SwiftUI overlay in
/// `_FaceLivenessDetectionView` lays itself out with `.aspectRatio(3/4, contentMode: .fit)`.
/// `.fit` means the largest 3:4 rect that fits *entirely inside* the viewport, so the preview
/// has to be fitted the same way. Deriving the preview as `width x width * 4/3` instead only
/// matches `.fit` while the viewport is at least 4/3 as tall as it is wide, which holds for
/// every phone in portrait but fails in landscape, in a resized iPad window, and on a
/// near-square display, where it produces a preview taller than the screen and an oval the
/// user cannot fit their face into.
enum LivenessPreviewGeometry {
    /// Width divided by height of the camera image, and therefore of the preview rect.
    static let previewAspectRatio: CGFloat = 3.0 / 4.0

    /// The largest `previewAspectRatio` rect that fits entirely inside `viewport`, centered.
    ///
    /// Leaves bars at the left and right when the viewport is proportionally wider than the
    /// camera image, and at the top and bottom when it is proportionally taller. Returns
    /// `.zero` for an empty viewport, which happens before the first layout pass.
    static func previewRect(fittingIn viewport: CGSize) -> CGRect {
        guard viewport.width > 0, viewport.height > 0 else { return .zero }

        let width = min(viewport.width, viewport.height * previewAspectRatio)
        let height = width / previewAspectRatio

        return CGRect(
            x: (viewport.width - width) / 2,
            y: (viewport.height - height) / 2,
            width: width,
            height: height
        )
    }

    /// Maps the oval the service specifies in video coordinates onto a preview rect.
    ///
    /// The result is expressed in the preview rect's own coordinate space, because it is
    /// drawn by `OvalView`, whose frame is the preview rect, and compared against face
    /// landmarks normalized to the same size.
    static func ovalRect(
        forVideoOval videoOval: CGRect,
        videoSize: CGSize,
        previewRect: CGRect
    ) -> CGRect {
        guard videoSize.width > 0 else { return .zero }

        let scaleRatio = previewRect.width / videoSize.width

        return CGRect(
            x: videoOval.minX * scaleRatio,
            y: videoOval.minY * scaleRatio,
            width: videoOval.width * scaleRatio,
            height: videoOval.height * scaleRatio
        )
    }
}
