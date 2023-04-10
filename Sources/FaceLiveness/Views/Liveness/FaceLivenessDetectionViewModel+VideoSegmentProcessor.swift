//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

extension FaceLivenessDetectionViewModel: VideoSegmentProcessor {
    func process(initalSegment: Data, currentSeparableSegment: Data) {
        let chunk = chunk(initial: initalSegment, current: currentSeparableSegment)
        sendVideoEvent(data: chunk, videoEventTime: .zero)
        if !hasSentFinalVideoEvent,
           case .completedDisplayingFreshness = livenessState.state {
            sendFinalVideoChunk(data: chunk, videoEventTime: .zero)
        }
    }
}
