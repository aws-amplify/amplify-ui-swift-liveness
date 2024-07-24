//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

struct GetReadyPageView: View {
    let beginCheckButtonDisabled: Bool
    let onBegin: () -> Void
    let challenge: Challenge
    let cameraPosition: LivenessCaptureDevicePosition
    
    init(
        onBegin: @escaping () -> Void,
        beginCheckButtonDisabled: Bool = false,
        challenge: Challenge,
        cameraPosition: LivenessCaptureDevicePosition
    ) {
        self.onBegin = onBegin
        self.beginCheckButtonDisabled = beginCheckButtonDisabled
        self.challenge = challenge
        self.cameraPosition = cameraPosition
    }

    var body: some View {
        VStack {
            ZStack {
                CameraPreviewView(model: CameraPreviewViewModel(cameraPosition: cameraPosition))
                VStack {
                    WarningBox(
                        titleText: LocalizedStrings.get_ready_photosensitivity_title,
                        bodyText: LocalizedStrings.get_ready_photosensitivity_description,
                        popoverContent: { photosensitivityWarningPopoverContent }
                    )
                    .accessibilityElement(children: .combine)
                    .opacity(challenge.type == .faceMovementAndLightChallenge ? 1.0 : 0.0)
                    Text(LocalizedStrings.preview_center_your_face_text)
                        .font(.title)
                        .multilineTextAlignment(.center)
                    Spacer()
                }.padding()
            }
            beginCheckButton
        }
    }

    private var beginCheckButton: some View {
        Button(
            action: onBegin,
            label: {
                Text(LocalizedStrings.get_ready_begin_check)
                    .foregroundColor(.livenessPrimaryLabel)
                    .frame(maxWidth: .infinity)
            }
        )
        .disabled(beginCheckButtonDisabled)
        .frame(height: 52)
        ._background { Color.livenessPrimaryBackground }
        .cornerRadius(14)
        .padding([.leading, .trailing])
        .padding(.bottom, 16)
    }

    private var photosensitivityWarningPopoverContent: some View {
        VStack {
            Text(LocalizedStrings.get_ready_photosensitivity_dialog_title)
                .font(.system(size: 20, weight: .medium))
                .frame(alignment: .center)
                .padding()
            Text(LocalizedStrings.get_ready_photosensitivity_dialog_description)
                .padding()
            Spacer()
        }
    }
}

struct GetReadyPageView_Previews: PreviewProvider {
    static var previews: some View {
        GetReadyPageView(onBegin: {}, 
                         challenge: .init(version: "2.0.0",
                                              type: .faceMovementAndLightChallenge),
                         cameraPosition: .front)
    }
}
