//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

extension View {
    @ViewBuilder func _background<Content: View>(
        alignment: Alignment = .center,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        if #available(iOS 15.0, *) {
            background(alignment: alignment, content: content)
        } else {
            background(content(), alignment: alignment)
        }
    }
}
