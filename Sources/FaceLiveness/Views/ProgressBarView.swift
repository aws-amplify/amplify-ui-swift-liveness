//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct ProgressBarView: View {
    let emptyColor: Color
    let borderColor: Color
    let fillColor: Color
    let indicatorColor: Color
    let percentage: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .border(borderColor, width: 1)
                    .cornerRadius(8, corners: .allCorners)
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height - 8
                    )
                    .foregroundColor(emptyColor)

                Rectangle()
                    .cornerRadius(8, corners: .allCorners)
                    .frame(
                        width: min(percentage, 1) * proxy.size.width,
                        height: proxy.size.height - 8
                    )
                    .foregroundColor(fillColor)
            }
        }
    }
}
