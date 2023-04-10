//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct InstructionView: View {
    let text: LocalizedStringKey
    let backgroundColor: Color
    var textColor: Color = .livenessLabel
    var font: Font = .body
    
    var body: some View {
        Text(text, bundle: .module)
            .foregroundColor(textColor)
            .font(font)
            .padding(12)
            .background(backgroundColor)
            .cornerRadius(8)
    }
}
