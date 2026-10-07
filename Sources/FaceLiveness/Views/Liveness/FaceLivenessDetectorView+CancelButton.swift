//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

extension FaceLivenessDetectorView {
    /// Hides the close (X) button during the check and on the prompt to rotate the device.
    ///
    /// With the button hidden, your app must give users another way to leave the check, for
    /// example by setting `isPresented` to `false` from its own close action. Removing the view
    /// stops the camera, and the session is left for the service to time out; `onCompletion`
    /// isn't called.
    ///
    /// Hiding the button doesn't stop users leaving the check in other ways, such as by
    /// backgrounding the app, so keep verifying the session's result on your backend.
    ///
    /// Web equivalent: `components={{ CancelButton: null }}`.
    ///
    /// - Parameter hidesCancelButton: Whether to hide the close button.
    public func hidesCancelButton(_ hidesCancelButton: Bool = true) -> Self {
        var view = self
        view.cancelButtonOptions.isHidden = hidesCancelButton
        return view
    }

    /// What a replacement close button is given, through the closure passed to
    /// ``cancelButton(_:)``.
    ///
    /// The same pattern as SwiftUI's `ButtonStyle.Configuration`.
    public struct CancelButtonConfiguration {
        /// Ends the check the same way as the default button: `onCompletion` is called with
        /// ``FaceLivenessDetectionError/userCancelled``.
        public let cancel: @MainActor () -> Void

        /// The localized label VoiceOver reads for the default button ("Close"), for your
        /// button to use as its own.
        public let accessibilityLabel: String
    }

    /// Replaces the close (X) button, during the check and on the prompt to rotate the device,
    /// with your own view. For example, a button that asks the user to confirm before leaving,
    /// so the check isn't ended by an accidental tap.
    ///
    /// ```swift
    /// FaceLivenessDetectorView(...)
    ///     .cancelButton { configuration in
    ///         ConfirmLeaveButton(onConfirm: configuration.cancel)
    ///             .accessibilityLabel(configuration.accessibilityLabel)
    ///     }
    /// ```
    ///
    /// The view takes the default button's place in the top trailing corner. Give it a tap target
    /// of at least 44x44 points and an accessibility label, as the default button has. If
    /// ``hidesCancelButton(_:)`` is also set to `true`, the button is hidden.
    ///
    /// Web equivalent: `components={{ CancelButton: MyButton }}`.
    ///
    /// - Parameter content: The view to show, given a ``CancelButtonConfiguration`` with the
    ///   action that cancels the check and the default button's accessibility label.
    public func cancelButton<Content: View>(
        @ViewBuilder _ content: @escaping (_ configuration: CancelButtonConfiguration) -> Content
    ) -> Self {
        var view = self
        view.cancelButtonOptions.content = { configuration in AnyView(content(configuration)) }
        return view
    }
}
