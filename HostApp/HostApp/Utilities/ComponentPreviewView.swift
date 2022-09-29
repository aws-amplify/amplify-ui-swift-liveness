//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

class DisplayViewModel: ObservableObject {
    @Published var displayState = DisplayState.controls

    static let `default` = DisplayViewModel()
}

//var displayState = DisplayState.controls

struct ComponentPreviewView<T: View>: View {
    let content: T
    let title: String

    init(@ViewBuilder _ content: () -> T, title: String) {
        self.content = content()
        self.title = title
    }

    @State var scheme = Scheme.light
    @ObservedObject var display = DisplayViewModel.default

    var body: some View {
        VStack {
            Spacer()
            content
                .preferredColorScheme(scheme.colorScheme)
            Spacer()
        }
        .navigationTitle(title)
        .navigationBarItems(
            trailing:
                HStack {
                    Button(action: toggleDisplayState) {
                        SwiftUI.Image(systemName: display.displayState.buttonImage)
                            .foregroundColor(.primary)
                    }

                    Button(action: toggle) {
                        SwiftUI.Image(systemName: scheme.buttonImage)
                            .foregroundColor(.primary)
                            .preferredColorScheme(scheme.colorScheme)
                    }
                }
        )
    }

    func toggle() { scheme.toggle() }

    func toggleDisplayState() {
        display.displayState.toggle()
    }
}
