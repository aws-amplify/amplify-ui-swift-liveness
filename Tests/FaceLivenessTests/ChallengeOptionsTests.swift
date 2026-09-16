//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import FaceLiveness
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

final class ChallengeOptionsTests: XCTestCase {

    /// Given: Options with the back camera for the face movement challenge
    /// When: The camera for each challenge is looked up
    /// Then: Face movement gets the back camera; face movement and light keeps the front camera
    func testCameraForChallengeFollowsTheMatchingOption() {
        let options = ChallengeOptions(
            faceMovementChallengeOption: .init(camera: .back),
            faceMovementAndLightChallengeOption: .init()
        )

        XCTAssertEqual(options.camera(for: .faceMovementChallenge("1.0.0")), .back)
        XCTAssertEqual(options.camera(for: .faceMovementAndLightChallenge("2.0.0")), .front)
    }

    /// Given: Default options
    /// When: The camera for each challenge is looked up
    /// Then: Both use the front camera
    func testDefaultOptionsUseTheFrontCamera() {
        let options = ChallengeOptions()

        XCTAssertEqual(options.camera(for: .faceMovementChallenge("1.0.0")), .front)
        XCTAssertEqual(options.camera(for: .faceMovementAndLightChallenge("2.0.0")), .front)
    }
}
