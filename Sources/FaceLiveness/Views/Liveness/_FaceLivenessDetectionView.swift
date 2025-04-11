//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct _FaceLivenessDetectionView<VideoView: View>: View {
    let videoView: VideoView
    @ObservedObject var viewModel: FaceLivenessDetectionViewModel
    @Binding var displayResultsView: Bool

    init(
        viewModel: FaceLivenessDetectionViewModel,
        @ViewBuilder videoView: @escaping () -> VideoView
    ) {
        self.viewModel = viewModel
        self.videoView = videoView()

        self._displayResultsView = .init(
            get: { viewModel.livenessState.state == .completed },
            set: { _ in }
        )
    }

    var body: some View {
        ZStack {
            Color.black
            ZStack {
                videoView
                VStack {
                    HStack(alignment: .top) {
                        if viewModel.livenessState.shouldDisplayRecordingIcon {
                            RecordingButton()
                                .accessibilityHidden(true)
                        }

                        Spacer()

                        CloseButton(
                            action: viewModel.closeButtonAction
                        )
                    }
                    .padding()

                    InstructionContainerView(
                        viewModel: viewModel
                    )

                    Spacer()
                }
                .padding([.leading, .trailing])
                .aspectRatio(3/4, contentMode: .fit)
                .frame(maxWidth: .infinity)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}
