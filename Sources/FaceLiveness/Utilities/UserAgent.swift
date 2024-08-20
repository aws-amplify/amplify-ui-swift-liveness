//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import UIKit
import InternalAmplifyCredentials

struct UserAgentValues {
    
    static let libVersion = "1.3.2"
    static let libName = "amplify-ui-swift-face-liveness"
    
    let amplifyVersion: String
    let os: String
    let osVersion: String
    let swiftVersion: String
    let unameMachine: String
    let locale: String
    let additionalMetadata: String
    let lib: String?

    var userAgentString: String {
        let string = "amplify-swift/\(amplifyVersion) api/rekognitionstreaming/\(amplifyVersion) os/\(os)/\(osVersion) lang/swift/\(swiftVersion) md/device/\(unameMachine) md/locale/\(locale)" + additionalMetadata
        if let lib = lib {
            return string + " \(lib)"
        } else {
            return string
        }
    }

    init(
        amplifyVersion: String,
        os: String,
        osVersion: String,
        swiftVersion: String,
        unameMachine: String,
        locale: String,
        lib: String?,
        additionalMetadata: KeyValuePairs<String, String>
    ) {
        self.amplifyVersion = amplifyVersion
        self.os = os
        self.osVersion = osVersion
        self.swiftVersion = swiftVersion
        self.unameMachine = unameMachine
        self.locale = locale
        self.lib = lib
        self.additionalMetadata = additionalMetadata.map { key, value in
            "md/\(key)/\(value)"
        }.joined(separator: " ")
    }

    static func standard(additionalMetadata: KeyValuePairs<String, String> = [:]) -> Self {
        return .init(
            amplifyVersion: AmplifyAWSServiceConfiguration.amplifyVersion,
            os: UIDevice.current.systemName.replacingOccurrences(of: " ", with: "-"),
            osVersion: UIDevice.current.systemVersion,
            swiftVersion: Swift().version(),
            unameMachine: Device.current.machine.replacingOccurrences(of: ",", with: "_"),
            locale: Locale.current.identifier,
            lib: "lib/\(Self.libName)/\(Self.libVersion)",
            additionalMetadata: additionalMetadata
        )
    }
}


// https://github.com/apple/swift-evolution/blob/main/proposals/0141-available-by-swift-version.md
fileprivate struct Swift {
    func version() -> String {
#if swift(>=7.0)
        return "unknown"
#elseif swift(>=6.0)
        return "6.x"
#elseif swift(>=5.9)
        return "5.9"
#elseif swift(>=5.8)
        return "5.8"
#elseif swift(>=5.8)
        return "5.8"
#elseif swift(>=5.7)
        return "5.7"
#else
        return "unknown"
#endif
    }
}
