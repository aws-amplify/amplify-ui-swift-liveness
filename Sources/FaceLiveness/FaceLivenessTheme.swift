//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
import UIKit

// MARK: - FaceLivenessTheme

/// Configuration for customizing the visual appearance of the Face Liveness detection UI.
///
/// Create a theme with default values and override only the properties you need:
/// ```swift
/// var theme = FaceLivenessTheme()
/// theme.colors.primary = .blue
/// theme.oval.strokeWidth = 4
/// theme.components.showRecordingIndicator = false
/// ```
public struct FaceLivenessTheme {

    /// Colors used across the liveness UI.
    public var colors: Colors

    /// Configuration for the oval overlay during face detection.
    public var oval: OvalStyle

    /// Configuration for the instruction text pill shown during the liveness check.
    public var instruction: InstructionStyle

    /// Controls which UI components are visible during the liveness check.
    public var components: ComponentVisibility

    /// When non-nil, forces the specified color scheme on all liveness views.
    /// Set to `.dark` for a dark-themed UI. Default is `nil` (follows system).
    public var preferredColorScheme: ColorScheme?

    /// Custom view to display during loading/connecting states.
    /// When `nil`, the default loading spinner is shown.
    ///
    /// Example:
    /// ```swift
    /// theme.customLoadingView = AnyView(MyCustomLoadingView())
    /// ```
    public var customLoadingView: AnyView?

    /// When `true`, camera permission prompts use a compact system alert
    /// over the loading view instead of the full-screen camera permission view.
    /// Default is `false`.
    public var usesCompactCameraPermissionPrompt: Bool

    /// Layout style for the detection overlay. Default is `.default` (VStack-based).
    /// Use `.fullScreenOval()` for a full-screen layout with a static oval placeholder.
    public var layout: LayoutStyle

    /// Creates a theme with all default values matching the standard liveness UI.
    public init() {
        self.colors = Colors()
        self.oval = OvalStyle()
        self.instruction = InstructionStyle()
        self.components = ComponentVisibility()
        self.preferredColorScheme = nil
        self.customLoadingView = nil
        self.usesCompactCameraPermissionPrompt = false
        self.layout = .default
    }

    /// The default theme matching the standard liveness UI.
    public static let `default` = FaceLivenessTheme()
}

// MARK: - Colors

extension FaceLivenessTheme {
    /// Color configuration for the liveness UI.
    public struct Colors {
        /// Color for primary action elements
        /// (buttons, active instruction pills, progress bars).
        public var primary: Color

        /// Text/icon color used on primary elements.
        public var onPrimary: Color

        /// General background color (verifying state).
        public var background: Color

        /// Text/icon color on background.
        public var onBackground: Color

        /// Component background color (close button, recording indicator).
        public var surface: Color

        /// Text/icon color on surface components.
        public var onSurface: Color

        /// Color for error instruction states (e.g., "Move face back").
        public var error: Color

        /// Text color for error instruction states.
        public var onError: Color

        /// Background color for the photosensitivity warning box.
        public var errorContainer: Color

        /// Text color for the photosensitivity warning box.
        public var onErrorContainer: Color

        /// Stroke color for the preview ellipse on the Get Ready page.
        public var previewBorder: Color

        /// Creates default colors matching the standard liveness UI.
        public init() {
            self.primary = .livenessPrimaryBackground
            self.onPrimary = .livenessPrimaryLabel
            self.background = .livenessBackground
            self.onBackground = .livenessLabel
            self.surface = .livenessBackground
            self.onSurface = .livenessLabel
            self.error = .livenessErrorBackground
            self.onError = .livenessErrorLabel
            self.errorContainer = .livenessWarningBackground
            self.onErrorContainer = .livenessWarningLabel
            self.previewBorder = .livenessPreviewBorder
        }
    }
}

// MARK: - OvalStyle

extension FaceLivenessTheme {
    /// Configuration for the oval overlay that frames the user's face.
    public struct OvalStyle {
        /// Fill color for the mask area outside the oval.
        /// Default: white at 90% opacity.
        public var maskColor: UIColor

        /// Stroke color for the oval border. Default: white.
        public var strokeColor: UIColor

        /// Line width for the oval border stroke. Default: 8.
        public var strokeWidth: CGFloat

        /// Creates default oval style matching the standard liveness UI.
        public init() {
            self.maskColor = UIColor.white.withAlphaComponent(0.9)
            self.strokeColor = .white
            self.strokeWidth = 8
        }
    }
}

// MARK: - InstructionStyle

extension FaceLivenessTheme {
    /// Configuration for the instruction text shown during the liveness check.
    public struct InstructionStyle {
        /// Override for instruction background color.
        /// When non-nil, all instruction states use this single color.
        /// When nil (default), per-state colors from ``Colors`` are used.
        public var backgroundColor: Color?

        /// Override for instruction text color.
        /// When non-nil, all instruction states use this single color.
        /// When nil (default), per-state colors from ``Colors`` are used.
        public var textColor: Color?

        /// Font for the instruction text. Default: `.title`.
        public var font: Font

        /// When `true`, uses a capsule shape for the instruction background.
        /// When `false` (default), uses a rounded rectangle with ``cornerRadius``.
        public var useCapsuleShape: Bool

        /// Corner radius for the instruction background.
        /// Ignored when ``useCapsuleShape`` is `true`. Default: 8.
        public var cornerRadius: CGFloat

        /// Padding around the instruction text.
        /// Default: 12 on all edges.
        public var padding: EdgeInsets

        /// Creates default instruction style matching the standard liveness UI.
        public init() {
            self.backgroundColor = nil
            self.textColor = nil
            self.font = .title
            self.useCapsuleShape = false
            self.cornerRadius = 8
            self.padding = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        }
    }
}

// MARK: - ComponentVisibility

extension FaceLivenessTheme {
    /// Controls which UI components are visible during the liveness check.
    public struct ComponentVisibility {
        /// Whether to show the recording indicator (red dot + "REC" label).
        /// Default: `true`.
        public var showRecordingIndicator: Bool

        /// Whether to show the close button during the liveness check.
        /// Default: `true`.
        public var showCloseButton: Bool

        /// Whether to show the progress bar during face matching.
        /// Default: `true`.
        public var showProgressBar: Bool

        /// Creates default visibility settings (all components visible).
        public init() {
            self.showRecordingIndicator = true
            self.showCloseButton = true
            self.showProgressBar = true
        }
    }
}

// MARK: - LayoutStyle

extension FaceLivenessTheme {
    /// Controls the layout of the detection overlay during the liveness check.
    public enum LayoutStyle {
        /// Default layout: VStack with top bar (recording indicator + close button),
        /// instruction below the top bar, 3:4 aspect ratio content area.
        case `default`

        /// Full-screen layout with a static oval placeholder shown before the SDK
        /// draws its dynamic oval. The instruction pill is positioned above the oval.
        /// Ideal for seamless transitions from a custom loading view that also
        /// shows an oval.
        ///
        /// - Parameters:
        ///   - ovalWidth: Width of the static oval placeholder. Default: 250.
        ///   - ovalHeight: Height of the static oval placeholder. Default: 344.
        ///   - ovalYRatio: Vertical position of the oval center as a fraction of
        ///     screen height (0 = top, 1 = bottom). Default: 0.42.
        ///   - instructionOffset: Distance in points between the instruction pill's
        ///     bottom edge and the oval's top edge. Default: 30.
        case fullScreenOval(
            ovalWidth: CGFloat = 250,
            ovalHeight: CGFloat = 344,
            ovalYRatio: CGFloat = 0.42,
            instructionOffset: CGFloat = 30
        )
    }
}

// MARK: - SwiftUI Environment

struct LivenessThemeKey: EnvironmentKey {
    static let defaultValue = FaceLivenessTheme.default
}

extension EnvironmentValues {
    var livenessTheme: FaceLivenessTheme {
        get { self[LivenessThemeKey.self] }
        set { self[LivenessThemeKey.self] = newValue }
    }
}
