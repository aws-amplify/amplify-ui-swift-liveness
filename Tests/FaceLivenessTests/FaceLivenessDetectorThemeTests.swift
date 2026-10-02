//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import SwiftUI
@testable import FaceLiveness

@MainActor
final class FaceLivenessDetectorThemeTests: XCTestCase {
    private typealias Colors = FaceLivenessDetectorTheme.Colors

    /// Android's `LivenessColorScheme.Defaults`, as (light, dark) pairs.
    private let expected: [(name: String, color: KeyPath<Colors, Color>, light: String, dark: String)] = [
        ("primary", \.primary, "#047D95", "#7DD6E8"),
        ("onPrimary", \.onPrimary, "#FFFFFF", "#0D1926"),
        ("error", \.error, "#950404", "#EF8F8F"),
        ("onError", \.onError, "#FFFFFF", "#0D1926"),
        ("background", \.background, "#FFFFFF", "#0D1926"),
        ("onBackground", \.onBackground, "#0D1926", "#FFFFFF"),
        ("surface", \.surface, "#FFFFFF", "#0D1926"),
        ("errorContainer", \.errorContainer, "#B8CEF9", "#043495"),
        ("onErrorContainer", \.onErrorContainer, "#002266", "#E6EEFE")
    ]

    /// Given: A theme created with `init()`
    /// When: Its colors are resolved in light and in dark appearance
    /// Then: Each matches that appearance's default
    func testDefaultColorsFollowTheSystemAppearance() throws {
        try skipBeforeIOS17()
        let colors = FaceLivenessDetectorTheme().colors

        for role in expected {
            XCTAssertEqual(hex(colors[keyPath: role.color], in: .light), role.light, "\(role.name), light")
            XCTAssertEqual(hex(colors[keyPath: role.color], in: .dark), role.dark, "\(role.name), dark")
        }
    }

    /// Given: Themes created with `init(colorScheme:)`
    /// When: Their colors are resolved in either appearance
    /// Then: Each has the chosen appearance's defaults, whatever the system's appearance
    func testColorSchemeDefaultsIgnoreTheSystemAppearance() throws {
        try skipBeforeIOS17()
        let light = FaceLivenessDetectorTheme(colorScheme: .light).colors
        let dark = FaceLivenessDetectorTheme(colorScheme: .dark).colors

        for role in expected {
            for style in [UIUserInterfaceStyle.light, .dark] {
                XCTAssertEqual(hex(light[keyPath: role.color], in: style), role.light, "\(role.name), light theme")
                XCTAssertEqual(hex(dark[keyPath: role.color], in: style), role.dark, "\(role.name), dark theme")
            }
        }
    }

    /// Given: A theme created with `init()`
    /// When: Its fonts are read
    /// Then: Each is the SwiftUI text style it's named after
    func testDefaultFontsAreTheMatchingTextStyles() {
        let fonts = FaceLivenessDetectorTheme().fonts

        XCTAssertEqual(fonts.largeTitle, .largeTitle)
        XCTAssertEqual(fonts.title, .title)
        XCTAssertEqual(fonts.title2, .title2)
        XCTAssertEqual(fonts.title3, .title3)
        XCTAssertEqual(fonts.headline, .headline)
        XCTAssertEqual(fonts.subheadline, .subheadline)
        XCTAssertEqual(fonts.body, .body)
        XCTAssertEqual(fonts.callout, .callout)
        XCTAssertEqual(fonts.caption, .caption)
        XCTAssertEqual(fonts.caption2, .caption2)
        XCTAssertEqual(fonts.footnote, .footnote)
    }

    /// Given: A view without a theme applied
    /// When: It renders
    /// Then: It reads a theme with the default colors
    func testViewsWithoutAThemeUseTheDefaults() throws {
        try skipBeforeIOS17()
        let probe = ThemeProbe()
        render(ThemeReader(probe: probe))

        let theme = try XCTUnwrap(probe.themes.last)
        XCTAssertEqual(hex(theme.colors.primary, in: .light), "#047D95")
    }

    /// Given: A view rendered with one theme
    /// When: A new theme is passed, and then a property of that theme is changed in place
    /// Then: The new theme reaches the view, but the in-place change doesn't re-render it
    func testPassingANewThemeUpdatesTheViewsButChangingOneInPlaceDoesNot() {
        let probe = ThemeProbe()
        let host = ThemeHost()
        let original = host.theme
        render(ThemedRoot(host: host, probe: probe))
        XCTAssertTrue(probe.themes.last === original)

        let replacement = FaceLivenessDetectorTheme()
        replacement.colors.primary = .red
        host.theme = replacement
        spinRunLoop()
        XCTAssertTrue(probe.themes.last === replacement, "a new theme must reach the views")

        let renders = probe.themes.count
        replacement.colors.primary = .blue
        spinRunLoop()
        XCTAssertEqual(probe.themes.count, renders, "changing a theme in place isn't observed")
    }

    // MARK: - Helpers

    /// `hex(_:in:)` needs `Color.resolve(in:)`. Converting to `UIColor` and resolving that instead
    /// loses the light and dark variants of a `Color` made from a dynamic `UIColor`.
    private func skipBeforeIOS17() throws {
        guard #available(iOS 17, *) else {
            throw XCTSkip("Resolving a SwiftUI Color for an appearance needs iOS 17")
        }
    }

    /// Resolves `color` the way SwiftUI does when drawing it in the given appearance.
    private func hex(_ color: Color, in style: UIUserInterfaceStyle) -> String {
        guard #available(iOS 17, *) else { return "" }
        var environment = EnvironmentValues()
        environment.colorScheme = style == .dark ? .dark : .light
        let components = color.resolve(in: environment).cgColor.components ?? []
        let rgb = components.prefix(3).map { Int(($0 * 255).rounded()) }
        return String(format: "#%02X%02X%02X", rgb[0], rgb[1], rgb[2])
    }

    private var window: UIWindow?

    private func render<Content: View>(_ view: Content) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        self.window = window
        spinRunLoop()
    }

    private func spinRunLoop() {
        window?.rootViewController?.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    }

    override func tearDown() {
        window = nil
    }
}

/// Records the theme every time a ``ThemeReader`` renders.
@MainActor
private final class ThemeProbe {
    var themes: [FaceLivenessDetectorTheme] = []
}

@MainActor
private final class ThemeHost: ObservableObject {
    @Published var theme = FaceLivenessDetectorTheme()
}

private struct ThemeReader: View {
    @Environment(\.faceLivenessDetectorTheme) private var theme
    let probe: ThemeProbe

    var body: some View {
        probe.themes.append(theme)
        return Text("Theme").foregroundColor(theme.colors.primary)
    }
}

private struct ThemedRoot: View {
    @ObservedObject var host: ThemeHost
    let probe: ThemeProbe

    var body: some View {
        ThemeReader(probe: probe)
            .faceLivenessDetectorTheme(host.theme)
    }
}
