//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

@testable import FaceLiveness

final class MockFaceDetectionResultHandler {
    var intereactions: [String] = []
}

extension MockFaceDetectionResultHandler: FaceDetectionResultHandler {
    func process(newResult: FaceLiveness.FaceDetectionResult) {
        intereactions.append(#function)
    }
}
