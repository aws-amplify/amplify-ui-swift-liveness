//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
import AVFoundation
import AWSPredictionsPlugin

struct CameraView: UIViewControllerRepresentable {
    @ObservedObject var faceLivenessDetectionViewModel: FaceLivenessDetectionViewModel
    let ovalStyle: FaceLivenessTheme.OvalStyle

    init(
        faceLivenessDetectionViewModel: FaceLivenessDetectionViewModel,
        ovalStyle: FaceLivenessTheme.OvalStyle = .init()
    ) {
        self.faceLivenessDetectionViewModel = faceLivenessDetectionViewModel
        self.ovalStyle = ovalStyle
    }

    func makeUIViewController(
        context: Context
    ) -> _LivenessViewController {
        let livenessViewController = _LivenessViewController(
            viewModel: faceLivenessDetectionViewModel,
            ovalStyle: ovalStyle
        )
        return livenessViewController
    }

    func updateUIViewController(
        _ uiViewController: _LivenessViewController,
        context: Context
    ) {}
}
