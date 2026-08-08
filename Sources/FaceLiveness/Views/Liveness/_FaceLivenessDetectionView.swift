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
    @Environment(\.livenessTheme) var theme

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

    /// During the freshness color check the AWS backend validates overlay
    /// colors that are semi-transparent. A white background is required
    /// so the blended colors match the expected values.
    private var isFreshnessActive: Bool {
        switch viewModel.livenessState.state {
        case .displayingFreshness, .faceMatched:
            return true
        default:
            return false
        }
    }

    /// Whether the SDK has drawn its dynamic oval (hide the static placeholder).
    private var shouldShowStaticOval: Bool {
        switch viewModel.livenessState.state {
        case .recording(ovalDisplayed: true),
             .awaitingFaceInOvalMatch(_, _),
             .faceMatched,
             .displayingFreshness,
             .completedDisplayingFreshness,
             .completedNoLightCheck:
            return false
        default:
            return true
        }
    }

    var body: some View {
        ZStack {
            (isFreshnessActive ? Color.white : Color.black)
            switch theme.layout {
            case .default:
                defaultLayout
            case .fullScreenOval(let ovalWidth, let ovalHeight, let ovalYRatio, let instructionOffset):
                fullScreenOvalLayout(
                    ovalWidth: ovalWidth,
                    ovalHeight: ovalHeight,
                    ovalYRatio: ovalYRatio,
                    instructionOffset: instructionOffset
                )
            }
        }
        .edgesIgnoringSafeArea(.all)
    }

    // MARK: - Default Layout (VStack, top bar, 3:4 aspect ratio)

    private var defaultLayout: some View {
        ZStack {
            videoView
            VStack {
                HStack(alignment: .top) {
                    if theme.components.showRecordingIndicator,
                       viewModel.livenessState.shouldDisplayRecordingIcon {
                        RecordingButton()
                            .accessibilityHidden(true)
                    }

                    Spacer()

                    if theme.components.showCloseButton {
                        CloseButton(
                            action: viewModel.closeButtonAction
                        )
                    }
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

    // MARK: - Full-Screen Oval Layout (GeometryReader, static oval, instruction above)

    private func fullScreenOvalLayout(
        ovalWidth: CGFloat,
        ovalHeight: CGFloat,
        ovalYRatio: CGFloat,
        instructionOffset: CGFloat
    ) -> some View {
        ZStack {
            videoView

            GeometryReader { geometry in
                let ovalCenter = CGPoint(
                    x: geometry.size.width / 2,
                    y: geometry.size.height * ovalYRatio
                )
                let ovalSize = CGSize(width: ovalWidth, height: ovalHeight)
                let ovalTopY = ovalCenter.y - ovalHeight / 2

                // Static oval overlay (visible before SDK draws its dynamic oval)
                if shouldShowStaticOval {
                    OvalCutoutOverlay(ovalSize: ovalSize, ovalCenter: ovalCenter)
                        .fill(Color.black, style: FillStyle(eoFill: true))

                    Ellipse()
                        .stroke(Color.white, lineWidth: theme.oval.strokeWidth)
                        .frame(width: ovalWidth, height: ovalHeight)
                        .position(ovalCenter)
                }

                // Instruction pill positioned above the oval
                InstructionContainerView(viewModel: viewModel)
                    .position(x: geometry.size.width / 2, y: ovalTopY - instructionOffset)
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Oval Cutout Shape

/// Shape that creates a mask overlay with an oval cutout using even-odd fill.
struct OvalCutoutOverlay: Shape {
    let ovalSize: CGSize
    let ovalCenter: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        let ovalRect = CGRect(
            x: ovalCenter.x - ovalSize.width / 2,
            y: ovalCenter.y - ovalSize.height / 2,
            width: ovalSize.width,
            height: ovalSize.height
        )
        path.addEllipse(in: ovalRect)
        return path
    }
}
