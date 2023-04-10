//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct CountdownInstructionContainerView: View {
    var viewModel: FaceLivenessDetectionViewModel
    let onCountdownComplete: () -> Void
    @State var duration: Double = 3

    var body: some View {
        switch viewModel.livenessState.state {
        case .pendingFacePreparedConfirmation(let reason):
            InstructionView(
                text: .init(reason.rawValue),
                backgroundColor: .livenessBackground
            )
        case .countingDown:
            InstructionView(
                text: .challenge_instruction_hold_face_during_countdown,
                backgroundColor: .livenessBackground
            )

            CountdownView(
                duration: duration,
                onComplete: onCountdownComplete
            )
                .padding(.top)
        case .completedDisplayingFreshness:
            InstructionView(
                text: .challenge_verifying,
                backgroundColor: .livenessBackground
            )
        default:
            EmptyView()
        }
    }
}
