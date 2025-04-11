//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import AVFoundation

final class LivenessAVAssetWriter: AVAssetWriter {
    init() {
        super.init(contentType: .mpeg4Movie)
        outputFileTypeProfile = .mpeg4CMAFCompliant
        preferredOutputSegmentInterval = CMTime(
            seconds: 1,
            preferredTimescale: 1
        )
        initialSegmentStartTime = CMTime(seconds: 0, preferredTimescale: 240)
    }
}
