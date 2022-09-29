//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct _ContentPreview<Content: View>: View {
  let title: String
  let content: Content
  
  init(title: String, @ViewBuilder _ content: () -> Content) {
    self.title = title
    self.content = content()
  }
  
  var body: some View {
    VStack {
      HStack {
        Text(title)
          .bold()
          .padding(.leading)
        Spacer()
      }.padding(.top)
      
      content
        .padding([.leading, .trailing, .bottom])
    }
  }
}
