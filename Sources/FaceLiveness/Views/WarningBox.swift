//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct WarningBox<PopoverView: View>: View {
    @State var isPresentingPopover = false
    let titleText: LocalizedStringKey
    let bodyText: LocalizedStringKey
    let popoverContent: PopoverView

    init(
        titleText: LocalizedStringKey,
        bodyText: LocalizedStringKey,
        @ViewBuilder popoverContent: () -> PopoverView
    ) {
        self.titleText = titleText
        self.bodyText = bodyText
        self.popoverContent = popoverContent()
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(titleText, bundle: .module)
                    .fontWeight(.semibold)
                    .foregroundColor(.livenessWarningLabel)

                Text(bodyText, bundle: .module)
                    .foregroundColor(.livenessWarningLabel)
            }
            Spacer()
            Button(
                action: { isPresentingPopover = true },
                label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.livenessWarningLabel)
                        .frame(width: 20, height: 20)
                }
            )
            .frame(width: 44, height: 44)
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
                .foregroundColor(.livenessWarningBackground)
                .cornerRadius(6)
        )
    }
}
