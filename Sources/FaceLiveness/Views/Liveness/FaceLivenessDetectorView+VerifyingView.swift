//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

extension FaceLivenessDetectorView {
    /// Replaces the screen shown while the check is being verified, from the end of the challenge
    /// until `onCompletion` is called, with your own view. By default the screen shows the last
    /// camera frame with "Verifying".
    ///
    /// ```swift
    /// FaceLivenessDetectorView(...)
    ///     .verifyingView {
    ///         MyVerifyingView()
    ///     }
    /// ```
    ///
    /// The view fills the screen over the theme's background color. The close (X) button stays
    /// in the top trailing corner, so leave room for it, or hide or replace it with
    /// ``hidesCancelButton(_:)`` or ``cancelButton(_:)``. Keep the view on screen until
    /// `onCompletion` is called: the result is still being received while it's shown.
    ///
    /// - Parameter content: The view to show while the check is being verified.
    public func verifyingView<Content: View>(
        @ViewBuilder _ content: @escaping () -> Content
    ) -> Self {
        var view = self
        view.verifyingViewOptions.content = { AnyView(content()) }
        return view
    }
}

/// The app's replacement for the verifying screen, set with
/// ``FaceLivenessDetectorView/verifyingView(_:)``.
struct VerifyingViewOptions {
    var content: (() -> AnyView)?

    /// The app's view, if it set one and the check is being verified in `state`.
    func content(for state: LivenessStateMachine.State) -> AnyView? {
        switch state {
        case .completedDisplayingFreshness, .completedNoLightCheck:
            return content?()
        default:
            return nil
        }
    }
}
