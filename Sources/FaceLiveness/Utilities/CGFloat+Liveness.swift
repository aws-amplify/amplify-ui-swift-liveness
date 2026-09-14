//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import CoreGraphics

extension CGFloat {
    /// Maximum width for the liveness capture viewport (and its chrome) on wide iOS 27 windows —
    /// resized windows, foldables, iPad. Beyond this readable width the front camera stretches into an
    /// unusable wide crop and the framing oval no longer matches the preview, so the viewport is capped
    /// to this width and centred. On phone widths the available width binds, so behaviour is unchanged.
    static let livenessMaxViewportWidth: CGFloat = 540
}
