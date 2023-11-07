//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct CameraPreviewView: View {
    private static let previewWidthRatio = 0.6
    private static let previewHeightRatio = 0.75
    private static let previewXPositionRatio = 0.5
    private static let previewYPositionRatio = 0.55
    
    @StateObject var model: CameraPreviewViewModel
    
    public init(model: CameraPreviewViewModel = CameraPreviewViewModel()) {
        self._model = StateObject(wrappedValue: model)
    }
    
    var body: some View {
        ZStack {
            ImageFrameView(image: model.currentImageFrame)
                .edgesIgnoringSafeArea(.all)
                .mask(
                    GeometryReader { geometry in
                        Ellipse()
                            .frame(width: geometry.size.width*Self.previewWidthRatio,
                                   height: geometry.size.height*Self.previewHeightRatio)
                            .position(x: geometry.size.width*Self.previewXPositionRatio,
                                      y: geometry.size.height*Self.previewYPositionRatio)
                    })
            GeometryReader { geometry in
                Ellipse()
                    .stroke(Color.livenessPreviewBorder, style: StrokeStyle(lineWidth: 3))
                    .frame(width: geometry.size.width*Self.previewWidthRatio,
                           height: geometry.size.height*Self.previewHeightRatio)
                    .position(x: geometry.size.width*Self.previewXPositionRatio,
                              y: geometry.size.height*Self.previewYPositionRatio)
            }
            VStack {
                Text(LocalizedStrings.preview_center_your_face_text)
                    .font(.largeTitle)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            }
        }
    }
}

#Preview {
    CameraPreviewView()
}
