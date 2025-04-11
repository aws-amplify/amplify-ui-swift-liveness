//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

extension LivenessResultContentView {
    struct Result {
        let text: String
        let value: String
        let valueTextColor: Color
        let valueBackgroundColor: Color
        let auditImage: Data?
        let isLive: Bool
        
        init(livenessResult: LivenessResult) {
            guard livenessResult.confidenceScore > 0 else {
                text = ""
                value = ""
                valueTextColor = .clear
                valueBackgroundColor = .clear
                auditImage = nil
                isLive = false
                return
            }
            isLive = livenessResult.isLive
            let truncated = String(format: "%.4f", livenessResult.confidenceScore)
            value = truncated
            if livenessResult.isLive {
                valueTextColor = .hex("#365E3D")
                valueBackgroundColor = .hex("#D6F5DB")
                text = "Check successful"
            } else {
                valueTextColor = .hex("#660000")
                valueBackgroundColor = .hex("#F5BCBC")
                text = "Check unsuccessful"
            }
            auditImage = livenessResult.auditImageBytes.flatMap{
                Data(base64Encoded: $0)
            }
        }
    }

    struct Score {
        let resultText: String
        let value: String
        let valueTextColor: Color
        let valueBackgroundColor: Color

        init(
            value: Double,
            colorRule: (Double) -> (Color, Color, String) = colorRule
        ) {
            let truncated = String(format: "%.4f", value)
            let (textColor, backgroundColor, resultText) = colorRule(value)
            self.resultText = resultText
            self.value = truncated
            self.valueTextColor = textColor
            self.valueBackgroundColor = backgroundColor
        }
    }
}

fileprivate func colorRule(v: Double) -> (Color, Color, String) {
    let textColor, backgroundColor: Color
    let resultText: String
    if v >= 70 {
        textColor = .hex("#365E3D")
        backgroundColor = .hex("#D6F5DB")
        resultText = "Check successful"
    } else {
        textColor = .hex("#660000")
        backgroundColor = .hex("#F5BCBC")
        resultText = "Check unsuccessful"
    }
    return (textColor, backgroundColor, resultText)
}
