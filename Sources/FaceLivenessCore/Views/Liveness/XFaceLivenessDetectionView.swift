//
//  XFaceLivenessDetectionView.swift
//  XFaceLiveness
//
//  Created by Ruslan Serebriakov on 3/17/26.
//  Copyright © 2026 X Corp. All rights reserved.
//

import SwiftUI

struct XFaceLivenessDetectionView<VideoView: View>: View {
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

    // Oval dimensions matching Figma (250 x 344)
    private let ovalWidth: CGFloat = 250
    private let ovalHeight: CGFloat = 344

    /// Show static oval only when SDK hasn't drawn its dynamic oval yet
    private var shouldShowStaticOval: Bool {
        switch viewModel.livenessState.state {
        case .recording(ovalDisplayed: true),
             .awaitingFaceInOvalMatch(_, _),
             .faceMatched,
             .displayingFreshness,
             .completedDisplayingFreshness,
             .completedNoLightCheck:
            // SDK's oval is displayed in these states - hide our static one
            return false
        default:
            // Show static oval before SDK displays its own
            return true
        }
    }

    var body: some View {
        ZStack {
            Color.black

            // Camera view layer
            videoView

            // Overlay layer with oval and UI elements
            GeometryReader { geometry in
                let ovalCenter = CGPoint(
                    x: geometry.size.width / 2,
                    y: geometry.size.height * 0.42
                )
                let ovalSize = CGSize(width: ovalWidth, height: ovalHeight)
                let ovalTopY = ovalCenter.y - ovalHeight / 2

                // Static oval overlay (visible before SDK draws its dynamic oval)
                if shouldShowStaticOval {
                    // Dark overlay with oval cutout
                    XOvalCutoutOverlay(ovalSize: ovalSize, ovalCenter: ovalCenter)
                        .fill(Color.black, style: FillStyle(eoFill: true))

                    // White oval stroke
                    Ellipse()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: ovalWidth, height: ovalHeight)
                        .position(ovalCenter)
                }

                // Info button (top-right)
                HStack {
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }

                // Instruction pill positioned just above the oval
                XInstructionContainerView(viewModel: viewModel)
                    .position(x: geometry.size.width / 2, y: ovalTopY - 30)
            }
            .ignoresSafeArea()
        }
        .edgesIgnoringSafeArea(.all)
        .preferredColorScheme(.dark)
    }
}

// MARK: - X Instruction Container View (Figma Design)

/// Instruction container matching Figma specs:
/// - White background pill with black text
/// - Font: Bold 20px
/// - Always shows text (never empty)
struct XInstructionContainerView: View {
    @ObservedObject var viewModel: FaceLivenessDetectionViewModel

    var body: some View {
        XInstructionView(text: instructionText)
    }

    /// Returns instruction text for all states - never nil
    private var instructionText: String {
        switch viewModel.livenessState.state {
        case .displayingFreshness, .faceMatched:
            return LocalizedStrings.challenge_instruction_hold_still

        case .awaitingFaceInOvalMatch(.faceTooClose, _):
            return LocalizedStrings.challenge_instruction_move_face_back

        case .awaitingFaceInOvalMatch(let reason, _):
            return reason.localizedValue

        case .recording(ovalDisplayed: true):
            return LocalizedStrings.challenge_instruction_move_face_closer

        case .pendingFacePreparedConfirmation(let reason):
            return reason.localizedValue

        case .completedDisplayingFreshness, .completedNoLightCheck:
            return LocalizedStrings.challenge_verifying

        default:
            // Initial/unknown state - always show default instruction
            return "Put your face in the circle"
        }
    }
}

// MARK: - X Instruction View (Figma Design)

/// Instruction pill matching Figma specs:
/// - Background: white
/// - Text: black, Bold 20px
/// - Size: ~261 x 44 (hug content)
struct XInstructionView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.black)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white)
            )
    }
}

// MARK: - Oval Cutout Shape

/// Shape that creates a dark overlay with an oval cutout
struct XOvalCutoutOverlay: Shape {
    let ovalSize: CGSize
    let ovalCenter: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Full rectangle
        path.addRect(rect)
        // Oval cutout (subtracting with even-odd fill)
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
