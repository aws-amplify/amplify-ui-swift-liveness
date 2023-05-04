//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSPluginsCore

struct MockAWSTemporaryCredentials: AWSTemporaryCredentials {
    var sessionToken: String
    var expiration: Date
    var accessKeyId: String
    var secretAccessKey: String
}
