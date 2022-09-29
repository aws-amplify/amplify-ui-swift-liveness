//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct ContentView: View {
  @State var isPressed = false

  var body: some View {
    NavigationView {
      List {
        ForEach(Category.allCases) { category in
          Section(category.description) {
            ForEach(category.rows) { row in
              NavigationLink(
                destination: ComponentPreviewView({ row.view }, title: row.description),
                label: { Text(row.description) }
              )
              .disabled(row.disabled)
            }
          }
        }
      }
      .navigationTitle("AmplifyUI Primitives")
    }
    .onAppear {
      let rows = Category.allCases.flatMap(\.rows)
      print("ENABLED / TOTAL", "=", rows.filter { !$0.disabled }.count, "/", rows.count)
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
