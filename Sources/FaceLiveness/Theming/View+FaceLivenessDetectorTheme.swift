//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

extension View {
    /// Sets the theme used by the ``FaceLivenessDetectorView`` and all its views.
    ///
    /// Passing a different theme while the views are on screen updates them. Changing a property
    /// of the theme they're already using doesn't.
    ///
    /// - Parameter theme: The theme to apply.
    public func faceLivenessDetectorTheme(_ theme: FaceLivenessDetectorTheme) -> some View {
        environment(\.faceLivenessDetectorTheme, theme)
    }
}

extension EnvironmentValues {
    var faceLivenessDetectorTheme: FaceLivenessDetectorTheme {
        get { self[FaceLivenessDetectorThemeKey.self] }
        set { self[FaceLivenessDetectorThemeKey.self] = newValue }
    }
}

private struct FaceLivenessDetectorThemeKey: EnvironmentKey {
    static let defaultValue = FaceLivenessDetectorTheme()
}
