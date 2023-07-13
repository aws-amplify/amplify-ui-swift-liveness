//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

extension FaceLivenessDetectionViewModel: VideoSegmentProcessor {
    func process(initalSegment: Data, currentSeparableSegment: Data) {
        log.verbose("processing video segment of size \(currentSeparableSegment.count)")
        let chunk = chunk(initial: initalSegment, current: currentSeparableSegment)
        sendVideoEvent(data: chunk, videoEventTime: .zero)
        if !hasSentFinalVideoEvent,
           case .completedDisplayingFreshness = livenessState.state {
            log.verbose("Preparing to send final video event")
            sendFinalVideoChunk(data: chunk, videoEventTime: .zero)
        }
    }
}
