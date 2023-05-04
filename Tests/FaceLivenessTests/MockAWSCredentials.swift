//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSPluginsCore

struct MockAWSCredentials: AWSCredentials {
    var accessKeyId: String
    var secretAccessKey: String
}
