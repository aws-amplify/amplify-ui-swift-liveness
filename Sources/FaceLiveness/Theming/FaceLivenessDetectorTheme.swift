//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

/// Represents a theme that is used to style the ``FaceLivenessDetectorView``.
///
/// Set the colors and fonts you want to change, then apply the theme with
/// ``View/faceLivenessDetectorTheme(_:)``:
///
/// ```swift
/// let theme = FaceLivenessDetectorTheme()
/// theme.colors.primary = Color("BrandPrimary")
/// theme.fonts.title = .custom("BrandSans-Semibold", size: 24, relativeTo: .title)
///
/// FaceLivenessDetectorView(...)
///     .faceLivenessDetectorTheme(theme)
/// ```
///
/// The views don't observe changes to a theme they're already using. To change the theme while
/// they're on screen, pass a new theme to ``View/faceLivenessDetectorTheme(_:)``.
///
/// The background around the face oval, the oval's outline, and the colors flashed during the
/// check light the user's face, so they aren't part of the theme.
///
/// Android equivalent: wrapping `FaceLivenessDetector` in a `MaterialTheme`.
@MainActor
public final class FaceLivenessDetectorTheme: ObservableObject {
    /// The colors used by the liveness views.
    public var colors: Colors

    /// The fonts used by the liveness views.
    public var fonts = Fonts()

    /// Creates a theme whose default colors follow the system's light or dark appearance.
    ///
    /// Android equivalent: `LivenessColorScheme.default()`.
    nonisolated public init() {
        self.colors = .system
    }

    /// Creates a theme with the default colors for the given appearance, whatever the system's
    /// appearance. Use it to choose the appearance yourself, for example from
    /// `@Environment(\.colorScheme)`.
    ///
    /// Android equivalent: `LivenessColorScheme.Defaults.lightColorScheme` and
    /// `LivenessColorScheme.Defaults.darkColorScheme`.
    nonisolated public init(colorScheme: ColorScheme) {
        self.colors = colorScheme == .dark ? .dark : .light
    }
}

extension FaceLivenessDetectorTheme {
    /// The colors used by the liveness views, named after their Android `ColorScheme` roles.
    ///
    /// Any color can adapt to light and dark appearance, for example an asset catalog color with
    /// a Dark appearance.
    public struct Colors: Sendable {
        /// The background of the instructions shown during the check, the progress bar's fill,
        /// the primary buttons, and the loading indicator.
        ///
        /// Android equivalent: `ColorScheme.primary`.
        public var primary: Color

        /// Text and icons on ``primary``.
        ///
        /// Android equivalent: `ColorScheme.onPrimary`.
        public var onPrimary: Color

        /// The background of the instruction shown when the face is too close.
        ///
        /// Android equivalent: `ColorScheme.error`.
        public var error: Color

        /// Text on ``error``.
        ///
        /// Android equivalent: `ColorScheme.onError`.
        public var onError: Color

        /// The background of the get ready, camera permission, loading, and rotate device
        /// screens, the close button, the REC indicator, and the "Verifying" message.
        ///
        /// Android equivalent: `ColorScheme.background`.
        public var background: Color

        /// Text and icons on ``background``, including the text on the get ready, camera
        /// permission, loading, and rotate device screens.
        ///
        /// Android equivalent: `ColorScheme.onBackground`.
        public var onBackground: Color

        /// The unfilled part of the progress bar.
        ///
        /// Android equivalent: `ColorScheme.surface`.
        public var surface: Color

        /// The background of the photosensitivity warning.
        ///
        /// Android equivalent: `ColorScheme.errorContainer`.
        public var errorContainer: Color

        /// Text and icons on ``errorContainer``.
        ///
        /// Android equivalent: `ColorScheme.onErrorContainer`.
        public var onErrorContainer: Color
    }

    /// The fonts used by the liveness views, named after SwiftUI's text styles. The defaults are
    /// Dynamic Type text styles, so they scale with the user's preferred text size.
    ///
    /// Use `Font.custom(_:size:relativeTo:)` for a custom font that still scales.
    ///
    /// Android equivalent: `Typography`.
    public struct Fonts: Sendable {
        /// Not used by the liveness views.
        public var largeTitle: Font = .largeTitle

        /// The instructions shown during the check, and "Center your face" on the get ready
        /// screen.
        ///
        /// Android equivalent: `Typography.headlineLarge`.
        public var title: Font = .title

        /// The titles of the camera permission and rotate device screens, shown in medium
        /// weight. These screens are iOS only.
        public var title2: Font = .title2

        /// The title of the photosensitivity dialog, shown in medium weight.
        ///
        /// Android equivalent: `Typography.headlineSmall`, the default for an `AlertDialog` title.
        public var title3: Font = .title3

        /// The title of the photosensitivity warning.
        ///
        /// Android equivalent: `Typography.titleMedium`.
        public var headline: Font = .headline

        /// Not used by the liveness views.
        public var subheadline: Font = .subheadline

        /// Body text and button labels: the photosensitivity warning and dialog text, the
        /// descriptions on the camera permission and rotate device screens, "Connecting",
        /// the instructions shown before the oval appears, and "Verifying".
        ///
        /// Android equivalent: `Typography.bodyMedium`.
        public var body: Font = .body

        /// Not used by the liveness views.
        public var callout: Font = .callout

        /// The REC indicator's label, shown in bold.
        ///
        /// Android equivalent: `Typography.labelMedium`.
        public var caption: Font = .caption

        /// Not used by the liveness views.
        public var caption2: Font = .caption2

        /// Not used by the liveness views.
        public var footnote: Font = .footnote
    }
}

extension FaceLivenessDetectorTheme.Colors {
    /// Android's `LivenessColorScheme.Defaults.lightColorScheme`.
    static let light = Self(
        primary: .hex("#047D95"),
        onPrimary: .hex("#FFFFFF"),
        error: .hex("#950404"),
        onError: .hex("#FFFFFF"),
        background: .hex("#FFFFFF"),
        onBackground: .hex("#0D1926"),
        surface: .hex("#FFFFFF"),
        errorContainer: .hex("#B8CEF9"),
        onErrorContainer: .hex("#002266")
    )

    /// Android's `LivenessColorScheme.Defaults.darkColorScheme`.
    static let dark = Self(
        primary: .hex("#7DD6E8"),
        onPrimary: .hex("#0D1926"),
        error: .hex("#EF8F8F"),
        onError: .hex("#0D1926"),
        background: .hex("#0D1926"),
        onBackground: .hex("#FFFFFF"),
        surface: .hex("#0D1926"),
        errorContainer: .hex("#043495"),
        onErrorContainer: .hex("#E6EEFE")
    )

    /// ``light`` or ``dark``, whichever matches the system's appearance.
    static let system = Self(
        primary: .adaptive(light: light.primary, dark: dark.primary),
        onPrimary: .adaptive(light: light.onPrimary, dark: dark.onPrimary),
        error: .adaptive(light: light.error, dark: dark.error),
        onError: .adaptive(light: light.onError, dark: dark.onError),
        background: .adaptive(light: light.background, dark: dark.background),
        onBackground: .adaptive(light: light.onBackground, dark: dark.onBackground),
        surface: .adaptive(light: light.surface, dark: dark.surface),
        errorContainer: .adaptive(light: light.errorContainer, dark: dark.errorContainer),
        onErrorContainer: .adaptive(light: light.onErrorContainer, dark: dark.onErrorContainer)
    )
}

private extension Color {
    static func adaptive(light: Color, dark: Color) -> Color {
        .dynamicColors(light: UIColor(light), dark: UIColor(dark))
    }
}
