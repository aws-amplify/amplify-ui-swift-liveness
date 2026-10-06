//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

/// How the app wants the close (X) button shown, set with
/// ``FaceLivenessDetectorView/hidesCancelButton(_:)`` and
/// ``FaceLivenessDetectorView/cancelButton(_:)``.
struct CancelButtonOptions {
    var isHidden = false

    /// The app's replacement for the close button, given the action that cancels the check.
    var content: ((_ cancel: @escaping () -> Void) -> AnyView)?

    enum Resolved: Equatable {
        case standard
        case hidden
        case custom
    }

    /// Hiding wins over a replacement, whichever the app set first.
    var resolved: Resolved {
        if isHidden { return .hidden }
        return content == nil ? .standard : .custom
    }
}

/// The close (X) button, or what the app shows instead. Every option cancels the check through
/// `action`.
struct CancelButton: View {
    let options: CancelButtonOptions
    let action: () -> Void

    var body: some View {
        switch options.resolved {
        case .standard:
            CloseButton(action: action)
        case .hidden:
            EmptyView()
        case .custom:
            options.content?(action)
        }
    }
}
