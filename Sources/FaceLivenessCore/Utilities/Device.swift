//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

@dynamicMemberLookup
struct Device {
    let info: Info

    subscript<T>(dynamicMember keyPath: KeyPath<Info, T>) -> T {
        info[keyPath: keyPath]
    }
}

extension Device: Equatable {
    public static func == (lhs: Device, rhs: Device) -> Bool {
        return lhs.info == rhs.info
    }
}

extension Device {
    static var current: Device {
        Device(info: info)
    }

    struct Info: Equatable, Hashable {
        public let sysname: String
        public let nodename: String
        public let release: String
        public let version: String
        public let machine: String
    }

    // https://opensource.apple.com/source/xnu/xnu-201/bsd/sys/utsname.h.auto.html
    static let info: Info = {
        func value(
            from p: UnsafeMutablePointer<utsname>,
            _ keyPath: KeyPath<utsname, utsname_prop>
        ) -> String {
            var property = p.pointee[keyPath: keyPath]
            return withUnsafePointer(to: &property) {
                $0.withMemoryRebound(
                    to: CChar.self,
                    capacity: 1,
                    String.init(cString:)
                )
             }
        }

        let sysInfo = UnsafeMutablePointer<utsname>
            .allocate(capacity: 1)
        sysInfo.initialize(to: utsname())
        uname(sysInfo)

        return Info(
            sysname: value(from: sysInfo, \.sysname),
            nodename: value(from: sysInfo, \.nodename),
            release: value(from: sysInfo, \.release),
            version: value(from: sysInfo, \.version),
            machine: value(from: sysInfo, \.machine)
       )
    }()
}

typealias utsname_prop = (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar)
