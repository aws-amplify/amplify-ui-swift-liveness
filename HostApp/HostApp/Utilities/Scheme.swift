//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

enum Scheme {
    case light
    case dark

    var buttonImage: String {
        switch self {
        case .light: return "moon.fill"
        case .dark: return "sun.max.fill"
        }
    }

    mutating func toggle() {
        switch self {
        case .light: self = .dark
        case .dark: self = .light
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }
}
