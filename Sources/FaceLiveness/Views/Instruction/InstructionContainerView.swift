//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct InstructionContainerView: View {
    @ObservedObject var viewModel: FaceLivenessDetectionViewModel

    var body: some View {
        switch viewModel.livenessState.state {
        case .displayingFreshness:
            InstructionView(
                text: .challenge_instruction_hold_still,
                backgroundColor: .livenessPrimaryBackground,
                textColor: .livenessPrimaryLabel,
                font: .title
            )

        case .awaitingFaceInOvalMatch(.faceTooClose, _):
            InstructionView(
                text: .challenge_instruction_move_face_back,
                backgroundColor: .livenessErrorBackground,
                textColor: .livenessErrorLabel,
                font: .title
            )

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
                text: .challenge_instruction_move_face_closer,
                backgroundColor: .livenessPrimaryBackground,
                textColor: .livenessPrimaryLabel,
                font: .title
            )

            ProgressBarView(
                emptyColor: .white,
                borderColor: .hex("#AEB3B7"),
                fillColor: .livenessPrimaryBackground,
                indicatorColor: .livenessPrimaryBackground,
                percentage: 0.2
            )
            .frame(width: 200, height: 30)
        default:
            EmptyView()
        }
    }
}
