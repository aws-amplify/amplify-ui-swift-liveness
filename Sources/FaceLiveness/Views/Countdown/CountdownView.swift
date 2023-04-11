//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
import Combine

struct CountdownView: View {
    @ObservedObject var viewModel: CountdownView.ViewModel

    init(
        duration: Double,
        tickRate: Double = 0.02,
        onComplete: @escaping () -> Void
    ) {
        viewModel = .init(
            duration: duration,
            tickRate: tickRate,
            onComplete: onComplete
        )
    }

    var body: some View {
        ZStack {
            Circle()
                .foregroundColor(.livenessBackground)
                .frame(width: 68, height: 68)

            Circle()
                .trim(from: 0, to: min(viewModel.percentage, 1.0))
                .stroke(Color.livenessPrimaryBackground, lineWidth: 4)
                .padding(6)
                .frame(width: 68, height: 68)
                .rotationEffect(Angle.init(degrees: 270))
                .animation(.linear, value: viewModel.percentage)

            Text(viewModel.formatted(remaining: viewModel.remaining))
                .accessibilityHidden(true)
                .font(.system(size: 24, weight: .semibold))
        }
        .onReceive(viewModel.timer) { _ in
            viewModel.timerInvoked()
        }
        .onReceive(viewModel.$timerAccessibilityValue) { value in
            UIAccessibility.post(notification: .announcement, argument: value)
        }
    }
}

struct CountdownView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray
            CountdownView(
                duration: 3,
                tickRate: 0.05,
                onComplete: { print("donesies!") }
            )
        }
    }
}
