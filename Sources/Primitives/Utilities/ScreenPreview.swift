//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct ScreenPreview<Screen: View>: View {
  var screen: Screen
  var deviceNames: [String]
  
  var body: some View {
    ForEach(values: deviceNames) { device in
      ForEach(values: ColorScheme.allCases) { scheme in
        NavigationView {
          self.screen
            .navigationBarTitle("")
            .navigationBarHidden(true)
        }
        .previewDevice(PreviewDevice(rawValue: device))
        .colorScheme(scheme)
        .previewDisplayName("\(scheme.previewName): \(device)")
        .navigationViewStyle(StackNavigationViewStyle())
      }
    }
  }
  
}

struct Device {
  let name: String
  
  static let iPhone8 = Device(name: "iPhone 8")
  static let iPhone11 = Device(name: "iPhone 11")
  static let iPhone11ProMax = Device(name: "iPhone 11 Pro Max")
  static let iPadGen7 = Device(name: "iPad (7th generation)")
  static let iPadPro12inGen4 = Device(name: "iPad Pro (12.9-inch) (4th generation)")
  static let allDefaults = [Device.iPhone8, .iPhone11, .iPhone11ProMax, .iPadGen7, .iPadPro12inGen4]
  static func named(_ name: String) -> Device {
    .init(name: name)
  }
}

extension View {
  func previewAsScreen(devices: [Device] = Device.allDefaults) -> some View {
    ScreenPreview(screen: self, deviceNames: devices.map(\.name))
  }
  
  func previewAsScreen(devices: Device...) -> some View {
    ScreenPreview(screen: self, deviceNames: devices.map(\.name))
  }
}
