//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct Row: Identifiable {
  var id: String { description }
  
  init(
    description: String,
    icon: String = "",
    view: AnyView,
    disabled: Bool = true
  ) {
    self.description = description
    self.icon = icon
    self.view = view
    self.disabled = disabled
  }
  
  let description: String
  let icon: String
  let view: AnyView
  let disabled: Bool
}
