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
    let rightEar: CGPoint
    let leftEar: CGPoint

    let confidence: Float

    func boundingBoxFromLandmarks(ovalRect: CGRect) -> CGRect {
        let alpha = 2.0
        let gamma = 1.8
        let ow = (alpha * pupilDistance + gamma * faceHeight) / 2
        var cx = (eyeCenterX + nose.x) / 2
        
        if ovalRect != CGRect.zero {
            let ovalTop = ovalRect.minY
            let ovalHeight = ovalRect.maxY - ovalRect.minY
            if eyeCenterY > (ovalTop + ovalHeight) / 2 {
                cx = eyeCenterX
            }
        }
        
        let faceWidth = ow
        let faceHeight = 1.618 * faceWidth
        let faceBoxBottom = boundingBox.maxY
        let faceBoxTop = faceBoxBottom - faceHeight
        let faceBoxLeft = min(cx - ow / 2, rightEar.x)
        let faceBoxRight = max(cx + ow / 2, leftEar.x)
        let width = faceBoxRight - faceBoxLeft
        let height = faceBoxBottom - faceBoxTop
        let rect = CGRect(x: faceBoxLeft, y: faceBoxTop, width: width, height: height)
        return rect
    }

    var faceDistance: CGFloat {
        sqrt(pow(rightEye.x - leftEye.x, 2) + pow(rightEye.y - leftEye.y, 2))
    }
    
    var pupilDistance: CGFloat {
        sqrt(pow(leftEye.x - rightEye.x, 2) + pow(leftEye.y - rightEye.y, 2))
    }
    
    var eyeCenterX: CGFloat {
        (leftEye.x + rightEye.x) / 2
    }
    
    var eyeCenterY: CGFloat {
        (leftEye.y + rightEye.y) / 2
    }
    
    var faceHeight: CGFloat {
        sqrt(pow(eyeCenterX - mouth.x, 2) + pow(eyeCenterY - mouth.y, 2))
    }

    func normalize(width: CGFloat, height: CGFloat) -> DetectedFace {
        let boundingBox = CGRect(
            x: boundingBox.minX * width,
            y: boundingBox.minY * height,
            width: boundingBox.width * width,
            height: boundingBox.height * height
        )
        let leftEye = CGPoint(x: leftEye.x * width, y: leftEye.y * height)
        let rightEye = CGPoint(x: rightEye.x * width, y: rightEye.y * height)
        let nose = CGPoint(x: nose.x * width, y: nose.y * height)
        let mouth = CGPoint(x: mouth.x * width, y: mouth.y * height)
        let rightEar = CGPoint(x: rightEar.x * width, y: rightEar.y * height)
        let leftEar = CGPoint(x: leftEar.x * width, y: leftEar.y * height)
        
        return DetectedFace(
            boundingBox: boundingBox,
            leftEye: leftEye,
            rightEye: rightEye,
            nose: nose,
            mouth: mouth,
            rightEar: rightEar,
            leftEar: leftEar,
            confidence: confidence
        )
    }
}
