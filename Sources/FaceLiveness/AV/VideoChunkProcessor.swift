//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

protocol VideoSegmentProcessor {
    func process(initalSegment: Data, currentSeparableSegment: Data)
}
