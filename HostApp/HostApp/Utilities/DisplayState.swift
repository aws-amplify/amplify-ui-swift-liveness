//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

enum DisplayState {
    case code
    case controls

    var buttonImage: String {
        switch self {
        case .code: return "switch.2"
        case .controls: return "chevron.left.forwardslash.chevron.right"
        }
    }

    mutating func toggle() {
        switch self {
        case .code: self = .controls
        case .controls: self = .code
        }
    }
}
