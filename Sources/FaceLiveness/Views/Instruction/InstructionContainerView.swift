//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
import Combine

struct InstructionContainerView: View {
    @ObservedObject var viewModel: FaceLivenessDetectionViewModel

    var body: some View {
        switch viewModel.livenessState.state {
        case .displayingFreshness:
            InstructionView(
                text: LocalizedStrings.challenge_instruction_hold_still,
                backgroundColor: .livenessPrimaryBackground,
                textColor: .livenessPrimaryLabel,
                font: .title
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
                backgroundColor: .livenessErrorBackground,
                textColor: .livenessErrorLabel,
                font: .title
            )
            .onAppear {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: LocalizedStrings.challenge_instruction_move_face_back
                )
            }

        case .awaitingFaceInOvalMatch(let reason, let percentage):
            InstructionView(
                text: .init(reason.rawValue),
                backgroundColor: .livenessPrimaryBackground,
                textColor: .livenessPrimaryLabel,
                font: .title
            )

            ProgressBarView(
                emptyColor: .white,
                borderColor: .hex("#AEB3B7"),
                fillColor: .livenessPrimaryBackground,
                indicatorColor: .livenessPrimaryBackground,
                percentage: percentage
            )
            .frame(width: 200, height: 30)
        case .recording(ovalDisplayed: true):
            InstructionView(
                text: LocalizedStrings.challenge_instruction_move_face_closer,
                backgroundColor: .livenessPrimaryBackground,
                textColor: .livenessPrimaryLabel,
                font: .title
            )
            .onAppear {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: LocalizedStrings.challenge_instruction_move_face_closer
                )
            }

            ProgressBarView(
                emptyColor: .white,
                borderColor: .hex("#AEB3B7"),
                fillColor: .livenessPrimaryBackground,
                indicatorColor: .livenessPrimaryBackground,
                percentage: 0.2
            )
            .frame(width: 200, height: 30)
        case .pendingFacePreparedConfirmation(let reason):
            InstructionView(
                text: .init(reason.rawValue),
                backgroundColor: .livenessPrimaryBackground,
                textColor: .livenessPrimaryLabel,
                font: .title
            )
        case .completedDisplayingFreshness:
            InstructionView(
                text: LocalizedStrings.challenge_verifying,
                backgroundColor: .livenessBackground
            )
            .onAppear {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: LocalizedStrings.challenge_verifying
                )
            }
        case .faceMatched:
            InstructionView(
                text: LocalizedStrings.challenge_instruction_hold_still,
                backgroundColor: .livenessPrimaryBackground,
                textColor: .livenessPrimaryLabel,
                font: .title
            )
        default:
            EmptyView()
        }
    }
}
