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
    let cancelButtonOptions: CancelButtonOptions

    init(
        viewModel: FaceLivenessDetectionViewModel,
        cancelButtonOptions: CancelButtonOptions = .init(),
        @ViewBuilder videoView: @escaping () -> VideoView
    ) {
        self.viewModel = viewModel
        self.cancelButtonOptions = cancelButtonOptions
        self.videoView = videoView()

        self._displayResultsView = .init(
            get: { viewModel.livenessState.state == .completed },
            set: { _ in }
        )
    }

    /// Where the preview's top and the bottom of the REC indicator and close button row are,
    /// in the `layoutSpace` coordinate space.
    @State private var previewMinY: CGFloat = 0
    @State private var controlsMaxY: CGFloat = 0

    /// The instruction is inset 24pt from the preview's edges while the face guide is on screen
    /// and 16pt otherwise.
    private var instructionPadding: CGFloat {
        viewModel.livenessState.isFaceGuideDisplayed ? 24 : 16
    }

    private var instructionTopInset: CGFloat {
        LivenessPreviewGeometry.instructionTopInset(
            instructionPadding,
            previewMinY: previewMinY,
            controlsMaxY: controlsMaxY
        )
    }

    var body: some View {
        ZStack {
            ZStack {
                Color.black
                videoView

                VStack(spacing: 5) {
                    InstructionContainerView(
                        viewModel: viewModel
                    )

                    Spacer()
                }
                .padding(.top, instructionTopInset)
                .padding([.leading, .trailing, .bottom], instructionPadding)
                .aspectRatio(3/4, contentMode: .fit)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: PreviewMinYKey.self,
                            value: proxy.frame(in: .named(layoutSpace)).minY
                        )
                    }
                )
                .frame(maxWidth: .infinity)
            }
            .edgesIgnoringSafeArea(.all)

            // The REC indicator and close button sit in the screen's top corners rather than
            // above the instruction, so they don't push it onto the oval.
            VStack {
                HStack(alignment: .top) {
                    if viewModel.livenessState.shouldDisplayRecordingIcon {
                        RecordingButton()
                            .accessibilityHidden(true)
                    }

                    Spacer()

                    CancelButton(
                        options: cancelButtonOptions,
                        action: viewModel.closeButtonAction
                    )
                }
                .padding(16)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ControlsMaxYKey.self,
                            value: proxy.frame(in: .named(layoutSpace)).maxY
                        )
                    }
                )

                Spacer()
            }
        }
        .coordinateSpace(name: layoutSpace)
        .onPreferenceChange(PreviewMinYKey.self) { previewMinY = $0 ?? previewMinY }
        .onPreferenceChange(ControlsMaxYKey.self) { controlsMaxY = $0 ?? controlsMaxY }
    }
}

private let layoutSpace = "FaceLivenessDetectionLayout"

/// Optional so a view that doesn't measure, and so contributes the default, can't overwrite a
/// measurement while the values are combined.
private struct PreviewMinYKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}

private struct ControlsMaxYKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}
