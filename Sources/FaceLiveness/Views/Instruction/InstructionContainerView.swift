//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
import Combine
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

struct InstructionContainerView: View {
    @ObservedObject var viewModel: FaceLivenessDetectionViewModel
    @Environment(\.livenessTheme) var theme

    var body: some View {
        switch viewModel.livenessState.state {
        case .displayingFreshness:
            themedInstructionView(
                text: LocalizedStrings.challenge_instruction_hold_still,
                defaultBackgroundColor: theme.colors.primary,
                defaultTextColor: theme.colors.onPrimary
            )
            .onAppear {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: LocalizedStrings.challenge_instruction_hold_still
                )
            }

        case .awaitingFaceInOvalMatch(.faceTooClose, _):
            themedInstructionView(
                text: LocalizedStrings.challenge_instruction_move_face_back,
                defaultBackgroundColor: theme.colors.error,
                defaultTextColor: theme.colors.onError
            )
            .onAppear {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: LocalizedStrings.challenge_instruction_move_face_back
                )
            }

        case .awaitingFaceInOvalMatch(let reason, let percentage):
            themedInstructionView(
                text: .init(reason.localizedValue),
                defaultBackgroundColor: theme.colors.primary,
                defaultTextColor: theme.colors.onPrimary
            )

            if theme.components.showProgressBar {
                ProgressBarView(
                    emptyColor: .white,
                    borderColor: .hex("#AEB3B7"),
                    fillColor: theme.colors.primary,
                    indicatorColor: theme.colors.primary,
                    percentage: percentage
                )
                .frame(width: 200, height: 30)
            }
        case .recording(ovalDisplayed: true):
            themedInstructionView(
                text: LocalizedStrings.challenge_instruction_move_face_closer,
                defaultBackgroundColor: theme.colors.primary,
                defaultTextColor: theme.colors.onPrimary
            )
            .onAppear {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: LocalizedStrings.challenge_instruction_move_face_closer
                )
            }

            if theme.components.showProgressBar {
                ProgressBarView(
                    emptyColor: .white,
                    borderColor: .hex("#AEB3B7"),
                    fillColor: theme.colors.primary,
                    indicatorColor: theme.colors.primary,
                    percentage: 0.2
                )
                .frame(width: 200, height: 30)
            }
        case .pendingFacePreparedConfirmation(let reason):
            themedInstructionView(
                text: .init(reason.localizedValue),
                defaultBackgroundColor: theme.colors.primary,
                defaultTextColor: theme.colors.onPrimary
            )
        case .completedDisplayingFreshness:
            themedInstructionView(
                text: LocalizedStrings.challenge_verifying,
                defaultBackgroundColor: theme.colors.background,
                defaultTextColor: theme.colors.onBackground
            )
            .onAppear {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: LocalizedStrings.challenge_verifying
                )
            }
        case .completedNoLightCheck:
            themedInstructionView(
                text: LocalizedStrings.challenge_verifying,
                defaultBackgroundColor: theme.colors.background,
                defaultTextColor: theme.colors.onBackground
            )
            .onAppear {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: LocalizedStrings.challenge_verifying
                )
            }
        case .faceMatched:
            if let challenge = viewModel.challengeReceived,
               case .faceMovementAndLightChallenge = challenge {
                themedInstructionView(
                    text: LocalizedStrings.challenge_instruction_hold_still,
                    defaultBackgroundColor: theme.colors.primary,
                    defaultTextColor: theme.colors.onPrimary
                )
            } else {
                EmptyView()
            }
        default:
            EmptyView()
        }
    }

    /// Creates an ``InstructionView`` using theme overrides when set,
    /// falling back to the provided per-state default colors.
    private func themedInstructionView(
        text: String,
        defaultBackgroundColor: Color,
        defaultTextColor: Color
    ) -> InstructionView {
        InstructionView(
            text: text,
            backgroundColor: theme.instruction.backgroundColor ?? defaultBackgroundColor,
            textColor: theme.instruction.textColor ?? defaultTextColor,
            font: theme.instruction.font,
            useCapsuleShape: theme.instruction.useCapsuleShape,
            cornerRadius: theme.instruction.cornerRadius,
            padding: theme.instruction.padding
        )
    }
}
