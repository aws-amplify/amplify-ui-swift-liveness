//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct ImageFrameView: View {
    var image: CGImage?
    
    var body: some View {
        if let image = image {
            GeometryReader { geometry in
                Image(decorative: image, scale: 1.0, orientation: .up)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height,
                        alignment: .center)
                    .clipped()
            }
        } else {
          Color.black
        }
    }
}

struct ImageFrameView_Previews: PreviewProvider {
    static var previews: some View {
        ImageFrameView()
    }
}
