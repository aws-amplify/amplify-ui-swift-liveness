//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct WarningBox<PopoverView: View>: View {
    @Environment(\.faceLivenessDetectorTheme) private var theme
    @State var isPresentingPopover = false
    let titleText: String
    let bodyText: String
    let infoButtonAccessibilityLabel: String
    let popoverContent: PopoverView

    init(
        titleText: String,
        bodyText: String,
        infoButtonAccessibilityLabel: String,
        @ViewBuilder popoverContent: () -> PopoverView
    ) {
        self.titleText = titleText
        self.bodyText = bodyText
        self.infoButtonAccessibilityLabel = infoButtonAccessibilityLabel
        self.popoverContent = popoverContent()
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(titleText)
                    .font(theme.fonts.headline)
                    .foregroundColor(theme.colors.onErrorContainer)

                Text(bodyText)
                    .font(theme.fonts.body)
                    .foregroundColor(theme.colors.onErrorContainer)
            }
            Spacer()
            Button(
                action: { isPresentingPopover = true },
                label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(theme.colors.onErrorContainer)
                        .frame(width: 20, height: 20)
                }
            )
            .frame(width: 44, height: 44)
            .accessibilityLabel(Text(infoButtonAccessibilityLabel))
            .popover(
                isPresented: $isPresentingPopover,
                attachmentAnchor: .point(.top),
                arrowEdge: .bottom,
                content: {  popoverContent }
            )
        }
        .padding()
        .background(
            Rectangle()
                .foregroundColor(theme.colors.errorContainer)
                .cornerRadius(6)
        )
    }
}
