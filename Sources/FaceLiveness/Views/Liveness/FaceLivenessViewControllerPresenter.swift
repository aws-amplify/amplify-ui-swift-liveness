//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import UIKit
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

protocol FaceLivenessViewControllerPresenter: AnyObject {
    func drawOvalInCanvas(_ ovalRect: CGRect)
    func displayFreshness(colorSequences: [FaceLivenessSession.DisplayColor])
    func displaySingleFrame(uiImage: UIImage)
}
