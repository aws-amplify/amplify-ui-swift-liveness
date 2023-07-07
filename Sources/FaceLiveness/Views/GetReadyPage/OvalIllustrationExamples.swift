//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct OvalIllustrationExamples: View {
    var body: some View {
        HStack(spacing: 16) {
                OvalIllustrationView(
                    icon: .checkmark(backgroundColor: .hex("#365E3D")),
                    text: { Text(.get_ready_good_fit_example, bundle: .module) },
                    primaryColor: .hex("#365E3D"),
                    secondaryColor: .hex("#D6F5DB"),
                    illustration: { Image("illustration_face_good_fit", bundle: .module) }
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(.get_ready_illustration_good_fit_a11y, bundle: .module))

                OvalIllustrationView(
                    icon: .xmark(backgroundColor: .hex("#660000")),
                    text: { Text(.get_ready_too_far_example, bundle: .module) },
                    primaryColor: .hex("#660000"),
                    secondaryColor: .hex("#F5BCBC"),
                    illustration: { Image("illustration_face_too_far", bundle: .module) }
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(.get_ready_illustration_too_far_a11y, bundle: .module))

                Spacer()
        }
    }
}

struct OvalIllustrationExamples_Previews: PreviewProvider {
    static var previews: some View {
        OvalIllustrationExamples()
            .background(Color.purple)
    }
}
