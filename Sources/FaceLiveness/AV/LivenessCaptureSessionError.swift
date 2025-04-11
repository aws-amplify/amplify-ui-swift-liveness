//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

struct LivenessCaptureSessionError: Error, Equatable {
    let code: UInt8

    static let deviceInputUnavailable = Self(code: 1)
    static let cameraUnavailable = Self(code: 2)
    static let captureSessionUnavailable = Self(code: 3)
    static let captureSessionInputUnavailable = Self(code: 5)
    static let captureSessionOutputUnavailable = Self(code: 6)
}
