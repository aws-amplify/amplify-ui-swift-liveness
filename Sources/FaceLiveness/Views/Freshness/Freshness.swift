//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import UIKit
import Amplify
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

class Freshness {
    var colorSequences: [FaceLivenessSession.DisplayColor] = []
    let tickRate: Double
    let initialAlpha: CGFloat
    let secondaryAlpha: CGFloat
    var timer: Timer? = nil

    init(
        tickRate: Double = 0.01,
        initialAlpha: CGFloat = 0.9,
        secondaryAlpha: CGFloat = 0.75
    ) {
        self.tickRate = tickRate
        self.initialAlpha = initialAlpha
        self.secondaryAlpha = secondaryAlpha
    }

    struct ColorEvent {
        let currentColor: FaceLivenessSession.DisplayColor
        let previousColor: FaceLivenessSession.DisplayColor
        let sequenceNumber: Int
        let colorStartTime: UInt64
    }

    func showColorSequences(
        _ colorSequences: [FaceLivenessSession.DisplayColor],
        width: CGFloat,
        height: CGFloat,
        view: FreshnessView,
        onNewColor: @escaping (ColorEvent) -> Void,
        onComplete: @escaping () -> Void
    ) {
        self.colorSequences = colorSequences
        _showColorSequences(
            colorIndex: 0,
            previousColor: nil,
            view: view,
            height: height,
            onNewColor: onNewColor,
            onComplete: onComplete
        )
    }


    private func _showColorSequences(
        colorIndex: Int,
        previousColor: FaceLivenessSession.DisplayColor?,
        view: FreshnessView,
        height: CGFloat,
        onNewColor: @escaping (ColorEvent) -> Void,
        onComplete: @escaping () -> Void
    ) {
        if colorIndex >= colorSequences.count {
            view.clearColors()
            onComplete()
            return
        }

        let currentFreshnessColor = colorSequences[colorIndex]

        if !currentFreshnessColor.shouldScroll {
            view.alpha = initialAlpha
            view.backgroundColor = currentFreshnessColor.uiColor

            let previous = previousColor ?? currentFreshnessColor
            onNewColor(
                .init(
                    currentColor: currentFreshnessColor,
                    previousColor: previous,
                    sequenceNumber: colorIndex,
                    colorStartTime: Date().timestampMilliseconds
                )
            )

            DispatchQueue.main.asyncAfter(
                deadline: .now() + Double(currentFreshnessColor.duration / 1_000)
            ) {
                onNewColor(
                    .init(
                        currentColor: self.colorSequences[colorIndex + 1],
                        previousColor: currentFreshnessColor,
                        sequenceNumber: colorIndex + 1,
                        colorStartTime: Date().timestampMilliseconds
                    )
                )
                self._showColorSequences(
                        colorIndex: colorIndex + 1,
                        previousColor: currentFreshnessColor,
                        view: view,
                        height: height,
                        onNewColor: onNewColor,
                        onComplete: onComplete
                    )
            }
        } else {
            view.alpha = secondaryAlpha
            var newRectangleBottom: Double = 0
            let heightIncrease = height / Double(currentFreshnessColor.duration  / 1_000) * tickRate
            var msElapsed: Double = 0

            if let previousColor {
                view.oldRectangle.backgroundColor = previousColor.uiColor
            }

            Timer.scheduledTimer(withTimeInterval: tickRate, repeats: true) { timer in
                msElapsed += self.tickRate
                if msElapsed >= Double(currentFreshnessColor.duration / 1_000) {
                    timer.invalidate()
                    view.fractionalRectangleBottom?.constant = 0
                    view.oldRectangleTop?.constant = 0
                    if colorIndex < self.colorSequences.count - 1 {
                        onNewColor(
                            .init(
                                currentColor: self.colorSequences[colorIndex + 1],
                                previousColor: currentFreshnessColor,
                                sequenceNumber: colorIndex + 1,
                                colorStartTime: Date().timestampMilliseconds
                            )
                        )
                    }
                    self._showColorSequences(
                        colorIndex: colorIndex + 1,
                        previousColor: currentFreshnessColor,
                        view: view,
                        height: height,
                        onNewColor: onNewColor,
                        onComplete: onComplete
                    )
                } else {
                    newRectangleBottom += CGFloat(heightIncrease)
                    view.fractionalRectangleBottom?.constant = newRectangleBottom
                    view.oldRectangleTop?.constant = newRectangleBottom
                    view.fractionalRectangle.backgroundColor = currentFreshnessColor.uiColor
                    if let previousColor {
                        view.oldRectangle.backgroundColor = previousColor.uiColor
                    }
                }
            }
        }
    }
}

fileprivate extension ColorSequence {
    private func normalize(rgb: Int) -> CGFloat {
        CGFloat(rgb) / 255
    }

    var uiColor: UIColor {
        assert(freshnessColor.rgb.count == 3, "Invalid input format. Expected `Array` with values [r, g, b]")
        return .init(
            red: normalize(rgb: freshnessColor.rgb[0]),
            green: normalize(rgb: freshnessColor.rgb[1]),
            blue: normalize(rgb: freshnessColor.rgb[2]),
            alpha: 1
        )
    }
}
