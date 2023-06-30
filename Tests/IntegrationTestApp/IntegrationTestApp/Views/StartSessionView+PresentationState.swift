//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

extension StartSessionView {
    struct PresentationState: Equatable {
        let buttonText: String
        let buttonBackgroundColor: Color
        let buttonAction: () -> Void
        let buttonEnabled: Bool

        static let loading = PresentationState(
            buttonText: "...",
            buttonBackgroundColor: .dynamicColors(
                light: .darkGray,
                dark: .lightGray
            ),
            buttonAction: {},
            buttonEnabled: false
        )

        static func signedIn(action: @escaping () -> Void) ->  PresentationState {
            PresentationState(
                buttonText: "Sign Out",
                buttonBackgroundColor: .dynamicColors(
                    light: .darkGray,
                    dark: .lightGray
                ),
                buttonAction: action,
                buttonEnabled: true
            )
        }

        static func signedOut(action: @escaping () -> Void) ->  PresentationState {
            PresentationState(
                buttonText: "Sign In",
                buttonBackgroundColor: .dynamicColors(
                    light: .darkGray,
                    dark: .lightGray
                ),
                buttonAction: action,
                buttonEnabled: true
            )
        }

        static func == (lhs: StartSessionView.PresentationState, rhs: StartSessionView.PresentationState) -> Bool {
            lhs.buttonText == rhs.buttonText
        }
    }
}
