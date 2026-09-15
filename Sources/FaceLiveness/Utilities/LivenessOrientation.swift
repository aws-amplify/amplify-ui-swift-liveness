//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import UIKit

/// Decides what the detector does for a given interface orientation. The capture session is
/// pinned to `.portrait`, so the check is only valid while the interface is portrait.
enum LivenessOrientation {
    enum Decision: Equatable {
        case proceed

        case blockUntilPortrait
    }

    /// `.portraitUpsideDown` is blocked too: the feed would be rotated 180 degrees, which the
    /// face detector cannot read. Matches Android's `SCREEN_ORIENTATION_PORTRAIT` lock.
    static func decision(for orientation: UIInterfaceOrientation) -> Decision {
        switch orientation {
        case .portrait:
            return .proceed
        case .landscapeLeft, .landscapeRight, .portraitUpsideDown:
            return .blockUntilPortrait
        case .unknown:
            // an orientation we cannot read must not block the check
            return .proceed
        @unknown default:
            return .proceed
        }
    }

    /// The interface orientation of the app's foreground scene, or `.portrait` if none resolves.
    /// Only a seed: once the reader is in a window, its scene is read instead.
    static var currentInterfaceOrientation: UIInterfaceOrientation {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        let scene = windowScenes.first(where: { $0.activationState == .foregroundActive })
            ?? windowScenes.first

        return scene?.interfaceOrientation ?? .portrait
    }

    /// `orientation` turned by a transition coordinator's `targetTransform`. Each quarter turn
    /// of the transform's rotation advances portrait -> landscapeRight -> upsideDown -> landscapeLeft,
    /// the convention UIKit reported on iOS 17.5 (see `LivenessOrientationTestCase`).
    static func orientation(
        _ orientation: UIInterfaceOrientation,
        rotatedBy transform: CGAffineTransform
    ) -> UIInterfaceOrientation {
        let clockwiseOrder: [UIInterfaceOrientation] = [
            .portrait, .landscapeRight, .portraitUpsideDown, .landscapeLeft
        ]
        guard let index = clockwiseOrder.firstIndex(of: orientation) else { return orientation }

        let radians = atan2(transform.b, transform.a)
        let quarterTurns = Int((radians / (.pi / 2)).rounded())
        let rotated = ((index + quarterTurns) % 4 + 4) % 4

        return clockwiseOrder[rotated]
    }
}

/// What the observer needs from the scene hosting the detector; lets tests stand in for a
/// `UIWindowScene`.
protocol InterfaceOrientationProviding: AnyObject {
    var interfaceOrientation: UIInterfaceOrientation { get }
}

extension UIWindowScene: InterfaceOrientationProviding {}
