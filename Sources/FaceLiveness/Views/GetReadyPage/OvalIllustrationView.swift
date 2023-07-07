//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
import Amplify

struct OvalIllustrationView<Illustration: View>: View {
    let icon: OvalIllustrationIconView
    let text: () -> Text
    let primaryColor: Color
    let secondaryColor: Color
    let illustration: () -> Illustration

    var body: some View {
        VStack(alignment: .leading) {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    illustration()
                        .border(primaryColor, width: 0.8)

                    text()
                        .bold()
                        .foregroundColor(primaryColor)
                        .padding(4)
                }
                .background(secondaryColor)

                icon
            }
        }
    }
}
