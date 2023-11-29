//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import FaceLiveness


final class DetectedFaceTests: XCTestCase {
    var detectedFace: DetectedFace!
    var expectedNormalizeFace: DetectedFace!
    let normalizeWidth = 414.0
    let normalizeHeight = 552.0
    
    override func setUp() {
        let boundingBox = CGRect(
            x: 0.15805082494171963,
            y: 0.3962942063808441,
            width: 0.6549023386310235,
            height: 0.49117204546928406
        )
        let leftEye = CGPoint(x: 0.6686329891870315, y: 0.48738187551498413)
        let rightEye = CGPoint(x: 0.35714725227596134, y: 0.4664449691772461)
        let nose = CGPoint(x: 0.5283648181467697, y: 0.5319401621818542)
        let mouth = CGPoint(x: 0.5062596005080024, y: 0.689265251159668)
        let rightEar = CGPoint(x: 0.1658528943614037, y: 0.5668278932571411)
        let leftEar = CGPoint(x: 0.7898947484263203, y: 0.5973731875419617)
        let confidence: Float = 0.94027895
        detectedFace = DetectedFace(
            boundingBox: boundingBox,
            leftEye: leftEye,
            rightEye: rightEye,
            nose: nose,
            mouth: mouth,
            rightEar: rightEar,
            leftEar: leftEar,
            confidence: confidence
        )
        
        let normalizedBoundingBox = CGRect(
            x: 0.15805082494171963 * normalizeWidth,
            y: 0.3962942063808441 * normalizeHeight,
            width: 0.6549023386310235 * normalizeWidth,
            height: 0.49117204546928406 * normalizeHeight
        )
        let normalizedLeftEye = CGPoint(
            x: 0.6686329891870315 * normalizeWidth,
            y: 0.48738187551498413 * normalizeHeight
        )
        let normalizedRightEye = CGPoint(
            x: 0.35714725227596134 * normalizeWidth,
            y: 0.4664449691772461 * normalizeHeight)
        let normalizedNose = CGPoint(
            x: 0.5283648181467697 * normalizeWidth,
            y: 0.5319401621818542 * normalizeHeight
        )
        let normalizedMouth = CGPoint(
            x: 0.5062596005080024 * normalizeWidth,
            y: 0.689265251159668 * normalizeHeight
        )
        let normalizedRightEar = CGPoint(
            x: 0.1658528943614037 * normalizeWidth,
            y: 0.5668278932571411 * normalizeHeight
        )
        let normalizedLeftEar = CGPoint(
            x: 0.7898947484263203 * normalizeWidth,
            y: 0.5973731875419617 * normalizeHeight
        )
        
        expectedNormalizeFace = DetectedFace(
            boundingBox: normalizedBoundingBox,
            leftEye: normalizedLeftEye,
            rightEye: normalizedRightEye,
            nose: normalizedNose,
            mouth: normalizedMouth,
            rightEar: normalizedRightEar,
            leftEar: normalizedLeftEar,
            confidence: confidence
        )
    }

    /// Given:  A `DetectedFace`
    /// When: when the struct is initialized
    /// Then: the calculated landmarks are available and calculated as expected
    func testDetectedFaceLandmarks() {
        XCTAssertEqual(detectedFace.eyeCenterX, 0.5128901207314964)
        XCTAssertEqual(detectedFace.eyeCenterY, 0.4769134223461151)
        XCTAssertEqual(detectedFace.faceDistance, 0.31218859419592454)
        XCTAssertEqual(detectedFace.pupilDistance, 0.31218859419592454)
        XCTAssertEqual(detectedFace.faceHeight, 0.21245532000610062)
    }
    
    /// Given:  A `DetectedFace`
    /// When: when boundingBoxFromLandmarks is called
    /// Then: the calculated bounding box is returned
    func testDetectedFaceBoundingBoxFromLandmarks() {
        let ovalRect = CGRect.zero
        let expectedBoundingBox = CGRect(
            x: 0.1658528943614037,
            y: 0.072967669448238516,
            width: 0.6240418540649166,
            height: 0.8144985824018897
        )
        let boundingBox = detectedFace.boundingBoxFromLandmarks(ovalRect: ovalRect)
        XCTAssertEqual(boundingBox.origin.x, expectedBoundingBox.origin.x)
        XCTAssertEqual(boundingBox.origin.y, expectedBoundingBox.origin.y)
        XCTAssertEqual(boundingBox.width, expectedBoundingBox.width)
        XCTAssertEqual(boundingBox.height, expectedBoundingBox.height)
    }
    
    /// Given:  A `DetectedFace`
    /// When: when normalize is called with a view dimension
    /// Then: the normalized face calculates the correct landmark distances
    func testDetectedFaceNormalize() {
        let normalizedFace = detectedFace.normalize(width: normalizeWidth, height:  normalizeHeight)
        XCTAssertEqual(normalizedFace.eyeCenterX, expectedNormalizeFace.eyeCenterX)
        XCTAssertEqual(normalizedFace.eyeCenterY, expectedNormalizeFace.eyeCenterY)
        XCTAssertEqual(normalizedFace.faceDistance, expectedNormalizeFace.faceDistance)
        XCTAssertEqual(normalizedFace.pupilDistance, expectedNormalizeFace.pupilDistance)
        XCTAssertEqual(normalizedFace.faceHeight, expectedNormalizeFace.faceHeight)
    }

}
