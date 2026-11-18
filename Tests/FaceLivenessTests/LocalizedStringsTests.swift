//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import FaceLiveness

final class LocalizedStringsTests: XCTestCase {
    private var originalMainBundleClass: AnyClass?

    override func setUp() {
        originalMainBundleClass = object_getClass(Bundle.main)
        // switch languages the way apps with an in-app language picker do: by overriding
        // `Bundle.main`'s lookup
        object_setClass(Bundle.main, LanguageOverridingBundle.self)
    }

    override func tearDown() {
        LanguageOverridingBundle.translations = [:]
        if let originalMainBundleClass {
            object_setClass(Bundle.main, originalMainBundleClass)
        }
    }

    /// Given: A string the Liveness UI has already shown in one language
    /// When: The app switches language while running
    /// Then: The next read returns the new language
    func testStringsFollowALanguageChangeWhileTheAppRuns() {
        let key = "amplify_ui_liveness_get_ready_begin_check"

        LanguageOverridingBundle.translations = [key: "Start video check"]
        XCTAssertEqual(LocalizedStrings.get_ready_begin_check, "Start video check")

        LanguageOverridingBundle.translations = [key: "Commencer la vérification vidéo"]
        XCTAssertEqual(LocalizedStrings.get_ready_begin_check, "Commencer la vérification vidéo")
    }

    /// Given: An app without its own translation for a string
    /// When: The string is read
    /// Then: The Liveness default is used
    func testStringsFallBackToTheLivenessDefault() {
        XCTAssertEqual(LocalizedStrings.get_ready_begin_check, "Start video check")
    }
}

/// Stands in for an app's language override of `Bundle.main`.
private final class LanguageOverridingBundle: Bundle, @unchecked Sendable {
    nonisolated(unsafe) static var translations: [String: String] = [:]

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        Self.translations[key] ?? value ?? key
    }
}
