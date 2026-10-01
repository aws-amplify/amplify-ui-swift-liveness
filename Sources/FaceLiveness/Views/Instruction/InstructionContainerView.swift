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
    @Environment(\.faceLivenessDetectorTheme) private var theme
    @ObservedObject var viewModel: FaceLivenessDetectionViewModel

    var body: some View {
        switch viewModel.livenessState.state {
        case .displayingFreshness:
            InstructionView(
                text: LocalizedStrings.challenge_instruction_hold_still,
                backgroundColor: theme.colors.primary,
                textColor: theme.colors.onPrimary,
                font: theme.fonts.title
            )
            .onAppear {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: LocalizedStrings.challenge_instruction_hold_still
                )
            }

        case .awaitingFaceInOvalMatch(.faceTooClose, _):
            InstructionView(
                text: LocalizedStrings.challenge_instruction_move_face_back,
                backgroundColor: theme.colors.error,
                textColor: theme.colors.onError,
                font: theme.fonts.title
            )
            .onAppear {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: LocalizedStrings.challenge_instruction_move_face_back
                )
            }

        case .awaitingFaceInOvalMatch(let reason, let percentage):
            InstructionView(
                text: .init(reason.localizedValue),
                backgroundColor: theme.colors.primary,
                textColor: theme.colors.onPrimary,
                font: theme.fonts.title
            )

            ProgressBarView(
                emptyColor: theme.colors.surface,
                borderColor: .hex("#AEB3B7"),
                fillColor: theme.colors.primary,
                indicatorColor: theme.colors.primary,
                percentage: percentage
            )
            .frame(width: 200, height: 30)
        case .recording(ovalDisplayed: true):
            InstructionView(
                text: LocalizedStrings.challenge_instruction_move_face_closer,
                backgroundColor: theme.colors.primary,
                textColor: theme.colors.onPrimary,
                font: theme.fonts.title
            )
            .onAppear {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: LocalizedStrings.challenge_instruction_move_face_closer
                )
            }

            ProgressBarView(
                emptyColor: theme.colors.surface,
                borderColor: .hex("#AEB3B7"),
                fillColor: theme.colors.primary,
                indicatorColor: theme.colors.primary,
                percentage: 0.2
            )
            .frame(width: 200, height: 30)
        case .pendingFacePreparedConfirmation(let reason):
            InstructionView(
                text: .init(reason.localizedValue),
                backgroundColor: theme.colors.primary,
                textColor: theme.colors.onPrimary,
                font: theme.fonts.title
            )
        case .completedDisplayingFreshness:
            InstructionView(
                text: LocalizedStrings.challenge_verifying,
                backgroundColor: theme.colors.background
            )
            .onAppear {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: LocalizedStrings.challenge_verifying
                )
            }
        case .completedNoLightCheck:
            InstructionView(
                text: LocalizedStrings.challenge_verifying,
                backgroundColor: theme.colors.background
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
                InstructionView(
                    text: LocalizedStrings.challenge_instruction_hold_still,
                    backgroundColor: theme.colors.primary,
                    textColor: theme.colors.onPrimary,
                    font: theme.fonts.title
                )
            } else {
                EmptyView()
            }
        default:
            EmptyView()
        }
    }
}
