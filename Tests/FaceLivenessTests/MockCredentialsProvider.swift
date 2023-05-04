//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import AWSPluginsCore

struct MockCredentialsProvider: AWSCredentialsProvider {
    let credentials: () -> AWSCredentials

    func fetchAWSCredentials() async throws -> AWSCredentials {
        credentials()
    }
}
