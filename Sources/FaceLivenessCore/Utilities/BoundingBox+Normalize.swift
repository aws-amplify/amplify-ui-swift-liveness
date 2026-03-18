//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

extension FaceLivenessSession.BoundingBox {
    func normalize(within videoSize: CGSize) -> Self {
        .init(
            x: x / videoSize.width,
            y: y / videoSize.height,
            width: width / videoSize.width,
            height: height / videoSize.height
        )
    }
}
