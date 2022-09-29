//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct Category: Identifiable {
  var id: String { description }
  let description: String
  let rows: [Row]

  static let allCases: [Category] = [
    Category(description: "Base", rows: [
      Row.init(description: "Divider", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "Heading", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "Image", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "Icon", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "ScrollView", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "Text", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "View", view: AnyView(EmptyView()), disabled: false)
    ]),
    Category(description: "Feedback", rows: [
      Row.init(description: "Alert", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "Loader", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "Placeholder", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "Pagination", view: AnyView(EmptyView()), disabled: false)
    ]),
    Category(description: "Navigation", rows: [
      Row.init(description: "Link", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "Menu", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "Tabs", view: AnyView(EmptyView()), disabled: false)
    ]),
    Category(description: "Inputs", rows: [
      Row.init(
        description: "Button",
        view: AnyView(EmptyView()),
        disabled: false
      ),
      Row.init(description: "CheckboxField", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "PasswordField", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "PhoneNumberField", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "RadioGroupField", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "SearchField", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "SelectField", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "SliderField", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "TextField", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "TextAreaField", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "ToggleButton", view: AnyView(EmptyView()), disabled: false)
    ]),
    Category(description: "Layout", rows: [
      Row.init(description: "Card", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "Collection", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "Expander", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "Flex", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "Grid", view: AnyView(EmptyView()), disabled: false),
      Row.init(description: "Table", view: AnyView(EmptyView()), disabled: false)
    ]),
    Category(description: "Data Display", rows: [
      Row.init(
        description: "Badge",
        view: AnyView(EmptyView()),
        disabled: false
      ),
      Row.init(
        description: "Rating",
        view: AnyView(EmptyView()),
        disabled: false
      )
    ])
  ]
}
