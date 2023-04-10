//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

extension View {
    @ViewBuilder func _overlay<V: View>(
        alignment: Alignment = .center,
        @ViewBuilder content: () -> V
    ) -> some View {
        if #available(iOS 15.0, *) {
            overlay(alignment: alignment, content: content)
        } else {
            overlay(content(), alignment: alignment)
        }
    }
}
