//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import AVFoundation

protocol FaceDetector {
    func detectFaces(from buffer: CVPixelBuffer)
}
