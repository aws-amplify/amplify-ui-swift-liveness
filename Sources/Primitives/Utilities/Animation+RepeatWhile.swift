//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import SwiftUI

extension Animation {
    func `repeat`(while expression: Bool, autoreverses: Bool) -> Animation {
        expression
        ? repeatForever(autoreverses: autoreverses)
        : self
    }
}
