//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

extension FinalClientEvent {
    init(
        sessionConfiguration: FaceLivenessSession.SessionConfiguration,
        initialClientEvent: InitialClientEvent,
        videoSize: CGSize,
        faceMatchedStart: UInt64,
        faceMatchedEnd: UInt64,
        videoEnd: UInt64
    ) {
        let normalizedBoundingBox = sessionConfiguration
            .ovalMatchChallenge
            .oval.boundingBox
            .normalize(within: videoSize)

        self.init(
            initialClientEvent: initialClientEvent,
            targetFace: .init(
                initialEvent: .init(
                    boundingBox: normalizedBoundingBox,
                    startTimestamp: faceMatchedStart
                ),
                endTimestamp: faceMatchedEnd
            ),
            videoEndTimeStamp: videoEnd
        )
    }
}
