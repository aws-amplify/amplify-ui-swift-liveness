//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import CoreGraphics

extension CGFloat {
    /// Readable-width cap for the get-ready preview column on wide windows; on phone
    /// widths the available width binds, so behavior is unchanged.
    static let livenessMaxViewportWidth: CGFloat = 540
}
