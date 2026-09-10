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

    /// The interface orientation of the host's current scene, or `.portrait` if none resolves.
    static var currentInterfaceOrientation: UIInterfaceOrientation {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        let scene = windowScenes.first(where: { $0.activationState == .foregroundActive })
            ?? windowScenes.first

        return scene?.interfaceOrientation ?? .portrait
    }
}
