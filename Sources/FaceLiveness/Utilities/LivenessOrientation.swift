//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import UIKit

/// The liveness check captures and streams video in a fixed portrait orientation
/// (`LivenessCaptureSession` pins both the data output and the preview connections to
/// `.portrait`), so the check is only valid while the interface itself is portrait.
///
/// This type holds the decision of what to do about every other interface orientation.
/// It deliberately has no UI and no UIKit state of its own so the decision can be tested
/// directly.
enum LivenessOrientation {
    /// What the detector should do for a given interface orientation.
    enum Decision: Equatable {
        /// The interface is portrait. Render the liveness flow normally.
        case proceed

        /// The interface is not portrait, so the camera feed would be rotated relative to
        /// the screen. Ask the user to rotate back instead of showing the check.
        case blockUntilPortrait
    }

    /// - Note: `.portraitUpsideDown` is blocked along with the two landscape orientations.
    ///   The capture connections are pinned to `.portrait`, so upside down produces a feed
    ///   rotated by 180 degrees, which the upright-trained face detector cannot read either.
    ///   This matches Android, which locks to `SCREEN_ORIENTATION_PORTRAIT` and therefore
    ///   also excludes upside down.
    static func decision(for orientation: UIInterfaceOrientation) -> Decision {
        switch orientation {
        case .portrait:
            return .proceed
        case .landscapeLeft, .landscapeRight, .portraitUpsideDown:
            return .blockUntilPortrait
        case .unknown:
            // Permissive on purpose. An orientation we cannot read must not block a check
            // that works today.
            return .proceed
        @unknown default:
            return .proceed
        }
    }

    /// The interface orientation of the scene the host app is currently displaying.
    ///
    /// Falls back to `.portrait` when no window scene can be resolved, so a failed lookup
    /// leaves the existing behavior untouched rather than blocking the check.
    static var currentInterfaceOrientation: UIInterfaceOrientation {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        let scene = windowScenes.first(where: { $0.activationState == .foregroundActive })
            ?? windowScenes.first

        return scene?.interfaceOrientation ?? .portrait
    }
}
