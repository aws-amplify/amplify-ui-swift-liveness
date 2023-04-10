//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

extension Date {
    var timestampMilliseconds: UInt64 {
        UInt64(timeIntervalSince1970 * 1_000)
    }
}
