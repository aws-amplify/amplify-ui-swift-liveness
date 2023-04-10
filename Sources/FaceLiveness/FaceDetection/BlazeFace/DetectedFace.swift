//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

struct DetectedFace {
    var boundingBox: CGRect

    let leftEye: CGPoint
    let rightEye: CGPoint
    let nose: CGPoint
    let mouth: CGPoint

    let confidence: Float

    func boundingBoxFromLandmarks() -> CGRect {
        let eyeCenterX = (leftEye.x + rightEye.x) / 2
        let eyeCenterY = (leftEye.y + rightEye.y) / 2

        let cx = (nose.x + eyeCenterX) / 2
        let cy = (nose.y + eyeCenterY) / 2

        let ow = sqrt(pow((leftEye.x - rightEye.x), 2) + pow((leftEye.y - rightEye.y), 2)) * 2
        let oh = 1.618 * ow
        let minX = cx - ow / 2
        let minY = cy - oh / 2

        let rect = CGRect(x: minX, y: minY, width: ow, height: oh)
        return rect
    }

    var faceDistance: CGFloat {
        sqrt(pow(rightEye.x - leftEye.x, 2) + pow(rightEye.y - leftEye.y, 2))
    }

    func normalize(width: CGFloat, height: CGFloat) -> DetectedFace {
        .init(
            boundingBox: .init(
                x: boundingBox.minX * width,
                y: boundingBox.minY * height,
                width: boundingBox.width * width,
                height: boundingBox.height * height
            ),
            leftEye: .init(
                x: leftEye.x * width,
                y: leftEye.y * height
            ),
            rightEye: .init(
                x: rightEye.x * width,
                y: rightEye.y * height
            ),
            nose: .init(
                x: nose.x * width,
                y: nose.y * height
            ),
            mouth: .init(
                x: mouth.x * width,
                y: mouth.y * height
            ),
            confidence: confidence
        )
    }
}
