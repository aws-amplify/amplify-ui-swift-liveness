//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import AVFoundation
@testable import FaceLiveness

/// Waits for `videoChunker`'s writer to reach `status`, which `prepare()` changes off the
/// calling thread.
func waitForWriter(
    of videoChunker: VideoChunker,
    toReach status: AVAssetWriter.Status,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let reached = XCTNSPredicateExpectation(
        predicate: NSPredicate { _, _ in videoChunker.assetWriter.status == status },
        object: nil
    )
    let result = XCTWaiter.wait(for: [reached], timeout: 5)
    XCTAssertEqual(result, .completed, "writer status is \(videoChunker.assetWriter.status.rawValue)", file: file, line: line)
}
