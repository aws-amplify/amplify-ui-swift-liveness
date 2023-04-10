//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
import Combine

extension CountdownView {
    class ViewModel: ObservableObject {
        let initialDuration: Double
        let rate: Double
        let timer: Timer.TimerPublisher
        let tickRate: Double
        let timerCancellable: AnyCancellable?
        let onComplete: () -> Void

        @Published var timerAccessibilityValue: String
        @Published var remaining: Double
        @Published var percentage: Double = 1.0

        init(
            duration: Double,
            tickRate: Double = 0.2,
            onComplete: @escaping () -> Void
        ) {
            self.initialDuration = duration
            self.remaining = duration
            self.rate = 100 / (initialDuration / tickRate) / 100
            self.tickRate = tickRate
            self.onComplete = onComplete
            self.timer = .init(
                interval: tickRate,
                runLoop: .main,
                mode: .default
            )
            self.timerCancellable = timer.connect() as? AnyCancellable
            self.timerAccessibilityValue = String(Int(duration))
        }

        deinit { timerCancellable?.cancel() }

        func timerInvoked() {
            if remaining != initialDuration
                && Int(floor(remaining)) != Int(floor(remaining - tickRate)) {
                timerAccessibilityValue = String(Int(remaining))
            }
            remaining -= tickRate
            percentage -= rate
            if remaining <= 0 {
                timer.connect().cancel()
                onComplete()
            }
        }

        func formatted(remaining: Double) -> String {
            String(Int(ceil(remaining)))
        }
    }
}
