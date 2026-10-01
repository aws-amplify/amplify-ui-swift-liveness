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

    /// Android insets the instruction 24dp from the preview's edges while the oval is on
    /// screen (exactly when the REC indicator shows) and 16dp otherwise.
    private var instructionPadding: CGFloat {
        viewModel.livenessState.shouldDisplayRecordingIcon ? 24 : 16
    }

    var body: some View {
        ZStack {
            ZStack {
                Color.black
                videoView

                // Like Android, the instruction sits at the top of the camera preview.
                VStack(spacing: 5) {
                    InstructionContainerView(
                        viewModel: viewModel
                    )

                    Spacer()
                }
                .padding(instructionPadding)
                .aspectRatio(3/4, contentMode: .fit)
                .frame(maxWidth: .infinity)
            }
            .edgesIgnoringSafeArea(.all)

            // Like Android, the REC indicator and close button sit in the screen's top
            // corners rather than above the instruction, so they don't push it onto the oval.
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
                .padding(16)

                Spacer()
            }
        }
    }
}
