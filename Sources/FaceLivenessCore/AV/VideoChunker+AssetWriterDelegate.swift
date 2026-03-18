//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import AVFoundation

extension VideoChunker {
    class AssetWriterDelegate: NSObject, AVAssetWriterDelegate {
        private var initialSegmentData: Data?
        private weak var segmentProcessor: VideoSegmentProcessor?

        func set(segmentProcessor: VideoSegmentProcessor) {
            self.segmentProcessor = segmentProcessor
        }

        func assetWriter(
            _ writer: AVAssetWriter,
            didOutputSegmentData segmentData: Data,
            segmentType: AVAssetSegmentType,
            segmentReport: AVAssetSegmentReport?
        ) {
            if segmentType == .initialization {
                assert(initialSegmentData == nil, "Received second initialization segment.")
                initialSegmentData = segmentData
                return
            }

            guard let initialSegmentData else {
                return assertionFailure(
                    "Received seperable segment before receiving initialization segment."
                )
            }

            segmentProcessor?.process(initalSegment: initialSegmentData, currentSeparableSegment: segmentData)
        }
    }
}
